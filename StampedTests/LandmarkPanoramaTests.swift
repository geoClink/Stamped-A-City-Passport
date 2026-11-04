//
//  LandmarkPanoramaTests.swift
//  StampedTests
//
//  LandmarkPanoramas.json (the Vision Pro "360° View" photos): it decodes,
//  every key is a real landmark, licences are ones we're allowed to use,
//  and every link is https.
//

import XCTest
@testable import Stamped_

@MainActor
final class LandmarkPanoramaTests: XCTestCase {

    /// Decodes the bundled file strictly (a typo in a field name fails here,
    /// where LandmarkPanorama.loadAll() would quietly return nothing).
    private func loadPanoramas() throws -> [String: LandmarkPanorama] {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "LandmarkPanoramas", withExtension: "json"),
                                "LandmarkPanoramas.json is missing from the app bundle")
        return try JSONDecoder().decode([String: LandmarkPanorama].self, from: Data(contentsOf: url))
    }

    /// The file decodes, isn't empty, and the app's loader sees the same entries.
    func testFileDecodes() throws {
        let panoramas = try loadPanoramas()
        XCTAssertFalse(panoramas.isEmpty)
        XCTAssertEqual(LandmarkPanorama.loadAll().count, panoramas.count)
    }

    /// Every key is the ID of a landmark in BuildingRegistry.json, and matches the entry's own ID.
    func testKeysAreRealBuildingIDs() throws {
        let registryURL = try XCTUnwrap(Bundle.main.url(forResource: "BuildingRegistry", withExtension: "json"))
        let registry = try JSONDecoder().decode([String: [Building]].self, from: Data(contentsOf: registryURL))
        let buildingIDs = Set(registry.values.flatMap { $0 }.map(\.id))

        for (key, panorama) in try loadPanoramas() {
            XCTAssertTrue(buildingIDs.contains(key), "\(key) is not a building ID")
            XCTAssertEqual(key, panorama.buildingID)
        }
    }

    /// Only CC0, public domain, CC BY and CC BY-SA: never non-commercial (NC) or no-derivatives (ND).
    func testLicencesAreAllowed() throws {
        for (key, panorama) in try loadPanoramas() {
            XCTAssertTrue(LandmarkPanorama.allowedLicenses.contains(panorama.license),
                          "\(key) has licence \(panorama.license)")
            // "CC BY-NC-SA 4.0" → ["CC", "BY", "NC", "SA", "4", "0"]
            let licenceParts = Set(panorama.licenseName.uppercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
            XCTAssertTrue(licenceParts.isDisjoint(with: ["NC", "ND"]), "\(key): \(panorama.licenseName)")
            XCTAssertFalse(panorama.author.trimmingCharacters(in: .whitespaces).isEmpty, "\(key) has no author")
        }
    }

    /// All links are https (visionOS blocks plain http), and photos are 2:1 equirectangular.
    func testURLsAreHTTPSAndPhotosAre2to1() throws {
        for (key, panorama) in try loadPanoramas() {
            for url in [panorama.imageURL, panorama.fullSizeURL, panorama.filePageURL, panorama.licenseURL] {
                XCTAssertEqual(url.scheme, "https", "\(key): \(url)")
            }
            XCTAssertEqual(Double(panorama.width) / Double(panorama.height), 2.0, accuracy: 0.02, key)
        }
    }
}
