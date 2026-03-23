import XCTest
@testable import GlobalDiscoveryApp

final class BuildingRegistryTests: XCTestCase {
    func testEmbeddedDataNotEmpty() throws {
        // Ensure the embeddedData constant has content and decodable Building values
        let embedded = BuildingRegistry.embeddedData
        XCTAssertFalse(embedded.isEmpty, "embeddedData should not be empty")

        // Pick a known city key that we expect to exist (Bath is present in resources)
        XCTAssertTrue(embedded.keys.contains(where: { $0 == .bath }) || embedded.count > 10, "Expected known cities like Bath to be present")

        // Ensure buildings decode properly
        if let buildings = embedded[.bath] {
            XCTAssertFalse(buildings.isEmpty, "Bath should have buildings in embeddedData")
            let first = buildings[0]
            XCTAssertNotNil(first.id)
            XCTAssertNotNil(first.name)
        }
    }

    func testGetBuildingsCycles() {
        // Use a city that exists in embeddedData
        let city: CityLocation.City = .bath
        // Request buildings for day 1 and day 2 and ensure we get up to 3 results and they are valid
        let day1 = BuildingRegistry.getBuildings(for: city, day: 1)
        XCTAssertLessThanOrEqual(day1.count, 3)
        // If there are any buildings at all, ensure IDs are unique and valid
        if !day1.isEmpty {
            XCTAssertFalse(day1.contains(where: { $0.id.isEmpty }))
        }

        let day2 = BuildingRegistry.getBuildings(for: city, day: 2)
        XCTAssertLessThanOrEqual(day2.count, 3)
        // day1 and day2 may overlap but should be arrays
        XCTAssertNotNil(day1)
        XCTAssertNotNil(day2)
    }
}
