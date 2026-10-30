//
//  LandmarkPanorama.swift
//  Stamped!
//
//  A free 360° photo taken at or inside a landmark, from Wikimedia Commons.
//  The Vision Pro app wraps it around the viewer ("Stand inside").
//  The list is made at build time by tools/landmark-panoramas/find_panoramas.py
//  and bundled as LandmarkPanoramas.json (building ID → panorama).
//
//  Shared with the Tally-AVP target (see the membership exceptions in the
//  project file), so the iPhone test target can check the JSON too.
//

import Foundation

struct LandmarkPanorama: Codable, Hashable, Sendable {
    let buildingID: String
    let landmarkName: String
    let city: String
    /// "File:Something.jpg" on Commons
    let fileTitle: String
    /// The Commons page with the full licence and description
    let filePageURL: URL
    /// About 4K wide: big enough to look sharp around you, small enough to load quickly
    let imageURL: URL
    let fullSizeURL: URL
    let width: Int
    let height: Int
    let author: String
    /// One of `allowedLicenses` ("CC BY-SA" etc.)
    let license: String
    /// The exact licence as Commons names it ("CC BY-SA 4.0")
    let licenseName: String
    let licenseURL: URL

    /// Only licences that let the app show the photo commercially (no NC / ND).
    static let allowedLicenses: Set<String> = ["CC0", "Public domain", "CC BY", "CC BY-SA"]

    /// Every bundled panorama, keyed by building ID. Empty if the file is missing.
    static func loadAll(from bundle: Bundle = .main) -> [String: LandmarkPanorama] {
        guard let url = bundle.url(forResource: "LandmarkPanoramas", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let panoramas = try? JSONDecoder().decode([String: LandmarkPanorama].self, from: data)
        else { return [:] }
        return panoramas
    }
}
