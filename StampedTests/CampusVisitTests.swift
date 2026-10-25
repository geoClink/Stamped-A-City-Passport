//
//  CampusVisitTests.swift
//  StampedTests
//
//  Tests for "Plan a Campus Visit": the ready-made trip holds exactly the
//  campus's landmarks on one day, in walking order, and isn't made twice.
//  Lives in StampedTests/ (a synchronized folder) so Xcode picks it up
//  without editing the project file.
//

import XCTest
@testable import Stamped_

@MainActor
final class CampusVisitTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: TripStore!
    private let suiteName = "CampusVisitTests"
    private let campus = CityLocation.City.duke

    override func setUp() async throws {
        // A throwaway UserDefaults suite and no iCloud, so tests never touch real trips
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = TripStore(defaults: defaults, iCloud: nil)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func buildingIDs(in day: TripDay) -> [String] {
        day.stops.map { stop in
            if case .landmark(let buildingID) = stop.kind { return buildingID }
            return "?"
        }
    }

    // Checks the visit is one day holding every landmark of the campus, and nothing else
    func testVisitHasEveryCampusBuildingOnOneDay() {
        XCTAssertTrue(campus.isCampus)
        let trip = store.campusVisitTrip(for: campus)

        XCTAssertEqual(trip.cityName, campus.name)
        XCTAssertEqual(trip.isCampusVisit, true)
        XCTAssertEqual(trip.days.count, 1)

        let ids = buildingIDs(in: trip.days[0])
        XCTAssertEqual(ids.count, campus.buildings.count)
        XCTAssertEqual(Set(ids), Set(campus.buildings.map(\.id)))
    }

    // Checks the stops are already in "Optimize route" order, so optimizing again changes nothing
    func testVisitIsInWalkingOrder() {
        let trip = store.campusVisitTrip(for: campus)
        let resolved = ResolvedTripStop.resolve(trip.days[0], buildings: campus.buildings, customPlaces: [])
        XCTAssertEqual(ResolvedTripStop.optimizedStopIDs(resolved), trip.days[0].stops.map(\.id))
    }

    // Checks a second tap opens the same trip instead of making another
    func testVisitIsNotDuplicated() {
        let first = store.campusVisitTrip(for: campus)
        let second = store.campusVisitTrip(for: campus)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(store.trips(in: campus.name).count, 1)
    }

    // Checks a renamed visit trip is still found, by its isCampusVisit flag
    func testRenamedVisitIsStillFound() {
        let first = store.campusVisitTrip(for: campus)
        store.renameTrip(first.id, to: "Saturday at Duke")

        XCTAssertEqual(store.campusVisitTrip(for: campus).id, first.id)
        XCTAssertEqual(store.trips(in: campus.name).count, 1)
    }

    // Checks another trip in the same campus isn't mistaken for the visit
    func testOtherTripsAreNotTheVisit() {
        store.createTrip(name: "Weekend", cityName: campus.name)
        XCTAssertNil(store.existingCampusVisit(for: campus))

        store.campusVisitTrip(for: campus)
        XCTAssertEqual(store.trips(in: campus.name).count, 2)
    }

    // Checks the short names used in trip names ("Duke Campus Visit")
    func testCampusVisitShortName() {
        XCTAssertEqual(CityLocation.City.duke.campusVisitShortName, "Duke")
        XCTAssertEqual(CityLocation.City.uGeorgia.campusVisitShortName, "Georgia")
        XCTAssertEqual(CityLocation.City.bostonCollege.campusVisitShortName, "Boston College")
    }
}
