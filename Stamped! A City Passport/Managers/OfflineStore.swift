//
//  OfflineStore.swift
//  Stamped! A City Passport
//
//  The saved copies behind "Save for Offline": for each saved city, every landmark's
//  Wikipedia summary (text and photo address), the campus History card, and the photos
//  themselves at the size the app shows (WikimediaService.photoWidth).
//
//  Everything lives in Application Support/OfflineCities (not Caches, so the system
//  doesn't delete it mid-trip; excluded from iCloud backup, since it can be downloaded again):
//
//      manifest.json        which cities are saved, when, and how big (OfflineCityRecord)
//      cities/<hash>.json   one city's summaries and History (OfflineCityContent)
//      images/<hash>.jpg    photos, named after their web address, shared between cities
//
//  WikimediaService, CampusHistoryService and the photo views ask this store first,
//  so a saved city works without a connection. Cities that aren't saved behave as before.
//  OfflineDownloader does the downloading; this type only reads and writes files.
//

import Foundation
import CryptoKit

// MARK: - Saved data

/// A landmark's (or city's) Wikipedia summary, as saved on disk.
nonisolated struct SavedSummary: Codable, Equatable, Sendable {
    var photoURL: URL?
    var extract: String?
    var articleTitle: String?
}

/// Everything saved for one city apart from the photos.
nonisolated struct OfflineCityContent: Codable, Equatable, Sendable {
    /// Same keys as WikimediaService's cache: building ID, or the article title for the city itself
    var summaries: [String: SavedSummary] = [:]
    /// Campus History card, by article title (campuses only)
    var histories: [String: CampusHistory] = [:]
}

/// One saved city, as listed in Settings.
nonisolated struct OfflineCityRecord: Codable, Equatable, Sendable, Identifiable {
    /// `CityLocation.City.rawValue`
    let cityID: String
    let cityName: String
    let savedAt: Date
    /// The city's text file plus its photos
    let byteCount: Int64
    /// File names in images/, so removing a city knows which photos were its own
    let imageFiles: [String]

    var id: String { cityID }
}

nonisolated private struct OfflineManifest: Codable {
    var cities: [String: OfflineCityRecord] = [:]
}

// MARK: - Store

