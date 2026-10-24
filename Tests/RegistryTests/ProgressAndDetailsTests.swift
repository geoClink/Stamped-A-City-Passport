import XCTest
@testable import Stamped_

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

    // Tapping the heart once saves a landmark; tapping again removes it
    @MainActor func testWishlistToggle() {
        let saved = GlobalProgressManager.shared.wishlistIDs
        defer { GlobalProgressManager.shared.wishlistIDs = saved }

        GlobalProgressManager.shared.wishlistIDs = []
        GlobalProgressManager.shared.toggleWishlist("test-wish")
        XCTAssertTrue(GlobalProgressManager.shared.isWishlisted("test-wish"))

        GlobalProgressManager.shared.toggleWishlist("test-wish")
        XCTAssertFalse(GlobalProgressManager.shared.isWishlisted("test-wish"))
    }

    // Saving the same place twice keeps one copy; removing deletes it
    @MainActor func testCustomPlaceAddDedupeRemove() {
        let saved = GlobalProgressManager.shared.customPlaces
        defer { GlobalProgressManager.shared.customPlaces = saved }
        GlobalProgressManager.shared.customPlaces = []

        let pizza = CustomPlace(id: "p1", name: "Joe's Pizza", address: nil,
                                latitude: 40.7306, longitude: -73.9891, cityName: "New York")
        let sameSpot = CustomPlace(id: "p2", name: "Joe's Pizza", address: nil,
                                   latitude: 40.7307, longitude: -73.9890, cityName: "New York")
        GlobalProgressManager.shared.addCustomPlace(pizza)
        GlobalProgressManager.shared.addCustomPlace(sameSpot)
        XCTAssertEqual(GlobalProgressManager.shared.customPlaces(in: "New York").count, 1)
        XCTAssertTrue(GlobalProgressManager.shared.customPlaces(in: "Chicago").isEmpty)

        GlobalProgressManager.shared.removeCustomPlace("p1")
        XCTAssertTrue(GlobalProgressManager.shared.customPlaces.isEmpty)
    }

    // Saving a landmark for later must not stamp it as visited
    @MainActor func testWishlistDoesNotStamp() {
        let savedWishlist = GlobalProgressManager.shared.wishlistIDs
        let savedVisits = GlobalProgressManager.shared.visitedIDs
        defer {
            GlobalProgressManager.shared.wishlistIDs = savedWishlist
            GlobalProgressManager.shared.visitedIDs = savedVisits
        }

        GlobalProgressManager.shared.visitedIDs = []
        GlobalProgressManager.shared.toggleWishlist("test-wish")
        XCTAssertFalse(GlobalProgressManager.shared.isVisited("test-wish"))
    }

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

// MARK: - Quiz Tests

final class QuizYearTests: XCTestCase {
    // Checks the quiz never asks for the build year of a place that has none (yearBuilt 0), and never offers "0" as an answer.
    @MainActor func testNoYearQuestionsForUnknownYear() {
        let buildings = [
            makeBuilding(id: "lake", yearBuilt: 0),
            makeBuilding(id: "old", yearBuilt: 1890),
            makeBuilding(id: "mid", yearBuilt: 1950),
            makeBuilding(id: "new", yearBuilt: 2010),
        ]
        let quiz = QuizViewModel(buildings: buildings, cityName: "Test City")

        // The question type is picked at random, so ask many questions.
        for _ in 0..<200 {
            quiz.questionCount = 0 // stop the quiz from ending after 10 questions
            quiz.generateQuestion()
            if quiz.currentBuilding?.id == "lake" {
                XCTAssertNotEqual(quiz.currentQuestionType, .year)
            }
            if quiz.currentQuestionType == .year {
                XCTAssertFalse(quiz.options.contains("0"), "0 was offered as a year answer")
            }
        }
    }
}

// MARK: - Helpers

private func makeBuilding(id: String, yearBuilt: Int = 2000) -> Building {
    Building(
        id: id, name: "Test Building \(id)", assetName: "", description: "",
        architect: "Unknown", yearBuilt: yearBuilt, address: "", oldUse: "",
        newUse: "", buildingStyle: "", numberOfStories: 1, height: 10,
        foodSpots: [], currency: "USD", latitude: nil, longitude: nil
    )
}
