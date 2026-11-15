//
//  ReviewPromptTests.swift
//  StampedTests
//
//  When the app asks for an App Store rating (GlobalProgressManager.shouldAskForReview):
//  on the 3rd stamp or right after a city or campus is fully stamped, at most once per app version.
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

    // Third stamp overall, spread over cities and with this city unfinished: ask
    func testAsksOnThirdStamp() {
        let ids: Set<String> = [buildings[0].id, "elsewhere-1", "elsewhere-2"]
        XCTAssertTrue(GlobalProgressManager.shouldAskForReview(
            cityBuildings: buildings, visited: ids, lastAskedVersion: nil, currentVersion: "2.15"))
        XCTAssertFalse(GlobalProgressManager.shouldAskForReview(
            cityBuildings: buildings, visited: ids, lastAskedVersion: "2.15", currentVersion: "2.15"))
    }

    // Two stamps in an unfinished city: not yet
    func testDoesNotAskOnSecondStamp() {
        let ids: Set<String> = [buildings[0].id, "elsewhere-1"]
        XCTAssertFalse(GlobalProgressManager.shouldAskForReview(
            cityBuildings: buildings, visited: ids, lastAskedVersion: nil, currentVersion: "2.15"))
    }
}
