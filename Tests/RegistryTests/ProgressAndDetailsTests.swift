import XCTest
@testable import GlobalDiscoveryApp

// MARK: - CityDetails Tests

final class CityDetailsTests: XCTestCase {

    // Verifies Boston loads from CityDetails.json with the correct currency
    func testBostonDetailsLoadCorrectly() {
        guard Bundle.main.url(forResource: "CityDetails", withExtension: "json") != nil else {
            // Add CityDetails.json to the test target in Xcode to enable this test
            return
        }
        let details = CityLocation.City.boston.details
        XCTAssertEqual(details.currencyCode, "USD", "Boston should use USD")
        XCTAssertFalse(details.airportCode.isEmpty, "Boston should have an airport code")
        XCTAssertFalse(details.nickname.isEmpty, "Boston should have a nickname")
    }

    // Verifies every city returns real data (not the placeholder fallback)
    // The placeholder uses "---" as the airport code, so any city returning "---" means
    // its key is missing or misspelled in CityDetails.json
    func testAllCitiesHaveNonPlaceholderDetails() {
        guard Bundle.main.url(forResource: "CityDetails", withExtension: "json") != nil else { return }
        for city in CityLocation.City.allCases {
            let details = city.details
            XCTAssertNotEqual(
                details.airportCode, "---",
                "\(city.rawValue) returned a placeholder — check its key in CityDetails.json"
            )
        }
    }

    // Spot-checks a few known currency codes to catch JSON parse regressions
    func testKnownCurrencyCodes() {
        guard Bundle.main.url(forResource: "CityDetails", withExtension: "json") != nil else { return }
        let cases: [(CityLocation.City, String)] = [
            (.tokyo, "JPY"),
            (.paris, "EUR"),
            (.london, "GBP"),
        ]
        for (city, expected) in cases {
            XCTAssertEqual(city.details.currencyCode, expected, "\(city.rawValue) should use \(expected)")
        }
    }
}

// MARK: - GlobalProgressManager Tests

final class GlobalProgressManagerTests: XCTestCase {

    // Mastery for zero buildings should always be Tourist at 0% progress
    @MainActor func testEmptyBuildingsMastery() {
        let result = GlobalProgressManager.shared.getMastery(for: [])
        XCTAssertEqual(result.tier, "Tourist")
        XCTAssertEqual(result.progress, 0.0, accuracy: 0.001)
        XCTAssertEqual(result.count, 0)
    }

    // Visiting 2 of 3 buildings should give 66.7% progress
    @MainActor func testPartialProgressCalculation() {
        let buildings = [
            makeBuilding(id: "test-a"),
            makeBuilding(id: "test-b"),
            makeBuilding(id: "test-c"),
        ]
        let saved = GlobalProgressManager.shared.visitedIDs
        defer { GlobalProgressManager.shared.visitedIDs = saved }

        GlobalProgressManager.shared.visitedIDs = ["test-a", "test-b"]
        let result = GlobalProgressManager.shared.getMastery(for: buildings)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.progress, 2.0 / 3.0, accuracy: 0.001)
    }

    // Visiting all buildings should return progress of 1.0
    @MainActor func testFullProgressCalculation() {
        let buildings = [makeBuilding(id: "full-1"), makeBuilding(id: "full-2")]
        let saved = GlobalProgressManager.shared.visitedIDs
        defer { GlobalProgressManager.shared.visitedIDs = saved }

        GlobalProgressManager.shared.visitedIDs = ["full-1", "full-2"]
        let result = GlobalProgressManager.shared.getMastery(for: buildings)

        XCTAssertEqual(result.progress, 1.0, accuracy: 0.001)
    }
}

// MARK: - Helpers

private func makeBuilding(id: String) -> Building {
    Building(
        id: id, name: "Test Building", assetName: "", description: "",
        architect: "Unknown", yearBuilt: 2000, address: "", oldUse: "",
        newUse: "", buildingStyle: "", numberOfStories: 1, height: 10,
        foodSpots: [], currency: "USD", latitude: nil, longitude: nil
    )
}
