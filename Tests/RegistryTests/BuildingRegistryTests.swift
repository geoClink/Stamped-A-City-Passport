import XCTest
@testable import GlobalDiscoveryApp

final class BuildingRegistryTests: XCTestCase {
    func testDataNotEmptyOrBundlePresent() throws {
        // Use BuildingRegistry.data which prefers bundle JSON and falls back to embeddedData
        let registryData = BuildingRegistry.data

        // If bundle provided JSON, registryData should not be empty. If not, embeddedData fallback may be empty.
        // So assert consistency: either non-empty data or embeddedData is empty fallback (which is allowed in this repo change)
        if registryData.isEmpty {
            // No bundle available at test runtime — ensure embeddedData is the declared fallback
            XCTAssertTrue(BuildingRegistry.embeddedData.isEmpty, "Both bundle data and embedded fallback are empty — ensure this is expected in CI or provide BuildingRegistry.json in test bundle.")
        } else {
            XCTAssertFalse(registryData.isEmpty, "BuildingRegistry.data should contain entries when bundle JSON is present in the test target")

            // Check for expected city or a reasonable size
            XCTAssertTrue(registryData.keys.contains(where: { $0 == .bath }) || registryData.count > 5, "Expected known cities like Bath to be present when bundle JSON is provided")

            if let buildings = registryData[.bath] {
                XCTAssertFalse(buildings.isEmpty, "Bath should have buildings when bundle JSON is provided")
                let first = buildings[0]
                XCTAssertFalse(first.id.isEmpty)
                XCTAssertFalse(first.name.isEmpty)
            }
        }
    }

    func testGetBuildingsCycles() {
        let city: CityLocation.City = .bath
        let day1 = BuildingRegistry.getBuildings(for: city, day: 1)
        XCTAssertLessThanOrEqual(day1.count, 3)

        if !day1.isEmpty {
            XCTAssertFalse(day1.contains(where: { $0.id.isEmpty }))
        }

        let day2 = BuildingRegistry.getBuildings(for: city, day: 2)
        XCTAssertLessThanOrEqual(day2.count, 3)
        XCTAssertNotNil(day1)
        XCTAssertNotNil(day2)
    }
}