/// Thread-safe: the photo views read it on the main thread, WikimediaService from its actor.
/// Lookups use an in-memory index built from the manifest, so they never touch the disk.
nonisolated final class OfflineStore: @unchecked Sendable {
    static let shared = OfflineStore(root: OfflineStore.defaultRoot)

    static var defaultRoot: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("OfflineCities", isDirectory: true)
    }

    let root: URL
    private let lock = NSLock()
    private let fileManager = FileManager.default

    // Guarded by `lock`
    private var manifest = OfflineManifest()
    private var summaries: [String: SavedSummary] = [:]
    private var histories: [String: CampusHistory] = [:]
    private var savedImageFiles: Set<String> = []

    /// Tests pass a temporary folder; the app uses `shared`.
    init(root: URL) {
        self.root = root
        lock.withLock { reloadLocked() }
    }

    // MARK: Paths

    var manifestURL: URL { root.appendingPathComponent("manifest.json") }
    var imagesDirectory: URL { root.appendingPathComponent("images", isDirectory: true) }
    var citiesDirectory: URL { root.appendingPathComponent("cities", isDirectory: true) }

    /// City names have spaces, dots and accents, so files are named after a hash instead
    func contentFileURL(forCity cityID: String) -> URL {
        citiesDirectory.appendingPathComponent(Self.hash(cityID) + ".json")
    }

    /// The same web address always gives the same file name, so a photo shared by two
    /// cities is stored once, and a half-finished save can pick up where it stopped.
    func imageFileName(for remoteURL: URL) -> String {
        let known = ["jpg", "jpeg", "png", "gif", "webp", "tif", "tiff"]
        let ext = remoteURL.pathExtension.lowercased()
        return Self.hash(remoteURL.absoluteString) + "." + (known.contains(ext) ? ext : "img")
    }

    func imageFileURL(for remoteURL: URL) -> URL {
        imagesDirectory.appendingPathComponent(imageFileName(for: remoteURL))
    }

    // MARK: Lookups (used by the app while browsing)

    var savedCities: [OfflineCityRecord] {
        lock.withLock { manifest.cities.values.sorted { $0.cityName < $1.cityName } }
    }

    func record(forCity cityID: String) -> OfflineCityRecord? {
        lock.withLock { manifest.cities[cityID] }
    }

    func isSaved(_ cityID: String) -> Bool {
        record(forCity: cityID) != nil
    }

    var totalByteCount: Int64 {
        lock.withLock { manifest.cities.values.reduce(0) { $0 + $1.byteCount } }
    }

    func summary(forKey key: String) -> SavedSummary? {
        lock.withLock { summaries[key] }
    }

    func history(forArticle title: String) -> CampusHistory? {
        lock.withLock { histories[title] }
    }

    /// The saved photo for this web address, or nil if no saved city has it.
    func localImageURL(for remoteURL: URL?) -> URL? {
        guard let remoteURL, !remoteURL.isFileURL else { return nil }
        let name = imageFileName(for: remoteURL)
        let isSaved = lock.withLock { savedImageFiles.contains(name) }
        return isSaved ? imagesDirectory.appendingPathComponent(name) : nil
    }

    /// What a photo view should load: the saved file when there is one, otherwise the web address.
    /// (AsyncImage loads file URLs the same way it loads web ones.)
    func displayURL(for remoteURL: URL?) -> URL? {
        localImageURL(for: remoteURL) ?? remoteURL
    }

    // MARK: Saving (used by OfflineDownloader, off the main thread)

    /// True if the photo is already on disk, from this save or an earlier, interrupted one
    func hasImageFile(for remoteURL: URL) -> Bool {
        fileManager.fileExists(atPath: imageFileURL(for: remoteURL).path)
    }

    func writeImage(_ data: Data, for remoteURL: URL) throws {
        try createFolders()
        try data.write(to: imageFileURL(for: remoteURL), options: .atomic)
    }

    /// Records a finished city: writes its text file and adds it to the manifest.
    /// Photos must already be written with `writeImage`; ones that aren't on disk are left out.
    @discardableResult
    func commit(cityID: String, cityName: String, content: OfflineCityContent,
                imageURLs: [URL], savedAt: Date = Date()) throws -> OfflineCityRecord {
        try createFolders()
        let contentURL = contentFileURL(forCity: cityID)
        try JSONEncoder().encode(content).write(to: contentURL, options: .atomic)

        var bytes = fileSize(contentURL)
        var files: [String] = []
        for url in imageURLs {
            let name = imageFileName(for: url)
            let fileURL = imagesDirectory.appendingPathComponent(name)
            guard !files.contains(name), fileManager.fileExists(atPath: fileURL.path) else { continue }
            files.append(name)
            bytes += fileSize(fileURL)
        }

        let record = OfflineCityRecord(cityID: cityID, cityName: cityName, savedAt: savedAt,
                                       byteCount: bytes, imageFiles: files)
        try lock.withLock {
            manifest.cities[cityID] = record
            try writeManifestLocked()
            reloadLocked()
        }
        return record
    }

    /// Deletes a city's saved copy. Photos another saved city still uses are kept.
    func remove(cityID: String) throws {
        try lock.withLock {
            manifest.cities[cityID] = nil
            try writeManifestLocked()
            try? fileManager.removeItem(at: contentFileURL(forCity: cityID))
            pruneImagesLocked()
            reloadLocked()
        }
    }

    /// Deletes photos no saved city lists, e.g. left over from a cancelled save.
    func pruneUnusedImages() {
        lock.withLock { pruneImagesLocked() }
    }

    // MARK: Private

    private func createFolders() throws {
        guard !fileManager.fileExists(atPath: imagesDirectory.path) || !fileManager.fileExists(atPath: citiesDirectory.path) else { return }
        try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: citiesDirectory, withIntermediateDirectories: true)
        // Can be downloaded again, so it doesn't belong in the user's iCloud backup
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var rootURL = root
        try? rootURL.setResourceValues(values)
    }

    private func writeManifestLocked() throws {
        try createFolders()
        try JSONEncoder().encode(manifest).write(to: manifestURL, options: .atomic)
    }

    /// Reads the manifest and every saved city's text into the in-memory index
    private func reloadLocked() {
        if let data = try? Data(contentsOf: manifestURL),
           let decoded = try? JSONDecoder().decode(OfflineManifest.self, from: data) {
            manifest = decoded
        } else {
            manifest = OfflineManifest()
        }

        summaries = [:]
        histories = [:]
        savedImageFiles = []
        for record in manifest.cities.values {
            savedImageFiles.formUnion(record.imageFiles)
            guard let data = try? Data(contentsOf: contentFileURL(forCity: record.cityID)),
                  let content = try? JSONDecoder().decode(OfflineCityContent.self, from: data)
            else { continue }
            summaries.merge(content.summaries) { current, _ in current }
            histories.merge(content.histories) { current, _ in current }
        }
    }

    private func pruneImagesLocked() {
        let inUse = Set(manifest.cities.values.flatMap(\.imageFiles))
        let files = (try? fileManager.contentsOfDirectory(atPath: imagesDirectory.path)) ?? []
        for name in files where !inUse.contains(name) {
            try? fileManager.removeItem(at: imagesDirectory.appendingPathComponent(name))
        }
    }

    private func fileSize(_ url: URL) -> Int64 {
        let size = (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value
        return size ?? 0
    }

    private static func hash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
