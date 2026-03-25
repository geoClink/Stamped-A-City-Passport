//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/13/26.
//

import Foundation

struct BuildingRegistry {
    // Minimal embedded fallback in case bundle JSON isn't available.
    // Keep this small to avoid large compile-time literals; it's only a last-resort fallback.
    static let embeddedData: [CityLocation.City: [Building]] = [:]

    // Cache decoded registry so subsequent accesses are fast and do not re-log.
    private static var cachedData: [CityLocation.City: [Building]]?

    // Attempt to load a JSON file named "BuildingRegistry.json" from the app bundle.
    private static func loadFromBundle() -> [CityLocation.City: [Building]]? {
        guard let url = Bundle.main.url(forResource: "BuildingRegistry", withExtension: "json") else {
            return nil
        }

        do {
            let raw = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            // Decode as [String: [Building]] where keys are CityLocation.City rawValues
            let dict = try decoder.decode([String: [Building]].self, from: raw)
            var mapped: [CityLocation.City: [Building]] = [:]
            for (k, v) in dict {
                if let city = CityLocation.City(rawValue: k) {
                    mapped[city] = v
                }
            }
            // Ensure no duplicate landmarks are present for any city by unique id
            for (city, buildings) in mapped {
                let unique = Array(Dictionary(grouping: buildings, by: { $0.id }).values.compactMap { $0.first })
                mapped[city] = unique
            }
            // Log successful load with number of cities to make runtime verification easy
            print("BuildingRegistry: loaded JSON from bundle with \(dict.keys.count) cities")
            return mapped
        } catch {
            print("BuildingRegistry: failed to load JSON from bundle: \(error)")
            return nil
        }
    }

    // Public `data` prefers bundle-provided JSON and falls back to the embedded data.
    static var data: [CityLocation.City: [Building]] {
        if let c = cachedData { return c }
        // Ensure no duplicate landmarks are present for any city by unique id
        let loaded = loadFromBundle() ?? embeddedData.mapValues { buildings in
            Array(Dictionary(grouping: buildings, by: { $0.id }).values.compactMap { $0.first })
        }
        cachedData = loaded
        return loaded
    }

    // MARK: - Add this inside your BuildingRegistry struct
    static func getBuildings(for city: CityLocation.City, day: Int) -> [Building] {
        // 1. Look up the city in your data dictionary
        guard let allBuildings = data[city], !allBuildings.isEmpty else {
            return [] // Return empty if city not found
        }

        // 2. Decide how many buildings to show per day (usually 3 or 4)
        let buildingsPerDay = 3

        // 3. Calculate which buildings to pull based on the day
        // This logic "cycles" through the list if you have a lot of buildings
        let startIndex = ((day - 1) * buildingsPerDay) % allBuildings.count
        let endIndex = min(startIndex + buildingsPerDay, allBuildings.count)

        return Array(allBuildings[startIndex..<endIndex])
    }
    
    /// Finds a building by its unique string ID, searching all cities.
    static func getBuilding(by id: String) -> Building? {
        for buildings in data.values {
            if let found = buildings.first(where: { $0.id == id }) {
                return found
            }
        }
        return nil
    }
    
    /// Returns all buildings for a given city ID (String).
    static func getAllBuildings(forCityName cityID: String) -> [Building] {
        // Try to convert cityID to CityLocation.City
        if let city = CityLocation.City(rawValue: cityID) {
            return data[city] ?? []
        }
        return []
    }
}
