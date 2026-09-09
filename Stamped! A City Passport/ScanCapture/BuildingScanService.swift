import CloudKit
import Foundation

// Manages CloudKit reads and writes for user-submitted building scans.
// Uses the public database so every user can see every scan.
@MainActor
class BuildingScanService {
    static let shared = BuildingScanService()

    private let db = CKContainer(identifier: "iCloud.com.georgeclinkscales.Stamped").publicCloudDatabase

    // Fetch the scan for a building by its record ID (buildingID is the record name — no index needed).
    func fetchLatestScan(buildingID: String) async -> CKRecord? {
        print("[CloudKit] Fetching scan for buildingID: \(buildingID)")
        let recordID = CKRecord.ID(recordName: buildingID)
        do {
            let record = try await db.record(for: recordID)
            print("[CloudKit] ✅ Found scan — recordID: \(record.recordID.recordName), created: \(record.creationDate as Any)")
            return record
        } catch let error as CKError where error.code == .unknownItem {
            print("[CloudKit] No scan found for \(buildingID).")
            return nil
        } catch {
            print("[CloudKit] ❌ Fetch failed for \(buildingID): \(error)")
            print("[CloudKit]    Error domain: \((error as NSError).domain), code: \((error as NSError).code)")
            return nil
        }
    }

    // Upload a USDZ file. Uses buildingID as the record name so each building has exactly one scan
    // and a new submission automatically replaces the old one.
    func upload(usdzURL: URL, buildingID: String, buildingName: String, cityName: String) async throws {
        print("[CloudKit] Uploading scan for \(buildingName) (\(buildingID)), file: \(usdzURL.lastPathComponent)")
        let recordID = CKRecord.ID(recordName: buildingID)
        let record = CKRecord(recordType: "BuildingScan", recordID: recordID)
        record["buildingID"] = buildingID as CKRecordValue
        record["buildingName"] = buildingName as CKRecordValue
        record["cityName"] = cityName as CKRecordValue
        record["model"] = CKAsset(fileURL: usdzURL)
        do {
            let saved = try await db.save(record)
            print("[CloudKit] ✅ Upload succeeded — recordID: \(saved.recordID.recordName)")
        } catch {
            print("[CloudKit] ❌ Upload failed: \(error)")
            print("[CloudKit]    Error domain: \((error as NSError).domain), code: \((error as NSError).code)")
            throw error
        }
    }

    // Copy the CKAsset to a stable temp path and return its URL.
    // CKAsset temp files are cleaned up by the system — we must copy before using.
    func localModelURL(for record: CKRecord) async throws -> URL {
        guard let asset = record["model"] as? CKAsset,
              let src = asset.fileURL else {
            print("[CloudKit] ❌ localModelURL: no asset in record \(record.recordID.recordName)")
            throw ScanError.noAsset
        }
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("scan_\(record.recordID.recordName).usdz")
        if !FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.copyItem(at: src, to: dest)
            print("[CloudKit] ✅ Copied model to: \(dest.lastPathComponent)")
        } else {
            print("[CloudKit] Model already cached at: \(dest.lastPathComponent)")
        }
        return dest
    }

    enum ScanError: LocalizedError {
        case noAsset
        var errorDescription: String? { "No 3D model found in this record." }
    }
}
