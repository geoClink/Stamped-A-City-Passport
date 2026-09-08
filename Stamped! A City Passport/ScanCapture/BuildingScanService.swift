import CloudKit
import Foundation

// Manages CloudKit reads and writes for user-submitted building scans.
// Uses the public database so every user can see every scan.
@MainActor
class BuildingScanService {
    static let shared = BuildingScanService()

    private let db = CKContainer.default().publicCloudDatabase

    // Fetch the most recent scan for a building. Returns nil if none exists.
    func fetchLatestScan(buildingID: String) async -> CKRecord? {
        let pred = NSPredicate(format: "buildingID == %@", buildingID)
        let query = CKQuery(recordType: "BuildingScan", predicate: pred)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = try? await db.records(matching: query, resultsLimit: 1)
        return try? result?.matchResults.first?.1.get()
    }

    // Upload a USDZ file to the public CloudKit database.
    func upload(usdzURL: URL, buildingID: String, buildingName: String, cityName: String) async throws {
        let record = CKRecord(recordType: "BuildingScan")
        record["buildingID"] = buildingID as CKRecordValue
        record["buildingName"] = buildingName as CKRecordValue
        record["cityName"] = cityName as CKRecordValue
        record["model"] = CKAsset(fileURL: usdzURL)
        _ = try await db.save(record)
    }

    // Copy the CKAsset to a stable temp path and return its URL.
    // CKAsset temp files are cleaned up by the system — we must copy before using.
    func localModelURL(for record: CKRecord) async throws -> URL {
        guard let asset = record["model"] as? CKAsset,
              let src = asset.fileURL else { throw ScanError.noAsset }
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("scan_\(record.recordID.recordName).usdz")
        if !FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.copyItem(at: src, to: dest)
        }
        return dest
    }

    enum ScanError: LocalizedError {
        case noAsset
        var errorDescription: String? { "No 3D model found in this record." }
    }
}
