//
//  OfflineDownloader.swift
//  Stamped! A City Passport
//
//  Runs "Save for Offline" for one city at a time: fetches the city's own Wikipedia
//  summary and header photo, the campus History card, then each landmark's summary and
//  photo, one after another, and hands them to OfflineStore.
//
//  Gentle on battery and data:
//  - only runs when the user taps Save (nothing in the background)
//  - one request at a time, photos at the app's display size (about 0.2–0.5 MB each)
//  - respects Low Data Mode (photo downloads stop and say so)
//  - Cancel stops after the current request; photos already downloaded are kept,
//    so the next Save picks up where it stopped
//

import Foundation
import Combine

@MainActor
final class OfflineDownloader: ObservableObject {
    static let shared = OfflineDownloader()

    enum Failure: Equatable {
        case connection, lowDataMode, storage
    }

    enum Status: Equatable {
        case idle
        case saving(cityID: String, done: Int, total: Int)
        case failed(cityID: String, Failure)
    }

    @Published private(set) var status: Status = .idle
    /// Every saved city, for the city page and Settings
    @Published private(set) var savedCities: [OfflineCityRecord]

    private let store: OfflineStore
    private let session: URLSession
    private var task: Task<Void, Never>?

    init(store: OfflineStore = .shared) {
        self.store = store
        self.savedCities = store.savedCities

        let configuration = URLSessionConfiguration.default
        // Low Data Mode: don't download photos (the request fails with a "constrained" reason)
        configuration.allowsConstrainedNetworkAccess = false
        configuration.timeoutIntervalForRequest = 30
        // The photos are kept by OfflineStore; no need for a second copy in the URL cache
        configuration.urlCache = nil
        // Wikimedia asks apps to identify themselves (same as WikimediaService)
        configuration.httpAdditionalHeaders = ["User-Agent": "Stamped-A-City-Passport/2.3 (iOS)"]
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Queries

    func record(for city: CityLocation.City) -> OfflineCityRecord? {
        savedCities.first { $0.cityID == city.id }
    }

    var isBusy: Bool {
        if case .saving = status { return true }
        return false
    }

    // MARK: - Actions

    func save(_ city: CityLocation.City) {
        // One city at a time keeps memory and battery use low
        guard task == nil else { return }
        task = Task {
            await run(city)
            task = nil
        }
    }

    func cancel() {
        task?.cancel()
    }

    func remove(cityID: String) {
        let store = store
        Task {
            let removed = await Task.detached { (try? store.remove(cityID: cityID)) != nil }.value
            savedCities = store.savedCities
            if !removed { status = .failed(cityID: cityID, .storage) }
        }
    }

    // MARK: - Download

    private func run(_ city: CityLocation.City) async {
        let buildings = city.buildings
        // The city's own article counts as one step, then one per landmark
        let total = buildings.count + 1
        status = .saving(cityID: city.id, done: 0, total: total)

        var content = OfflineCityContent()
        var imageURLs: [URL] = []

        do {
            // 1. The city header: its Wikipedia article (CityHeroHeader / citySummary)
            let cityTitle = WikimediaService.cityTitleOverrides[city.name] ?? city.name
            let citySummary = try await WikimediaService.shared.summaryForSaving(for: cityTitle)
            content.summaries[cityTitle] = SavedSummary(photoURL: citySummary.photoURL,
                                                        extract: citySummary.extract,
                                                        articleTitle: citySummary.articleTitle)
            // Campuses show their first landmark's photo instead (see CityHeroHeader)
            if !city.isCampus, let url = citySummary.photoURL, try await saveImage(url) {
                imageURLs.append(url)
            }
            // Campuses: the History card
            if let title = city.historyArticleTitle,
               let history = await CampusHistoryService.shared.history(forArticle: title) {
                content.histories[title] = history
            }
            status = .saving(cityID: city.id, done: 1, total: total)

            // 2. Each landmark, one at a time
            for (index, building) in buildings.enumerated() {
                try Task.checkCancellation()
                let summary = try await WikimediaService.shared.summaryForSaving(for: building.name, buildingID: building.id)
                content.summaries[building.id] = SavedSummary(photoURL: summary.photoURL,
                                                              extract: summary.extract,
                                                              articleTitle: summary.articleTitle)
                if let url = summary.photoURL, try await saveImage(url) {
                    imageURLs.append(url)
                }
                status = .saving(cityID: city.id, done: index + 2, total: total)
            }

            try Task.checkCancellation()

            // 3. Record it (file work off the main thread)
            let store = store
            let cityID = city.id
            let cityName = city.name
            let finished = content
            let urls = imageURLs
            _ = try await Task.detached {
                try store.commit(cityID: cityID, cityName: cityName, content: finished, imageURLs: urls)
            }.value
            savedCities = store.savedCities
            status = .idle
        } catch is CancellationError {
            status = .idle
        } catch let error as URLError {
            if error.code == .cancelled {
                status = .idle
            } else if error.networkUnavailableReason == .constrained {
                status = .failed(cityID: city.id, .lowDataMode)
            } else {
                status = .failed(cityID: city.id, .connection)
            }
        } catch {
            status = .failed(cityID: city.id, .storage)
        }
    }

    /// Downloads one photo unless it's already on disk. Returns false when the photo
    /// itself is missing (e.g. a 404), which skips it; throws when the connection fails.
    private func saveImage(_ url: URL) async throws -> Bool {
        let store = store
        if await Task.detached(operation: { store.hasImageFile(for: url) }).value { return true }

        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200, !data.isEmpty else { return false }
        try await Task.detached { try store.writeImage(data, for: url) }.value
        return true
    }
}
