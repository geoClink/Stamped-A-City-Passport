//
//  LandmarkAccessibilityTests.swift
//  StampedTests
//
//  Checks LandmarkAccessibility.json, the step-free access data from OpenStreetMap:
//  it decodes, every entry belongs to a real landmark, and it only holds the values
//  OSM uses, so the detail page never shows something we can't word.
//

import XCTest
@testable import Stamped_

final class LandmarkAccessibilityTests: XCTestCase {

    private func fileData() throws -> Data {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "LandmarkAccessibility", withExtension: "json"),
                                "LandmarkAccessibility.json isn't in the app bundle")
        return try Data(contentsOf: url)
    }

    /// Every building id in the registry
    private func registryIDs() throws -> Set<String> {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "BuildingRegistry", withExtension: "json"))
        let registry = try JSONDecoder().decode([String: [Building]].self, from: Data(contentsOf: url))
        return Set(registry.values.flatMap { $0 }.map(\.id))
    }

    // The file decodes, and no entry was dropped while decoding
    func testFileDecodes() throws {
        let data = try fileData()
        let entries = LandmarkAccessibilityStore.decode(data)
        XCTAssertFalse(entries.isEmpty, "LandmarkAccessibility.json didn't decode")
        let rawKeys = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]).keys
        XCTAssertEqual(entries.count, rawKeys.count)
    }

    // Every key is a real building id (stamps and pages are found by id)
    func testEveryKeyIsARealBuilding() throws {
        let ids = try registryIDs()
        for buildingID in LandmarkAccessibilityStore.decode(try fileData()).keys {
            XCTAssertTrue(ids.contains(buildingID), "\(buildingID) isn't in BuildingRegistry.json")
        }
    }

    // Only OSM's yes / limited / no, toilets only yes / no, and a working OSM link
    func testValuesAreOnlyOSMValues() throws {
        for (buildingID, entry) in LandmarkAccessibilityStore.decode(try fileData()) {
            XCTAssertTrue(["yes", "limited", "no"].contains(entry.wheelchair), "\(buildingID): wheelchair=\(entry.wheelchair)")
            XCTAssertNotNil(entry.stepFreeAccess)
            if let toilets = entry.toiletsWheelchair {
                XCTAssertTrue(["yes", "no"].contains(toilets), "\(buildingID): toilets:wheelchair=\(toilets)")
            }
            XCTAssertTrue(["node", "way", "relation"].contains(entry.osmType), "\(buildingID): osmType=\(entry.osmType)")
            XCTAssertNotNil(Int(entry.osmID), "\(buildingID): osmID isn't a number")
            XCTAssertEqual(entry.osmURL?.host, "www.openstreetmap.org")
        }
    }

    // The store finds an entry by id, and has nothing for an unknown id
    func testStoreLookup() throws {
        let entries = LandmarkAccessibilityStore.decode(try fileData())
        let (buildingID, entry) = try XCTUnwrap(entries.first)
        XCTAssertEqual(LandmarkAccessibilityStore.accessibility(for: buildingID), entry)
        XCTAssertNil(LandmarkAccessibilityStore.accessibility(for: "not_a_building"))
    }
}
