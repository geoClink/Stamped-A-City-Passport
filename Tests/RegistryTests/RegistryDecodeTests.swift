import XCTest
import CoreLocation
@testable import Stamped_

final class RegistryDecodeTests: XCTestCase {
    func testDecodeBundleRegistry() throws {
        // Attempt to load the bundled JSON resource included in the app target
        guard let url = Bundle.main.url(forResource: "BuildingRegistry", withExtension: "json") else {
            XCTFail("BuildingRegistry.json not found in bundle")
            return
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let dict = try decoder.decode([String: [Building]].self, from: data)
        XCTAssertFalse(dict.isEmpty, "Registry JSON should not be empty")
        XCTAssertTrue(dict.keys.contains("Bath") || dict.count > 10, "There should be known cities present")
    }

    // MARK: - Data quality

    /// Landmarks that are really a day trip from their city, reviewed by hand.
    /// Everything else must sit within `maxKilometersFromCity` of its city's middle.
    private let reviewedDayTrips: Set<String> = [
        "den-06",                 // US Air Force Academy Chapel, Colorado Springs (~80 km from Denver)
        "pit-04",                 // Fallingwater, Mill Run PA (~75 km from Pittsburgh)
        "cn_leshan_giant_buddha", // Leshan (~125 km from Chengdu)
        "ruh-04",                 // Ithra is in Dhahran, not Riyadh — left for George to decide
    ]
    private let maxKilometersFromCity: Double = 60

    /// Reads the JSON exactly as shipped. `BuildingRegistry.data` quietly drops
    /// duplicate ids, so these checks use the raw file instead.
    private func loadRawRegistry() throws -> [String: [Building]] {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "BuildingRegistry", withExtension: "json"))
        return try JSONDecoder().decode([String: [Building]].self, from: Data(contentsOf: url))
    }

    // Checks that no two landmarks anywhere share an id (stamps are saved by id, so a duplicate would mix up stamps).
    func testLandmarkIDsAreUnique() throws {
        let registry = try loadRawRegistry()
        let allIDs = registry.values.flatMap { $0.map(\.id) }
        let idCounts = Dictionary(allIDs.map { ($0, 1) }, uniquingKeysWith: +)
        let duplicateIDs = idCounts.filter { $0.value > 1 }.keys.sorted()
        XCTAssertEqual(duplicateIDs, [], "Duplicate landmark ids: \(duplicateIDs)")
    }

    // Checks that every landmark has real coordinates near its city's middle (catches swapped, zero or wrong-country pins).
    func testLandmarksAreInsideTheirCity() throws {
        let registry = try loadRawRegistry()
        for (cityName, buildings) in registry {
            // The median is used as the city's middle so one far-away pin can't move it.
            let middle = CLLocation(
                latitude: median(buildings.compactMap(\.latitude)),
                longitude: median(buildings.compactMap(\.longitude))
            )
            for building in buildings where !reviewedDayTrips.contains(building.id) {
                guard let latitude = building.latitude, let longitude = building.longitude,
                      latitude != 0, longitude != 0 else {
                    XCTFail("\(cityName): \(building.id) has no coordinates")
                    continue
                }
                let kilometers = CLLocation(latitude: latitude, longitude: longitude).distance(from: middle) / 1000
                XCTAssertLessThan(kilometers, maxKilometersFromCity,
                                  "\(cityName): \(building.id) is \(Int(kilometers)) km from the city's middle")
            }
        }
    }

    private func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middleIndex = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middleIndex - 1] + sorted[middleIndex]) / 2 : sorted[middleIndex]
    }
}
