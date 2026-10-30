//
//  TourLinksTests.swift
//  StampedTests
//
//  GetYourGuide tour links: the partner ID, the campaign label and encoding.
//

import XCTest
@testable import Stamped_

@MainActor
final class TourLinksTests: XCTestCase {

    func testLinkSearchesLandmarkAndPlaceWithPartnerID() throws {
        let url = TourLinkBuilder(partnerID: "PBXFUP9", campaign: "app").url(landmark: "Colosseum", place: "Rome, Italy")
        XCTAssertEqual(url?.absoluteString,
                       "https://www.getyourguide.com/s/?partner_id=PBXFUP9&cmp=app&q=Colosseum%2C%20Rome%2C%20Italy")
        XCTAssertTrue(TourLinkBuilder(partnerID: "PBXFUP9").earnsCommission)
    }

    func testNoPartnerIDMeansAPlainSearch() throws {
        let builder = TourLinkBuilder(partnerID: "  ")
        XCTAssertEqual(builder.url(landmark: "Colosseum", place: "Rome, Italy")?.absoluteString,
                       "https://www.getyourguide.com/s/?q=Colosseum%2C%20Rome%2C%20Italy")
        XCTAssertFalse(builder.earnsCommission)
    }

    func testSpecialCharactersAreEncoded() throws {
        let url = try XCTUnwrap(TourLinkBuilder(partnerID: "PBXFUP9").url(landmark: "Sagrada Família & Park Güell", place: "Barcelona, Spain"))
        let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "q" }?.value
        XCTAssertEqual(q, "Sagrada Família & Park Güell, Barcelona, Spain")
    }

    func testEmptyNamesGiveNoLink() {
        XCTAssertNil(TourLinkBuilder().url(landmark: " ", place: ""))
    }
}
