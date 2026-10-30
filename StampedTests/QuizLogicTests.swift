//
//  QuizLogicTests.swift
//  StampedTests
//
//  The quiz's wrong-answer picking, which questions a building gets, and
//  voice matching. The picks are random, so most tests check many rounds.
//

import XCTest
@testable import Stamped_

@MainActor
final class QuizLogicTests: XCTestCase {

    private var generator = SystemRandomNumberGenerator()

    /// A landmark with only the fields the quiz cares about filled in.
    private func building(
        _ id: String, year: Int = 1900, style: String = "Art Deco",
        architect: String = "Unknown", floors: Int = 0
    ) -> Building {
        Building(
            id: id, name: id, assetName: "", description: "", architect: architect, yearBuilt: year,
            address: "", oldUse: "", newUse: "", buildingStyle: style, numberOfStories: floors, height: 10,
            foodSpots: [], currency: "USD", latitude: nil, longitude: nil
        )
    }

    // MARK: - Year distractors

    // Checks the wrong years are always 3 different years, none the answer, all 5–40 years
    // from it, at least 3 years apart from each other, and never in the future.
    func testYearDistractorsAreDistinctNearbyAndNotTheAnswer() {
        for answer in [1066, 1829, 1890, 1931, 1975, 2004] {
            for _ in 0..<200 {
                let years = QuizLogic.yearDistractors(for: answer, currentYear: 2026, using: &generator)

                XCTAssertEqual(years.count, 3, "should always give 3 wrong years")
                XCTAssertEqual(Set(years).count, years.count, "a year was repeated")
                XCTAssertFalse(years.contains(answer), "the answer was offered as a wrong year")
                for year in years {
                    XCTAssertTrue(QuizLogic.yearOffsets.contains(abs(year - answer)), "\(year) is too near or too far from \(answer)")
                    XCTAssertLessThanOrEqual(year, 2026, "\(year) is in the future")
                }
                for (index, year) in years.enumerated() {
                    for other in years[(index + 1)...] {
                        XCTAssertGreaterThanOrEqual(abs(year - other), QuizLogic.minimumYearGap)
                    }
                }
            }
        }
    }

    // Checks a very recent building still gets 3 wrong years, all from the past
    func testYearDistractorsForARecentBuildingStayInThePast() {
        for _ in 0..<200 {
            let years = QuizLogic.yearDistractors(for: 2024, currentYear: 2026, using: &generator)
            XCTAssertEqual(years.count, 3)
            XCTAssertTrue(years.allSatisfy { $0 <= 2026 && $0 != 2024 })
        }
    }

    // MARK: - Floors

    // Checks "how many floors?" is never asked when floors are unknown (0) or just 1,
    // and is asked (less often than the others) for 2 or more
    func testFloorsQuestionOnlyForTwoOrMoreFloors() {
        func asksFloors(_ floors: Int) -> Bool {
            QuizLogic.choices(for: building("b", floors: floors), hasPhoto: false).contains { $0.type == .stories }
        }
        XCTAssertFalse(asksFloors(0), "0 means the floor count is unknown")
        XCTAssertFalse(asksFloors(1), "a 1-floor building is too easy")
        XCTAssertTrue(asksFloors(2))
        XCTAssertTrue(asksFloors(40))

        let floorsChoice = QuizLogic.choices(for: building("b", floors: 10), hasPhoto: false).first { $0.type == .stories }
        XCTAssertLessThan(floorsChoice?.weight ?? 1, 1, "floors should come up less often than other questions")
    }

    // Checks the wrong floor counts are distinct, never the answer and never below 1
    func testFloorDistractorsAreDistinctAndNotTheAnswer() {
        for answer in [2, 3, 12, 102] {
            for _ in 0..<100 {
                let floors = QuizLogic.floorDistractors(for: answer, using: &generator)
                XCTAssertEqual(floors.count, 3)
                XCTAssertEqual(Set(floors).count, 3)
                XCTAssertFalse(floors.contains(answer))
                XCTAssertTrue(floors.allSatisfy { $0 >= 1 })
            }
        }
    }

    // MARK: - Photo and other question choices

