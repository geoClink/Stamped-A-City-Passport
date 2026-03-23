//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/13/26.
//

import Foundation

struct BuildingRegistry {

    // Replaced the huge compile-time literal with a runtime loader to avoid
    // compile-time crashes and to keep the API compatible with callers/tests.
    // Public API compatibility:
    //  - `embeddedData` remains available (now populated at runtime from bundle JSON)
    //  - `data` remains available and follows: Documents override -> bundle -> embeddedData

    /// Embedded data (was previously a huge static literal). Populated at runtime
    /// by decoding the bundled `Resources/BuildingRegistry.json` file.
    static let embeddedData: [CityLocation.City: [Building]] = {
        return loadFromBundle() ?? [:]
    }()

    /// Try to load a JSON file placed in the app's Documents folder. This allows
    /// runtime overrides (for development or remote updates saved to disk).
    private static func loadFromDocuments() -> [CityLocation.City: [Building]]? {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let url = docs.appendingPathComponent("BuildingRegistry.json")
        guard fm.fileExists(atPath: url.path) else { return nil }
        do {
            let raw = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let dict = try decoder.decode([String: [Building]].self, from: raw)
            var mapped: [CityLocation.City: [Building]] = [:]
            for (k, v) in dict {
                if let city = CityLocation.City(rawValue: k) {
                    mapped[city] = v
                }
            }
            print("BuildingRegistry: loaded JSON from Documents with \(mapped.keys.count) cities")
            return mapped
        } catch {
            print("BuildingRegistry: failed to load from Documents: \(error)")
            return nil
        }
    }

    /// Primary data source used by the app. Lookup order:
    /// 1) Documents/BuildingRegistry.json (runtime override)
    /// 2) Bundled Resources/BuildingRegistry.json
    /// 3) embeddedData (falls back to whatever bundle provided earlier)
    static var data: [CityLocation.City: [Building]] {
        if let docs = loadFromDocuments() { return docs }
        if let bundle = loadFromBundle() { return bundle }
        return embeddedData
    }
    
    
    // Fallback embedded registry data (was `data`)
  
                           
                      
                    
          

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
            // Log successful load with number of cities to make runtime verification easy
            print("BuildingRegistry: loaded JSON from bundle with \(dict.keys.count) cities")
            return mapped
        } catch {
            print("BuildingRegistry: failed to load JSON from bundle: \(error)")
            return nil
        }
    }

    // Note: `data` is implemented later as a remote-first Documents -> bundle -> embedded loader.

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

}

