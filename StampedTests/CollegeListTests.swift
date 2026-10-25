//
//  CollegeListTests.swift
//  StampedTests
//
//  Tests for "My College List" (saving, toggling, reordering) and
//  "Plan a College Road Trip" (one day per campus holding exactly that
//  campus's landmarks in walking order, days in nearest-neighbour driving
//  order, and no duplicate trip on a second tap).
//  Lives in StampedTests/ (a synchronized folder) so Xcode picks it up
//  without editing the project file.
//

import XCTest
import CoreLocation
@testable import Stamped_

// MARK: - CollegeListStore

@MainActor
final class CollegeListStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: CollegeListStore!
    private let suiteName = "CollegeListStoreTests"

    override func setUp() async throws {
        // A throwaway UserDefaults suite and no iCloud, so tests never touch the real list
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = CollegeListStore(defaults: defaults, iCloud: nil)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // Checks a new list is empty
    func testStartsEmpty() {
        XCTAssertTrue(store.isEmpty)
        XCTAssertEqual(store.campuses, [])
    }

    // Checks toggling adds a campus, and toggling again removes it
    func testToggleAddsAndRemoves() {
        store.toggle(.duke)
        XCTAssertTrue(store.contains(.duke))
        XCTAssertEqual(store.campuses, [.duke])

        store.toggle(.duke)
        XCTAssertFalse(store.contains(.duke))
        XCTAssertTrue(store.isEmpty)
    }

    // Checks campuses keep the order they were added in, and aren't added twice
    func testAddKeepsOrderWithoutDuplicates() {
        store.add(.duke)
        store.add(.uGeorgia)
        store.add(.duke)
        XCTAssertEqual(store.campuses, [.duke, .uGeorgia])
    }

    // Checks a real city can't go on the college list
    func testCitiesAreIgnored() {
        XCTAssertFalse(CityLocation.City.boston.isCampus)
        store.add(.boston)
        store.toggle(.boston)
        XCTAssertTrue(store.isEmpty)
    }

    // Checks remove and the .onDelete / .onMove helpers
    func testRemoveAndMove() {
        store.add(.duke)
        store.add(.uGeorgia)
        store.add(.harvard)

        store.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        XCTAssertEqual(store.campuses, [.harvard, .duke, .uGeorgia])

        store.remove(atOffsets: IndexSet(integer: 1))
        XCTAssertEqual(store.campuses, [.harvard, .uGeorgia])

        store.remove(.harvard)
        XCTAssertEqual(store.campuses, [.uGeorgia])
    }

    // Checks the list (and its order) comes back in a new store reading the same defaults
    func testListPersistsAcrossStores() {
        store.add(.uGeorgia)
        store.add(.duke)
        store.toggle(.harvard)
        store.toggle(.uGeorgia)

        let reloaded = CollegeListStore(defaults: defaults, iCloud: nil)
        XCTAssertEqual(reloaded.campuses, [.duke, .harvard])
    }

    // Checks a saved name this app doesn't know is kept, but not shown
    func testUnknownSavedNamesAreKeptButHidden() {
        defaults.set(["Duke University", "Future University"], forKey: "GlobalCollegeListKey")
        let reloaded = CollegeListStore(defaults: defaults, iCloud: nil)

        XCTAssertEqual(reloaded.campuses, [.duke])
        reloaded.add(.uGeorgia)
        XCTAssertEqual(reloaded.campusNames, ["Duke University", "Future University", "University of Georgia"])
    }
}

// MARK: - College road trip

