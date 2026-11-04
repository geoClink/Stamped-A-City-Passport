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

    /// The Vision Pro app passes "vision" as the campaign, so its clicks show up apart from
    /// the iPhone app's ("app") in GetYourGuide's and Viator's reports.
    func testVisionCampaignLabelsTheClicks() throws {
        let getYourGuide = TourLinkBuilder(partnerID: "PBXFUP9", campaign: "vision").url(landmark: "Colosseum", place: "Rome")
        XCTAssertEqual(getYourGuide?.absoluteString,
                       "https://www.getyourguide.com/s/?partner_id=PBXFUP9&cmp=vision&q=Colosseum%2C%20Rome")

        let viator = ViatorLinkBuilder(partnerID: "P00329078", campaignNumber: "42383", campaign: "vision")
            .url(landmark: "Colosseum", place: "Rome")
        XCTAssertEqual(viator?.absoluteString,
                       "https://www.viator.com/searchResults/all?text=Colosseum%2C%20Rome&pid=P00329078&mcid=42383&medium=link&campaign=vision")
        // The iPhone app's default is still "app"
        XCTAssertEqual(TourLinkBuilder().campaign, "app")
        XCTAssertEqual(ViatorLinkBuilder().campaign, "app")
    }
}
