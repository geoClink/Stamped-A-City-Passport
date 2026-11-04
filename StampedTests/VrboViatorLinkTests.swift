//
//  VrboViatorLinkTests.swift
//  StampedTests
//
//  The Vrbo and Viator links: right site, search text, dates, and the partner tracking
//  that earns the commission.
//

import XCTest
@testable import Stamped_

final class VrboViatorLinkTests: XCTestCase {

    // MARK: - Vrbo

    // Wrapped in Vrbo's Partnerize click link, with the place in the search
    func testVrboLinkCarriesCamrefAndPlace() throws {
        let url = try XCTUnwrap(VrboLinkBuilder(camref: "ABC123").url(for: HotelSearch(destination: "Chicago, United States")))
        let text = url.absoluteString
        XCTAssertTrue(text.hasPrefix("https://prf.hn/click/camref:ABC123/destination:https%3A%2F%2Fwww.vrbo.com%2Fsearch%3F"))
        XCTAssertTrue(text.contains("destination%3DChicago%252C%2520United%2520States"))
    }

    // Trip dates go along as Vrbo's startDate and endDate
    func testVrboLinkCarriesDates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let checkIn = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 7)))
        let checkOut = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 10)))
        let builder = VrboLinkBuilder(camref: "ABC123", hotelLinks: HotelLinkBuilder(calendar: calendar))
        let text = try XCTUnwrap(builder.url(for: HotelSearch(destination: "Bath", checkIn: checkIn, checkOut: checkOut))).absoluteString
        XCTAssertTrue(text.contains("startDate%3D2026-11-07"))
        XCTAssertTrue(text.contains("endDate%3D2026-11-10"))
    }

    // No camref, no button
    func testVrboHiddenWithoutCamref() {
        XCTAssertNil(VrboLinkBuilder(camref: nil).url(for: HotelSearch(destination: "Chicago")))
        XCTAssertNil(VrboLinkBuilder(camref: "  ").url(for: HotelSearch(destination: "Chicago")))
    }

    // MARK: - Viator

    // Viator's search for "landmark, place" with the partner ID, campaign number and label
    func testViatorLinkCarriesTracking() throws {
        let url = try XCTUnwrap(ViatorLinkBuilder(partnerID: "P1", campaignNumber: "42", campaign: "app")
            .url(landmark: "Colosseum", place: "Rome, Italy"))
        XCTAssertEqual(url.absoluteString,
                       "https://www.viator.com/searchResults/all?text=Colosseum%2C%20Rome%2C%20Italy&pid=P1&mcid=42&medium=link&campaign=app")
    }

    func testViatorHiddenWithoutPartnerID() {
        XCTAssertNil(ViatorLinkBuilder(partnerID: nil).url(landmark: "Colosseum", place: "Rome"))
    }
}