    // Checks photo questions only come up for buildings known to have a photo,
    // and that a lake with no year/style/architect still gets a name question
    func testPhotoQuestionOnlyWithAPhoto() {
        let church = building("church", architect: "James O'Donnell", floors: 3)
        XCTAssertFalse(QuizLogic.choices(for: church, hasPhoto: false).contains { $0.showsPhoto })
        XCTAssertTrue(QuizLogic.choices(for: church, hasPhoto: true).contains { $0.showsPhoto })

        let lake = building("lake", year: 0, style: "Unknown")
        XCTAssertEqual(QuizLogic.choices(for: lake, hasPhoto: false).map(\.type), [.name])
    }

    // MARK: - Style and name distractors

    // Checks style options prefer styles from a similar era, never repeat and
    // never include the answer, even when a style is listed twice
    func testStyleDistractorsPreferSameEra() {
        let pool: [(style: String, year: Int?)] = [
            ("Gothic Revival", 1850), ("Italianate", 1860), ("Second Empire", 1870),
            ("Second Empire", 1875), ("Brutalist", 1968), ("Postmodern", 1985),
            ("Beaux-Arts", 1900)
        ]
        for _ in 0..<100 {
            let styles = QuizLogic.styleDistractors(for: "Gothic Revival", answerYear: 1850, pool: pool, using: &generator)
            XCTAssertEqual(styles.count, 3)
            XCTAssertEqual(Set(styles).count, 3)
            XCTAssertFalse(styles.contains("Gothic Revival"))
            // Italianate, Second Empire and Beaux-Arts are all within 75 years of 1850
            XCTAssertEqual(Set(styles), ["Italianate", "Second Empire", "Beaux-Arts"])
        }
    }

    // Checks a city with only one style still gets 3 wrong styles from the fallback list
    func testStyleDistractorsFallBackForSmallCities() {
        let styles = QuizLogic.styleDistractors(for: "Art Deco", answerYear: 1930, pool: [("Art Deco", 1930)], using: &generator)
        XCTAssertEqual(styles.count, 3)
        XCTAssertFalse(styles.contains { QuizLogic.sameText($0, "Art Deco") })
    }

    // Checks wrong names skip blanks, repeats (ignoring case and accents) and the answer
    func testUniqueDistractorsDropRepeats() {
        let names = ["Café Royal", "cafe royal", "", "Union Station", "Union Station", "City Hall"]
        let picked = QuizLogic.uniqueDistractors(for: "City Hall", from: names, using: &generator)
        XCTAssertEqual(picked.count, 2)
        XCTAssertFalse(picked.contains("City Hall"))
        XCTAssertTrue(picked.contains("Union Station"))
    }

    // MARK: - Fact line and voice

    // Checks the after-answer line lists only the facts that are known
    func testFactLine() {
        let basilica = building("Notre-Dame Basilica", year: 1829, style: "Gothic Revival", architect: "James O'Donnell")
        XCTAssertEqual(QuizLogic.factLine(for: basilica), "Notre-Dame Basilica · Gothic Revival · 1829 · James O'Donnell")

        let lake = building("Lake", year: 0, style: "Unknown")
        XCTAssertEqual(QuizLogic.factLine(for: lake), "Lake")
    }

    // Checks spoken names match despite punctuation and accents, and numbers must match exactly
    func testVoiceMatch() {
        let names = ["Notre-Dame Basilica", "St. Paul's Cathedral", "Union Station", "Union Station Tower"]
        XCTAssertEqual(QuizLogic.voiceMatch(spoken: "notre dame basilica", options: names), "Notre-Dame Basilica")
        XCTAssertEqual(QuizLogic.voiceMatch(spoken: "Saint Paul's Cathedral", options: names), "St. Paul's Cathedral")
        XCTAssertEqual(QuizLogic.voiceMatch(spoken: "union station", options: names), "Union Station")
        XCTAssertEqual(QuizLogic.voiceMatch(spoken: "union station tower", options: names), "Union Station Tower")
        XCTAssertNil(QuizLogic.voiceMatch(spoken: "basilica", options: names), "one word of a short name is not enough")

        let floors = ["2 floors", "12 floors", "20 floors"]
        XCTAssertEqual(QuizLogic.voiceMatch(spoken: "12", options: floors, isNumeric: true), "12 floors")
        XCTAssertEqual(QuizLogic.voiceMatch(spoken: "twenty", options: floors, isNumeric: true), "20 floors")
    }
}
