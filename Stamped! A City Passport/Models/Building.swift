//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/23/26.
//

import Foundation
// 1. Define the Building first so the City can use it.
struct Building: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let assetName: String
    let description: String
    let architect: String
    let yearBuilt: Int
    let address: String
    let oldUse: String
    let newUse: String
    let buildingStyle: String
    let numberOfStories: Int
    let height: Double
    let foodSpots: [String]
    let currency: String
    // Optional geographic coordinates — preferred if present in the registry JSON
    let latitude: Double?
    let longitude: Double?

    // Natural places (lakes, mountains, villages) have no build date, so the
    // registry stores 0 for them. Screens use this to hide the year.
    var hasKnownYear: Bool { yearBuilt != 0 }

    // Some campus buildings have no documented architect or style; the registry stores
    // "Unknown" for them. Screens show nothing instead of the word "Unknown".
    // ("Unknown (Norman builders)" says something, so it counts as known.)
    var knownArchitect: String? { Self.known(architect) }
    var knownStyle: String? { Self.known(buildingStyle) }

    private static func known(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed.lowercased() == "unknown" ? nil : trimmed
    }
}
