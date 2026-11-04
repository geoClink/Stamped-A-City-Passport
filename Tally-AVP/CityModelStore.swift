//
//  CityModelStore.swift
//  Tally-AVP
//
//  Finds each city's 3D model (detroit.usdz) and downloads it when needed.
//  The model isn't part of the Vision Pro app download (that kept the app at
//  about 24 MB). Instead it's an Apple-hosted asset pack, "Detroit3D", that
//  the user downloads from the city map with one tap. Apple stores the pack
//  next to the app on the App Store, and the system does the download.
//
//  A copy bundled inside the app still wins, so dev builds that bundle the
//  model keep working without a download.
//  How to build and upload the pack: tools/detroit-model/README.md
//

import Foundation
import Observation
import BackgroundAssets
import System

@MainActor
@Observable
final class CityModelStore {
    static let shared = CityModelStore()

    /// Where one city's 3D model is right now.
    enum ModelState: Equatable {
        /// Still asking the system what's installed.
        case checking
        /// This city has no 3D model at all.
        case unavailable
        /// Can be downloaded. The size is in bytes, when the system knows it.
        case notDownloaded(bytes: Int?)
        /// Downloading: 0.0 … 1.0
        case downloading(fraction: Double)
        /// On this device and ready to open.
        case ready
    }

    /// City name (lowercased) → its asset pack ID in App Store Connect.
    /// Must match "assetPackID" in tools/detroit-model/Detroit3D.json.
    private let assetPackIDs = ["detroit": "Detroit3D"]

    private(set) var states: [String: ModelState] = [:]
    /// The city whose download just failed; the map shows an alert for it.
    var failedCityName: String?

    private var downloadSizes: [String: Int] = [:]
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    /// A new ID for every download, so a cancelled one can't overwrite a newer one.
    private var downloadIDs: [String: UUID] = [:]
    /// The system's progress for each running download; cancelling it stops the download.
    private var downloadProgress: [String: Progress] = [:]

    private init() {}

    func state(for cityName: String) -> ModelState {
        states[key(cityName)] ?? .checking
    }

    /// The model file to load: the copy in the app bundle first, then the downloaded asset pack.
    func modelURL(for cityName: String) -> URL? {
        let name = key(cityName)
        if let bundled = Bundle.main.url(forResource: name, withExtension: "usdz") {
            return bundled
        }
        guard let packID = assetPackIDs[name],
              AssetPackManager.shared.assetPackIsAvailableLocally(withID: packID) else {
            return nil
        }
        return try? AssetPackManager.shared.url(for: FilePath("\(name).usdz"))
    }

    /// Works out whether the model is ready, downloadable, or doesn't exist.
    func refresh(_ cityName: String) async {
        let name = key(cityName)
        if case .downloading = state(for: cityName) { return }

        if modelURL(for: cityName) != nil {
            states[name] = .ready
            return
        }
        guard let packID = assetPackIDs[name] else {
            states[name] = .unavailable
            return
        }
        do {
            // Reads the pack's details (like its size) from Apple's servers.
            let pack = try await AssetPackManager.shared.assetPack(withID: packID)
            downloadSizes[name] = pack.downloadSize
            states[name] = .notDownloaded(bytes: pack.downloadSize)
        } catch {
            // Offline, for example. Still offer the download, just without a size.
            print("[CityModel] Couldn't look up \(packID): \(error)")
            states[name] = .notDownloaded(bytes: downloadSizes[name])
        }
    }

    /// Starts downloading the city's model. The state shows the progress.
    func download(_ cityName: String) {
        let name = key(cityName)
        guard let packID = assetPackIDs[name], downloadIDs[name] == nil else { return }
        let downloadID = UUID()
        downloadIDs[name] = downloadID
        states[name] = .downloading(fraction: 0)

        downloadTasks[name] = Task {
            // False once the user pressed Cancel (or started a new download).
            var isCurrent: Bool { downloadIDs[name] == downloadID }

            // Listen for progress updates while the system downloads.
            let progressTask = Task {
                for await update in AssetPackManager.shared.statusUpdates(forAssetPackWithID: packID) {
                    if case .downloading(_, let progress) = update, isCurrent {
                        downloadProgress[name] = progress
                        states[name] = .downloading(fraction: progress.fractionCompleted)
                    }
                }
            }

            do {
                let pack = try await AssetPackManager.shared.assetPack(withID: packID)
                try await AssetPackManager.shared.ensureLocalAvailability(of: pack)
                // The file is on the device now, even if Cancel came too late.
                states[name] = .ready
            } catch {
                if isCurrent {
                    print("[CityModel] Download of \(packID) failed: \(error)")
                    states[name] = .notDownloaded(bytes: downloadSizes[name])
                    failedCityName = cityName
                }
            }

            progressTask.cancel()
            if isCurrent {
                downloadIDs[name] = nil
                downloadTasks[name] = nil
                downloadProgress[name] = nil
            }
        }
    }

    /// Stops a running download and shows the download button again.
    func cancelDownload(_ cityName: String) {
        let name = key(cityName)
        downloadProgress[name]?.cancel()
        downloadTasks[name]?.cancel()
        downloadIDs[name] = nil
        downloadTasks[name] = nil
        downloadProgress[name] = nil
        states[name] = .notDownloaded(bytes: downloadSizes[name])
    }

    private func key(_ cityName: String) -> String {
        cityName.lowercased()
    }
}
