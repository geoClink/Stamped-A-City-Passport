import Foundation

/// Downloads a remote BuildingRegistry JSON (if configured in Info.plist under key `BuildingRegistryRemoteURL`) and
/// writes it to Documents/BuildingRegistry.json so the existing `BuildingRegistry` loader picks it up.
struct BuildingRegistryUpdater {
    private static let docsFileName = "BuildingRegistry.json"
    private static let etagKey = "cached_registry_etag"

    /// Public entry: attempt to update registry from remote if configured.
    static func refreshIfNeeded() async {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "BuildingRegistryRemoteURL") as? String,
              let url = URL(string: urlString) else {
            // No remote configured
            return
        }

        await fetchAndWrite(url: url)
    }

    private static func fetchAndWrite(url: URL) async {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData

        // Add If-None-Match using stored ETag to avoid re-downloading
        if let oldETag = UserDefaults.standard.string(forKey: etagKey) {
            request.addValue(oldETag, forHTTPHeaderField: "If-None-Match")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }

            if http.statusCode == 304 {
                // Not modified
                print("BuildingRegistryUpdater: registry not modified (304)")
                return
            }

            guard (200...299).contains(http.statusCode) else {
                print("BuildingRegistryUpdater: server returned status \(http.statusCode)")
                return
            }

            // Try decoding to ensure schema is OK before writing
            let decoder = JSONDecoder()
            let dict = try decoder.decode([String: [Building]].self, from: data)
            // Map to CityLocation.City keys to ensure compatibility (this mirrors BuildingRegistry.loadFromBundle)
            var mapped: [String: [Building]] = [:]
            for (k, v) in dict { mapped[k] = v }

            // Write raw bytes to Documents atomically
            try writeDataToDocuments(data)

            // Store ETag if present
            if let etag = http.value(forHTTPHeaderField: "ETag") {
                UserDefaults.standard.set(etag, forKey: etagKey)
            }

            print("BuildingRegistryUpdater: updated registry from \(url) with \(mapped.keys.count) cities")

        } catch {
            print("BuildingRegistryUpdater: fetch failed - \(error.localizedDescription)")
        }
    }

    private static func documentsURL() -> URL? {
        let fm = FileManager.default
        return fm.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(docsFileName)
    }

    private static func writeDataToDocuments(_ data: Data) throws {
        guard let dest = documentsURL() else { throw NSError(domain: "BuildingRegistryUpdater", code: 1, userInfo: [NSLocalizedDescriptionKey: "Documents directory not found"]) }
        let tmp = dest.appendingPathExtension("tmp")
        try data.write(to: tmp, options: .atomic)
        // Move into place (replace if exists)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tmp, to: dest)
    }
}
