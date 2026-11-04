//
//  PassportProgress.swift
//  PassportWidget
//
//  What the widget shows, read from the same App Group UserDefaults that
//  GlobalProgressManager (VisitManager.swift) writes. The app reloads the widget after
//  every save, so a new stamp shows up right away.
//

import Foundation

/// One stamped landmark, with the city it belongs to and when it was stamped.
struct WidgetStamp: Hashable {
    let landmarkName: String
    let cityName: String
    /// Nil for stamps saved before the app started recording dates
    let date: Date?

    /// Opens this stamp's city in the app (WebLinkRouter handles stamped://city/…)
    var cityURL: URL? {
        var components = URLComponents()
        components.scheme = "stamped"
        components.host = "city"
        components.path = "/" + cityName
        return components.url
    }
}

struct PassportProgress {
    let landmarkCount: Int
    let cityCount: Int
    /// The five newest, newest first (the large widget lists them all); only stamps
    /// the widget could match to a city
    let recentStamps: [WidgetStamp]

    var latestStamp: WidgetStamp? { recentStamps.first }

    static let empty = PassportProgress(landmarkCount: 0, cityCount: 0, recentStamps: [])

    /// Made-up data for the widget gallery and previews.
    static let sample = PassportProgress(
        landmarkCount: 42,
        cityCount: 7,
        recentStamps: [
            WidgetStamp(landmarkName: "Willis Tower", cityName: "Chicago", date: .now.addingTimeInterval(-3_600)),
            WidgetStamp(landmarkName: "The Rookery", cityName: "Chicago", date: .now.addingTimeInterval(-90_000)),
            WidgetStamp(landmarkName: "Fenway Park", cityName: "Boston", date: .now.addingTimeInterval(-700_000)),
            WidgetStamp(landmarkName: "Tokyo Tower", cityName: "Tokyo", date: .now.addingTimeInterval(-2_000_000)),
            WidgetStamp(landmarkName: "Gateway Arch", cityName: "St. Louis", date: .now.addingTimeInterval(-2_600_000))
        ]
    )

    // Keys written by GlobalProgressManager
    private static let visitedKey = "GlobalVisitedBuildingsKey"
    private static let visitDatesKey = "GlobalVisitDatesKey"

    static func load() -> PassportProgress {
        let defaults = UserDefaults(suiteName: "group.stamped.passport") ?? .standard
        let visitedIDs = (defaults.array(forKey: visitedKey) as? [String]) ?? []
        let timestamps = (defaults.dictionary(forKey: visitDatesKey) as? [String: Double]) ?? [:]

        // Landmark IDs don't say which city they're in, so look each one up in the registry
        let stamps = visitedIDs.compactMap { id -> WidgetStamp? in
            guard let landmark = LandmarkIndex.shared[id] else { return nil }
            return WidgetStamp(
                landmarkName: landmark.name,
                cityName: landmark.cityName,
                date: timestamps[id].map { Date(timeIntervalSince1970: $0) }
            )
        }

        // Newest first; undated (older) stamps go last, by name so the order stays put
        let sorted = stamps.sorted { first, second in
            switch (first.date, second.date) {
            case let (firstDate?, secondDate?): return firstDate > secondDate
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return first.landmarkName < second.landmarkName
            }
        }

        return PassportProgress(
            landmarkCount: visitedIDs.count,
            cityCount: Set(stamps.map(\.cityName)).count,
            recentStamps: Array(sorted.prefix(5))
        )
    }
}

/// Landmark ID → name and city, from the app's BuildingRegistry.json
/// (the widget target bundles the same file; see the project's membership exceptions).
enum LandmarkIndex {
    struct Entry {
        let name: String
        let cityName: String
    }

    /// Only the two fields the widget needs, so decoding skips the rest of each landmark
    private struct RegistryLandmark: Decodable {
        let id: String
        let name: String
    }

    /// A `static let` is built once, the first time it's used, and kept while the
    /// widget's process stays alive
    static let shared: [String: Entry] = {
        guard let url = Bundle.main.url(forResource: "BuildingRegistry", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let registry = try? JSONDecoder().decode([String: [RegistryLandmark]].self, from: data)
        else { return [:] }

        var index: [String: Entry] = [:]
        for (cityName, landmarks) in registry {
            for landmark in landmarks {
                index[landmark.id] = Entry(name: landmark.name, cityName: cityName)
            }
        }
        return index
    }()
}
