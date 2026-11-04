//
//  OpenTableLinkTests.swift
//  StampedTests
//
//  The OpenTable link: OpenTable's search near the building, wrapped in the Partnerize
//  click link that earns the commission, and hidden without a camref.
//

import XCTest
@testable import Stamped_

final class OpenTableLinkTests: XCTestCase {

    // Wrapped in Partnerize, with the building's point in OpenTable's search
    func testLinkCarriesCamrefAndLocation() throws {
        let url = try XCTUnwrap(OpenTableLinkBuilder(camref: "ABC123").url(latitude: 41.8789, longitude: -87.6359))
        XCTAssertEqual(url.absoluteString,
                       "https://prf.hn/click/camref:ABC123/destination:https%3A%2F%2Fwww.opentable.com%2Fs%3Flatitude%3D41.87890%26longitude%3D-87.63590")
    }

    // The Vision Pro label goes in as Partnerize's pubref
    func testClickLabelBecomesPubref() throws {
        let url = try XCTUnwrap(OpenTableLinkBuilder(camref: "ABC123", clickLabel: "vision").url(latitude: 1, longitude: 2))
        XCTAssertTrue(url.absoluteString.hasPrefix("https://prf.hn/click/camref:ABC123/pubref:vision/destination:"))
    }

    // No camref, no button
    func testHiddenWithoutCamref() {
        XCTAssertNil(OpenTableLinkBuilder(camref: nil).url(latitude: 1, longitude: 2))
        XCTAssertNil(OpenTableLinkBuilder(camref: "  ").url(latitude: 1, longitude: 2))
    }
}
