//
//  VisionStore.swift
//  Tally-AVP
//
//  Loads every city's landmarks once, and reads the stamps the iPhone app saves
//  to iCloud. Both apps share a bundle ID, so they share the same iCloud
//  key-value store: stamps collected on iPhone show up here automatically.
//

import Foundation
import Observation

@MainActor
@Observable
final class VisionStore {
    static let shared = VisionStore()

    /// City name → its landmarks, decoded once from BuildingRegistry.json.
    private(set) var buildingsByCity: [String: [Building]] = [:]
    /// Building IDs the user has stamped on any of their devices.
    private(set) var visitedIDs: Set<String> = []

    var cityNames: [String] { buildingsByCity.keys.sorted() }

    // Same key the iPhone app's GlobalProgressManager uses.
    private let visitedKey = "GlobalVisitedBuildingsKey"
    private let iCloud = NSUbiquitousKeyValueStore.default

    private init() {
        if let url = Bundle.main.url(forResource: "BuildingRegistry", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let dict = try? JSONDecoder().decode([String: [Building]].self, from: data) {
            buildingsByCity = dict.mapValues { $0.sorted { $0.name < $1.name } }
        }

        iCloud.synchronize()
        loadVisited()

        // Refresh when the iPhone app stamps something new
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloud,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.loadVisited() }
        }
    }

    func buildings(for city: String) -> [Building] {
        buildingsByCity[city] ?? []
    }

    func visitedCount(for city: String) -> Int {
        buildings(for: city).filter { visitedIDs.contains($0.id) }.count
    }

    private func loadVisited() {
        let saved = iCloud.array(forKey: visitedKey) as? [String] ?? []
        visitedIDs = Set(saved)
    }
}
