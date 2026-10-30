//
//  StaysAndFoodToursTests.swift
//  StampedTests
//
//  The building page's Food Tours link (GetYourGuide) and the distance text on the
//  Stays Near Here hotel cards.
//

import XCTest
@testable import Stamped_

@MainActor
final class StaysAndFoodToursTests: XCTestCase {

    // MARK: - Food tours link

    /// The link credits Stamped (partner_id + cmp) and searches food tours in the place.
    func testFoodToursLinkHasPartnerIDCampaignAndPlace() throws {
        let url = try XCTUnwrap(TourLinkBuilder(partnerID: "PBXFUP9", campaign: "app").foodToursURL(place: "Rome, Italy"))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(url.host, "www.getyourguide.com")
        XCTAssertEqual(items.first { $0.name == "partner_id" }?.value, "PBXFUP9")
        XCTAssertEqual(items.first { $0.name == "cmp" }?.value, "app")
        XCTAssertEqual(items.first { $0.name == "q" }?.value, "food tour, Rome, Italy")
    }

    /// No place means no button, rather than a search for just "food tour".
    func testFoodToursLinkNeedsAPlace() {
        XCTAssertNil(TourLinkBuilder().foodToursURL(place: "  "))
    }

    // MARK: - Distance text

    private let english = Locale(identifier: "en_US")

    /// Up to a 20-minute walk shows minutes, rounded up (400 m at 80 m/min = 5 min).
    func testShortDistanceIsWalkingMinutes() {
        XCTAssertEqual(NearbyDistance.text(meters: 400, useMetric: true, locale: english), "5 min walk")
        // Right next door is still "1 min", never "0 min"
        XCTAssertEqual(NearbyDistance.text(meters: 10, useMetric: false, locale: english), "1 min walk")
        // 1,600 m is exactly 20 minutes, the last walking one
        XCTAssertEqual(NearbyDistance.text(meters: 1600, useMetric: true, locale: english), "20 min walk")
    }

    /// Past 20 minutes it switches to km or miles, following the Metric Units setting.
    func testLongDistanceFollowsUnitSetting() {
        XCTAssertEqual(NearbyDistance.text(meters: 2500, useMetric: true, locale: english), "2.5 km")
        // 2,500 m is 1.55 miles, shown to one decimal
        XCTAssertEqual(NearbyDistance.text(meters: 2500, useMetric: false, locale: english), "1.6 mi")
    }
}