@MainActor
final class CollegeRoadTripTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: TripStore!
    private let suiteName = "CollegeRoadTripTests"

    override func setUp() async throws {
        // A throwaway UserDefaults suite and no iCloud, so tests never touch real trips
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = TripStore(defaults: defaults, iCloud: nil)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func distance(_ a: CityLocation.City, _ b: CityLocation.City) -> CLLocationDistance {
        CLLocation(latitude: a.coordinate.lat, longitude: a.coordinate.lon)
            .distance(from: CLLocation(latitude: b.coordinate.lat, longitude: b.coordinate.lon))
    }

    // Checks the shortcut the road trip relies on: a building id names one building in one city
    func testBuildingIDsAreUniqueAcrossCities() {
        let ids = CityLocation.City.allCases.flatMap { $0.buildings.map(\.id) }
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    // Checks there's one day per chosen campus, holding exactly that campus's landmarks
    func testOneDayPerCampusWithExactlyItsBuildings() throws {
        let campuses: [CityLocation.City] = [.duke, .uGeorgia, .harvard]
        for campus in campuses { XCTAssertTrue(campus.isCampus) }

        let trip = try XCTUnwrap(store.collegeRoadTrip(for: campuses))

        XCTAssertEqual(trip.isCollegeRoadTrip, true)
        XCTAssertTrue(trip.isRoadTrip)
        XCTAssertNil(trip.listedCity)
        XCTAssertEqual(trip.days.count, campuses.count)
        XCTAssertEqual(Set(trip.roadTripCampuses), Set(campuses))

        for (index, day) in trip.days.enumerated() {
            let campus = try XCTUnwrap(trip.city(ofDayAt: index))
            XCTAssertEqual(day.landmarkIDs.count, campus.buildings.count, "\(campus.name) day")
            XCTAssertEqual(Set(day.landmarkIDs), Set(campus.buildings.map(\.id)), "\(campus.name) day")
        }
    }

    // Checks each day is already in "Optimize route" order, like a campus visit
    func testEachDayIsInWalkingOrder() throws {
        let trip = try XCTUnwrap(store.collegeRoadTrip(for: [.duke, .uncChapelHill]))
        for (index, day) in trip.days.enumerated() {
            let campus = try XCTUnwrap(trip.city(ofDayAt: index))
            let resolved = ResolvedTripStop.resolve(day, buildings: campus.buildings, customPlaces: [])
            XCTAssertEqual(ResolvedTripStop.optimizedStopIDs(resolved), day.stops.map(\.id))
        }
    }

    // Checks the days start at the first campus and always drive to the closest one left
    func testDaysAreInNearestNeighbourOrder() throws {
        let campuses: [CityLocation.City] = [.duke, .stanford, .harvard, .uncChapelHill, .berkeley, .uGeorgia]
        let trip = try XCTUnwrap(store.collegeRoadTrip(for: campuses))
        let order = trip.roadTripCampuses

        XCTAssertEqual(order.count, campuses.count)
        XCTAssertEqual(order.first, .duke)
        var remaining = Set(campuses).subtracting([.duke])
        for (previous, next) in zip(order, order.dropFirst()) {
            let closest = remaining.min { distance(previous, $0) < distance(previous, $1) }
            XCTAssertEqual(next, closest, "after \(previous.name)")
            remaining.remove(next)
        }

        // A clear-cut case: Chapel Hill is next door to Duke, Stanford is across the country
        XCTAssertEqual(TripStore.roadTripOrder([.duke, .stanford, .uncChapelHill]), [.duke, .uncChapelHill, .stanford])
    }

    // Checks repeated taps for the same schools open the same trip instead of making another
    func testRoadTripIsNotDuplicated() throws {
        let first = try XCTUnwrap(store.collegeRoadTrip(for: [.duke, .uGeorgia]))
        let second = try XCTUnwrap(store.collegeRoadTrip(for: [.duke, .uGeorgia]))

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(store.collegeRoadTrips.count, 1)

        // Different schools make a different trip
        store.collegeRoadTrip(for: [.duke, .harvard])
        XCTAssertEqual(store.collegeRoadTrips.count, 2)
    }

    // Checks duplicate and non-campus entries are dropped, and an empty pick makes nothing
    func testInputIsCleanedUp() throws {
        XCTAssertNil(store.collegeRoadTrip(for: []))
        XCTAssertNil(store.collegeRoadTrip(for: [.boston]))
        XCTAssertTrue(store.trips.isEmpty)

        let trip = try XCTUnwrap(store.collegeRoadTrip(for: [.duke, .boston, .duke]))
        XCTAssertEqual(trip.roadTripCampuses, [.duke])
        XCTAssertEqual(trip.days.count, 1)
    }

    // Checks road trips get their own list in My Trips, apart from anywhere and city trips
    func testRoadTripsAreSeparateFromOtherTrips() throws {
        store.createTrip(name: "Kraków Trip", cityName: "Kraków",
                         area: TripArea(name: "Kraków", latitude: 50.06, longitude: 19.94))
        store.createTrip(name: "Duke Weekend", cityName: CityLocation.City.duke.name)
        let roadTrip = try XCTUnwrap(store.collegeRoadTrip(for: [.duke, .uGeorgia]))

        XCTAssertEqual(store.collegeRoadTrips.map(\.id), [roadTrip.id])
        XCTAssertEqual(store.anywhereTrips.map(\.name), ["Kraków Trip"])
        XCTAssertEqual(store.trips(in: CityLocation.City.duke.name).map(\.name), ["Duke Weekend"])
    }

    // Checks the trip's landmarks resolve to real buildings, from both campuses
    func testLandmarkBuildingsCoverEveryStop() throws {
        let trip = try XCTUnwrap(store.collegeRoadTrip(for: [.duke, .uGeorgia]))
        let expected = Set((CityLocation.City.duke.buildings + CityLocation.City.uGeorgia.buildings).map(\.id))
        XCTAssertEqual(Set(trip.landmarkBuildings.map(\.id)), expected)
    }

    // Checks a road trip re-saved by the 2.4 app (which drops the new keys) is still a road trip
    func testRoadTripSurvivesOldAppResave() throws {
        var trip = try XCTUnwrap(store.collegeRoadTrip(for: [.duke, .uGeorgia]))
        trip.isCollegeRoadTrip = nil
        trip.area = nil

        XCTAssertTrue(trip.isRoadTrip)
        XCTAssertEqual(Set(trip.roadTripCampuses), [.duke, .uGeorgia])
    }

    /// The trip as the 2.4 app decodes it.
    private struct OldTrip: Decodable {
        let id: String
        let name: String
        let cityName: String
        let startDate: Date?
        let days: [TripDay]
    }

    // Checks the 2.4 app can still read the saved trips once a road trip is among them
    func testOldAppCanReadRoadTrips() throws {
        let trip = try XCTUnwrap(store.collegeRoadTrip(for: [.duke, .uGeorgia]))
        let data = try JSONEncoder().encode(store.trips)

        let oldTrips = try JSONDecoder().decode([OldTrip].self, from: data)
        XCTAssertEqual(oldTrips.map(\.id), [trip.id])
        XCTAssertNil(CityLocation.City(rawValue: oldTrips[0].cityName), "a road trip must not look like a city trip")

        let decoded = try JSONDecoder().decode(Trip.self, from: JSONEncoder().encode(trip))
        XCTAssertEqual(decoded, trip)
    }

    // Checks road trip names: campuses listed for a short trip, a count for a long one
    func testRoadTripNames() {
        let short = TripStore.collegeRoadTripName(for: [.duke, .uGeorgia])
        XCTAssertTrue(short.contains("Duke"))
        XCTAssertTrue(short.contains("Georgia"))

        let long = TripStore.collegeRoadTripName(for: [.duke, .uGeorgia, .harvard, .stanford])
        XCTAssertTrue(long.contains("4"))
    }
}
