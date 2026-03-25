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
    let height: Int
    let foodSpots: [String]
    let currency: String
    // Optional geographic coordinates — preferred if present in the registry JSON
    let latitude: Double?
    let longitude: Double?
}
