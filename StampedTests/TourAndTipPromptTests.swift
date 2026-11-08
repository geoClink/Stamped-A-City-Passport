import XCTest
@testable import Stamped_

final class TourAndTipPromptTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let name = "TourAndTipPromptTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testTourOfferIsOncePerCity() {
        let defaults = makeDefaults()
        XCTAssertTrue(TourOffer.claim(city: "Rome", defaults: defaults))
        XCTAssertFalse(TourOffer.claim(city: "Rome", defaults: defaults))
        XCTAssertTrue(TourOffer.claim(city: "Paris", defaults: defaults))
    }

    func testEveryCampusHasAnOfficialVisitPage() {
        XCTAssertEqual(CityLocation.City.campusCases.count, 122)
        for campus in CityLocation.City.campusCases {
            XCTAssertEqual(campus.officialVisitURL?.scheme, "https", campus.rawValue)
        }
    }

    func testCitiesHaveNoOfficialVisitPage() {
        XCTAssertNil(CityLocation.City.cityCases.first?.officialVisitURL)
    }

    func testTopProgramsAreTheLargestThreeOverFivePercent() {
        let json = #"""
        {"results":[{"id":1,"latest.academics.program_percentage.history":0.04,
        "latest.academics.program_percentage.engineering":0.3,
        "latest.academics.program_percentage.business_marketing":0.2,
        "latest.academics.program_percentage.biological":0.1,
        "latest.academics.program_percentage.psychology":0.06}]}
        """#
        let programs = CollegeScorecardService.topPrograms(in: Data(json.utf8), unitID: 1)
        XCTAssertEqual(programs.map(\.key), ["engineering", "business_marketing", "biological"])
    }

    func testTipWaitsForTenStamps() {
        XCTAssertFalse(GlobalProgressManager.shouldAskForTip(stampCount: 9, finishedCity: false, alreadyAsked: false))
        XCTAssertTrue(GlobalProgressManager.shouldAskForTip(stampCount: 10, finishedCity: false, alreadyAsked: false))
    }

    func testTipIsNeverOnACityCelebrationOrRepeated() {
        XCTAssertFalse(GlobalProgressManager.shouldAskForTip(stampCount: 12, finishedCity: true, alreadyAsked: false))
        XCTAssertFalse(GlobalProgressManager.shouldAskForTip(stampCount: 12, finishedCity: false, alreadyAsked: true))
    }
}
