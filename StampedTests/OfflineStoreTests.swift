//
//  OfflineStoreTests.swift
//  StampedTests
//
//  Tests for the bookkeeping behind "Save for Offline" (OfflineStore): where files go,
//  the manifest, sizes, lookups and Remove. No network: each test writes small fake
//  "photos" into its own temporary folder.
//

import XCTest
@testable import Stamped_

final class OfflineStoreTests: XCTestCase {

    private var root: URL!
    private let photoA = URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Tower.jpg/1280px-Tower.jpg")!
    private let photoB = URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b2/Hall.png/1280px-Hall.png")!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("OfflineStoreTests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    /// Saves a city with one summary per photo, after writing `bytes` of fake data for each photo
    @discardableResult
    private func saveCity(_ store: OfflineStore, id: String, photos: [URL], bytes: Int = 1_000) throws -> OfflineCityRecord {
        var content = OfflineCityContent()
        for (index, photo) in photos.enumerated() {
            try store.writeImage(Data(repeating: 7, count: bytes), for: photo)
            content.summaries["\(id)-\(index)"] = SavedSummary(photoURL: photo, extract: "Text \(index)", articleTitle: nil)
        }
        return try store.commit(cityID: id, cityName: id, content: content, imageURLs: photos)
    }

    // Nothing saved yet: no cities, no lookups, and photo views keep the web address
    func testEmptyStore() {
        let store = OfflineStore(root: root)
        XCTAssertTrue(store.savedCities.isEmpty)
        XCTAssertFalse(store.isSaved("Chicago"))
        XCTAssertNil(store.summary(forKey: "chi-01"))
        XCTAssertNil(store.localImageURL(for: photoA))
        XCTAssertEqual(store.displayURL(for: photoA), photoA)
        XCTAssertNil(store.displayURL(for: nil))
    }

    // Files go in the store's folder; the same address always gives the same photo file,
    // the extension is kept, and odd ones become ".img"
    func testFilePaths() {
        let store = OfflineStore(root: root)
        XCTAssertEqual(store.imageFileURL(for: photoA).deletingLastPathComponent().lastPathComponent, "images")
        XCTAssertTrue(store.imageFileURL(for: photoA).path.hasPrefix(root.path))
        XCTAssertEqual(store.imageFileName(for: photoA), store.imageFileName(for: photoA))
        XCTAssertNotEqual(store.imageFileName(for: photoA), store.imageFileName(for: photoB))
        XCTAssertEqual(store.imageFileURL(for: photoA).pathExtension, "jpg")
        XCTAssertEqual(store.imageFileURL(for: URL(string: "https://example.com/photo?id=3")!).pathExtension, "img")
        // City names with spaces and dots still give a plain file name
        XCTAssertEqual(store.contentFileURL(forCity: "Washington D.C.").pathExtension, "json")
        XCTAssertFalse(store.contentFileURL(forCity: "Washington D.C.").lastPathComponent.contains(" "))
    }

    // Saving a city records it with its size (text file + photos), and its summaries
    // and photos are then found by the lookups the app uses
    func testCommitRecordsCityAndSize() throws {
        let store = OfflineStore(root: root)
        let record = try saveCity(store, id: "Chicago", photos: [photoA, photoB], bytes: 5_000)

        XCTAssertTrue(store.isSaved("Chicago"))
        XCTAssertEqual(record.imageFiles.count, 2)
        // Two 5,000-byte photos plus a small JSON file
        XCTAssertGreaterThan(record.byteCount, 10_000)
        XCTAssertLessThan(record.byteCount, 11_000)
        XCTAssertEqual(store.totalByteCount, record.byteCount)

        XCTAssertEqual(store.summary(forKey: "Chicago-0")?.extract, "Text 0")
        XCTAssertEqual(store.localImageURL(for: photoA), store.imageFileURL(for: photoA))
        XCTAssertTrue(store.displayURL(for: photoB)?.isFileURL == true)
    }

    // The manifest is on disk: a new store (the next app launch) sees the same cities
    func testManifestSurvivesRelaunch() throws {
        let first = OfflineStore(root: root)
        let saved = try saveCity(first, id: "Paris", photos: [photoA])

        let relaunched = OfflineStore(root: root)
        XCTAssertEqual(relaunched.savedCities, [saved])
        XCTAssertEqual(relaunched.summary(forKey: "Paris-0")?.photoURL, photoA)
        XCTAssertNotNil(relaunched.localImageURL(for: photoA))
    }

    // A photo that was never written (e.g. a 404) is left out of the record
    func testMissingPhotoIsLeftOut() throws {
        let store = OfflineStore(root: root)
        try store.writeImage(Data(repeating: 1, count: 100), for: photoA)
        let record = try store.commit(cityID: "Rome", cityName: "Rome", content: OfflineCityContent(), imageURLs: [photoA, photoB])
        XCTAssertEqual(record.imageFiles, [store.imageFileName(for: photoA)])
        XCTAssertNil(store.localImageURL(for: photoB))
    }

    // Remove deletes the city's text and photos, but keeps a photo another saved city uses
    func testRemoveKeepsSharedPhotos() throws {
        let store = OfflineStore(root: root)
        try saveCity(store, id: "Minneapolis", photos: [photoA, photoB])
        try saveCity(store, id: "St. Paul", photos: [photoA])

        try store.remove(cityID: "Minneapolis")

        XCTAssertFalse(store.isSaved("Minneapolis"))
        XCTAssertTrue(store.isSaved("St. Paul"))
        XCTAssertNil(store.summary(forKey: "Minneapolis-1"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.contentFileURL(forCity: "Minneapolis").path))
        // photoA is still used by St. Paul; photoB was only Minneapolis's
        XCTAssertTrue(store.hasImageFile(for: photoA))
        XCTAssertFalse(store.hasImageFile(for: photoB))

        try store.remove(cityID: "St. Paul")
        XCTAssertTrue(store.savedCities.isEmpty)
        XCTAssertFalse(store.hasImageFile(for: photoA))
        XCTAssertEqual(store.totalByteCount, 0)
    }

    // Photos from a cancelled save stay on disk (so the next Save resumes) but aren't
    // used until the city is committed; pruning clears them
    func testCancelledSaveLeftovers() throws {
        let store = OfflineStore(root: root)
        try store.writeImage(Data(repeating: 2, count: 100), for: photoA)

        XCTAssertTrue(store.hasImageFile(for: photoA))
        XCTAssertNil(store.localImageURL(for: photoA))

        store.pruneUnusedImages()
        XCTAssertFalse(store.hasImageFile(for: photoA))
    }

    // The campus History card is saved and found by its article title
    func testCampusHistoryLookup() throws {
        let store = OfflineStore(root: root)
        var content = OfflineCityContent()
        let history = CampusHistory(foundedYear: 1855, summary: "Founded as a farm school.", articleURL: URL(string: "https://en.wikipedia.org/wiki/Michigan_State_University"))
        content.histories["Michigan State University"] = history
        try store.commit(cityID: "Michigan State", cityName: "Michigan State", content: content, imageURLs: [])

        XCTAssertEqual(OfflineStore(root: root).history(forArticle: "Michigan State University"), history)
    }

    // The photo views hand AsyncImage a file URL; it loads through URLSession, which reads files
    func testSavedPhotoLoadsThroughURLSession() async throws {
        let store = OfflineStore(root: root)
        try saveCity(store, id: "Tokyo", photos: [photoA], bytes: 64)
        let fileURL = try XCTUnwrap(store.localImageURL(for: photoA))
        let (data, _) = try await URLSession.shared.data(from: fileURL)
        XCTAssertEqual(data.count, 64)
    }
}
