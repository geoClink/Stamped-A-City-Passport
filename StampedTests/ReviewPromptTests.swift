//
//  ReviewPromptTests.swift
//  StampedTests
//
//  When the app asks for an App Store rating (GlobalProgressManager.shouldAskForReview):
//  only right after a city or campus is fully stamped, and at most once per app version.
//

import XCTest
@testable import Stamped_

@MainActor
final class ReviewPromptTests: XCTestCase {

    /// Two real landmarks, so the test doesn't depend on made-up Building values
    private var buildings: [Building] { Array(CityLocation.City.chicago.buildings.prefix(2)) }

    // Every landmark stamped and this version hasn't asked: ask
    func testAsksWhenCityIsComplete() {
        let ids = Set(buildings.map(\.id))
        XCTAssertTrue(GlobalProgressManager.shouldAskForReview(
            cityBuildings: buildings, visited: ids, lastAskedVersion: nil, currentVersion: "2.8"))
    }

    // One landmark still to go: don't ask yet
    func testDoesNotAskBeforeCityIsComplete() {
        let ids = Set([buildings[0].id])
        XCTAssertFalse(GlobalProgressManager.shouldAskForReview(
            cityBuildings: buildings, visited: ids, lastAskedVersion: nil, currentVersion: "2.8"))
    }

    // Already asked in this version: don't ask again, even for another finished city
    func testAsksOncePerVersion() {
        let ids = Set(buildings.map(\.id))
        XCTAssertFalse(GlobalProgressManager.shouldAskForReview(
            cityBuildings: buildings, visited: ids, lastAskedVersion: "2.8", currentVersion: "2.8"))
        XCTAssertTrue(GlobalProgressManager.shouldAskForReview(
            cityBuildings: buildings, visited: ids, lastAskedVersion: "2.7", currentVersion: "2.8"))
    }
}
