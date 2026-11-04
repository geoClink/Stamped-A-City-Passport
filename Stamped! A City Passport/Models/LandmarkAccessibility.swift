//
//  LandmarkAccessibility.swift
//  Stamped! A City Passport
//
//  Step-free (wheelchair) access for a landmark, as OpenStreetMap's volunteers mapped it.
//  It comes from Resources/LandmarkAccessibility.json, made at build time by
//  tools/accessibility-data/build_accessibility.py. A landmark is only in the file when
//  OSM has a confident match with a wheelchair tag: nothing is guessed.
//  OSM data is © OpenStreetMap contributors, under the ODbL.
//

import Foundation

/// One landmark's entry in LandmarkAccessibility.json.
nonisolated struct LandmarkAccessibility: Decodable, Equatable {
    /// OSM's `wheelchair` tag, as written in the file ("yes", "limited" or "no")
    let wheelchair: String
    /// OSM's `toilets:wheelchair` tag ("yes" or "no"); missing when OSM doesn't say
    let toiletsWheelchair: String?
    /// "node", "way" or "relation", for the link to the feature on openstreetmap.org
    let osmType: String
    let osmID: String

    /// What OSM's wheelchair values mean for a visitor.
    enum StepFreeAccess: String {
        case yes       // step-free everywhere that matters
        case limited   // step-free to part of it, or with help
        case no
    }

    /// nil only if the file had a value we don't know (the tests stop that shipping)
    var stepFreeAccess: StepFreeAccess? { StepFreeAccess(rawValue: wheelchair) }

    /// true / false when OSM says whether there are accessible toilets, nil when it doesn't
    var hasAccessibleToilets: Bool? {
        switch toiletsWheelchair {
        case "yes": return true
        case "no": return false
        default: return nil
        }
    }

    /// The feature's page on openstreetmap.org, where anyone can check or correct it
    var osmURL: URL? {
        URL(string: "https://www.openstreetmap.org/\(osmType)/\(osmID)")
    }
}

/// Loads LandmarkAccessibility.json once. Building id → its OSM accessibility data.
enum LandmarkAccessibilityStore {
    private static let byBuildingID: [String: LandmarkAccessibility] = {
        guard let url = Bundle.main.url(forResource: "LandmarkAccessibility", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return [:] }
        return decode(data)
    }()

    /// Separate from the bundle lookup so the tests can check the real file's format
    nonisolated static func decode(_ data: Data) -> [String: LandmarkAccessibility] {
        (try? JSONDecoder().decode([String: LandmarkAccessibility].self, from: data)) ?? [:]
    }

    static func accessibility(for buildingID: String) -> LandmarkAccessibility? {
        byBuildingID[buildingID]
    }
}
