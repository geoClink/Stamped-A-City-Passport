//
//  TripPlannerTests.swift
//  StampedTests
//
//  Tests for the trip planner's store and walking-order helper.
//  Lives in StampedTests/ (a synchronized folder) so Xcode picks it up
//  without editing the project file.
//

import XCTest
import CoreLocation
@testable import Stamped_

// MARK: - TripStore

@MainActor
final class TripStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: TripStore!
    private let suiteName = "TripStoreTests"

    override func setUp() async throws {
        // A throwaway UserDefaults suite and no iCloud, so tests never touch real trips
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = TripStore(defaults: defaults, iCloud: nil)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    /// Makes a trip with one day holding stops named "a", "b", "c" (as landmark ids).
    private func makeTripWithStops(_ buildingIDs: [String] = ["a", "b", "c"]) -> (tripID: String, dayID: String) {
        let trip = store.createTrip(name: "Test", cityName: "Boston")
        let dayID = trip.days[0].id
        for buildingID in buildingIDs {
            store.addStop(.landmark(buildingID: buildingID), toDay: dayID, in: trip.id)
        }
        return (trip.id, dayID)
    }

    private func buildingIDs(inDay dayIndex: Int, of tripID: String) -> [String] {
        store.trip(withID: tripID)!.days[dayIndex].stops.map { stop in
            if case .landmark(let buildingID) = stop.kind { return buildingID }
            return "?"
        }
    }

    // Checks a new trip starts with one empty day and shows up for its city only
    func testCreateTripStartsWithOneDay() {
        let trip = store.createTrip(name: "Weekend", cityName: "Boston")
        XCTAssertEqual(trip.days.count, 1)
        XCTAssertEqual(store.trips(in: "Boston").map(\.id), [trip.id])
        XCTAssertTrue(store.trips(in: "Paris").isEmpty)
    }

    // Checks stops are added to the end of the day in the order they were added
    func testAddStopsKeepsOrder() {
        let (tripID, _) = makeTripWithStops()
        XCTAssertEqual(buildingIDs(inDay: 0, of: tripID), ["a", "b", "c"])
    }

    // Checks .onMove-style offsets reorder stops within a day
    func testMoveStopsWithinDay() {
        let (tripID, dayID) = makeTripWithStops()
        // Move "a" (index 0) to the end, like dragging it below "c"
        store.moveStops(inDay: dayID, in: tripID, fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(buildingIDs(inDay: 0, of: tripID), ["b", "c", "a"])
    }

    // Checks a stop can move to another day and lands at the requested spot
    func testMoveStopBetweenDays() {
        let (tripID, _) = makeTripWithStops()
        let day2ID = store.addDay(to: tripID)!
        store.addStop(.landmark(buildingID: "x"), toDay: day2ID, in: tripID)
        let stopB = store.trip(withID: tripID)!.days[0].stops[1].id

        store.moveStop(stopB, toDay: day2ID, at: 0, in: tripID)

        XCTAssertEqual(buildingIDs(inDay: 0, of: tripID), ["a", "c"])
        XCTAssertEqual(buildingIDs(inDay: 1, of: tripID), ["b", "x"])
    }

    // Checks removing a stop takes out only that stop
    func testRemoveStop() {
        let (tripID, dayID) = makeTripWithStops()
        let stopB = store.trip(withID: tripID)!.days[0].stops[1].id
        store.removeStop(stopB, fromDay: dayID, in: tripID)
        XCTAssertEqual(buildingIDs(inDay: 0, of: tripID), ["a", "c"])
    }

    // Checks a day can be removed, but the last day of a trip can't
    func testRemoveDayKeepsAtLeastOne() {
        let (tripID, firstDayID) = makeTripWithStops()
        let secondDayID = store.addDay(to: tripID)!
        store.removeDay(secondDayID, from: tripID)
        XCTAssertEqual(store.trip(withID: tripID)!.days.count, 1)

        store.removeDay(firstDayID, from: tripID)
        XCTAssertEqual(store.trip(withID: tripID)!.days.count, 1, "A trip should always keep one day")
    }

    // Checks reorderStops ignores a list that would drop stops
    func testReorderStopsRejectsMissingStops() {
        let (tripID, dayID) = makeTripWithStops()
        let stops = store.trip(withID: tripID)!.days[0].stops
        store.reorderStops([stops[2].id, stops[0].id], inDay: dayID, in: tripID)
        XCTAssertEqual(buildingIDs(inDay: 0, of: tripID), ["a", "b", "c"])

        store.reorderStops([stops[2].id, stops[0].id, stops[1].id], inDay: dayID, in: tripID)
        XCTAssertEqual(buildingIDs(inDay: 0, of: tripID), ["c", "a", "b"])
    }

    // Checks rename trims whitespace and delete removes the trip
    func testRenameAndDeleteTrip() {
        let trip = store.createTrip(name: "Old", cityName: "Boston")
        store.renameTrip(trip.id, to: "  New Name  ")
        XCTAssertEqual(store.trip(withID: trip.id)?.name, "New Name")

        store.deleteTrip(trip.id)
        XCTAssertNil(store.trip(withID: trip.id))
    }

    // Checks trips are saved and come back in a new store using the same storage
    func testTripsPersistAcrossStores() {
        let (tripID, _) = makeTripWithStops()
        let reloaded = TripStore(defaults: defaults, iCloud: nil)
        XCTAssertEqual(reloaded.trip(withID: tripID), store.trip(withID: tripID))
    }
}

// MARK: - Walking order

final class WalkingRouteTests: XCTestCase {
    // Points along one street, about 111 m apart per 0.001° of latitude
    private let start = RoutePoint(id: "start", latitude: 42.000, longitude: -71.0)
    private let near = RoutePoint(id: "near", latitude: 42.001, longitude: -71.0)
    private let middle = RoutePoint(id: "middle", latitude: 42.003, longitude: -71.0)
    private let far = RoutePoint(id: "far", latitude: 42.010, longitude: -71.0)

    // Checks the route starts at the first stop and always goes to the closest next one
    func testNearestNeighbourOrder() {
        let ordered = WalkingRoute.nearestNeighbourOrder([start, far, middle, near])
        XCTAssertEqual(ordered.map(\.id), ["start", "near", "middle", "far"])
    }

    // Checks empty and single-stop days come back unchanged
    func testNearestNeighbourEdgeCases() {
        XCTAssertTrue(WalkingRoute.nearestNeighbourOrder([]).isEmpty)
        XCTAssertEqual(WalkingRoute.nearestNeighbourOrder([far]).map(\.id), ["far"])
    }

    // Checks there's one leg per pair of stops, with ~80 m/min walking times
    func testLegsWalkingTimes() {
        let legs = WalkingRoute.legs(for: [start, near, far])
        XCTAssertEqual(legs.count, 2)
        XCTAssertEqual(legs[0].fromID, "start")
        XCTAssertEqual(legs[0].toID, "near")
        // ~111 m at 80 m/min ≈ 1.4 min, rounded up to 2
        XCTAssertEqual(legs[0].meters, 111, accuracy: 2)
        XCTAssertEqual(legs[0].minutes, 2)
        // near → far is ~1,000 m ≈ 12.5 min, rounded up to 13
        XCTAssertEqual(legs[1].minutes, 13)
    }

    // Checks minute rounding: a short hop is at least 1 minute, exact multiples aren't bumped up
    func testMinutesRounding() {
        XCTAssertEqual(WalkingRoute.minutes(forMeters: 10), 1)
        XCTAssertEqual(WalkingRoute.minutes(forMeters: 160), 2)
        XCTAssertEqual(WalkingRoute.minutes(forMeters: 0), 0)
    }

    // Checks optimizing a day keeps stops with no location, at the end in their old order
    @MainActor
    func testOptimizedStopIDsKeepsUnlocatedStopsAtEnd() {
        let places = [
            CustomPlace(id: "p-far", name: "Far", address: nil, latitude: 42.010, longitude: -71.0, cityName: "Boston"),
            CustomPlace(id: "p-start", name: "Start", address: nil, latitude: 42.000, longitude: -71.0, cityName: "Boston"),
            CustomPlace(id: "p-near", name: "Near", address: nil, latitude: 42.001, longitude: -71.0, cityName: "Boston"),
        ]
        let day = TripDay(stops: [
            TripStop(id: "s-start", kind: .place(placeID: "p-start")),
            TripStop(id: "s-missing", kind: .place(placeID: "deleted")),
            TripStop(id: "s-far", kind: .place(placeID: "p-far")),
            TripStop(id: "s-near", kind: .place(placeID: "p-near")),
        ])
        let resolved = ResolvedTripStop.resolve(day, buildings: [], customPlaces: places)

        XCTAssertEqual(ResolvedTripStop.optimizedStopIDs(resolved), ["s-start", "s-near", "s-far", "s-missing"])
    }
}

// MARK: - Trip tour

@MainActor
final class TripTourTests: XCTestCase {
    /// A landmark with only the fields the tour cares about filled in.
    private func building(_ id: String, latitude: Double? = 42.36, longitude: Double? = -71.06) -> Building {
        Building(
            id: id, name: id, assetName: "", description: "", architect: "", yearBuilt: 1900,
            address: "", oldUse: "", newUse: "", buildingStyle: "", numberOfStories: 1, height: 10,
            foodSpots: [], currency: "USD", latitude: latitude, longitude: longitude
        )
    }

    private let cafe = CustomPlace(id: "cafe", name: "Cafe", address: nil, latitude: 42.35, longitude: -71.05, cityName: "Boston")

    // Checks the tour goes through Day 1's stops in order, then Day 2's, numbering stops within each day
    func testStepsFollowDaysInOrder() {
        let trip = Trip(name: "Test", cityName: "Boston", days: [
            TripDay(stops: [TripStop(kind: .landmark(buildingID: "a")), TripStop(kind: .place(placeID: "cafe"))]),
            TripDay(stops: [TripStop(kind: .landmark(buildingID: "b"))]),
        ])
        let steps = TripTour.steps(for: trip, buildings: [building("a"), building("b")], customPlaces: [cafe])

        XCTAssertEqual(steps.map(\.name), ["a", "Cafe", "b"])
        XCTAssertEqual(steps.map(\.dayNumber), [1, 1, 2])
        XCTAssertEqual(steps.map(\.stopNumber), [1, 2, 1])
        XCTAssertEqual(steps.map(\.stopsInDay), [2, 2, 1])
    }

    // Checks stops with nowhere to fly (no coordinates, deleted place) are skipped and the numbering closes the gap
    func testStepsSkipStopsWithoutALocation() {
        let trip = Trip(name: "Test", cityName: "Boston", days: [
            TripDay(stops: [
                TripStop(kind: .landmark(buildingID: "noCoords")),
                TripStop(kind: .place(placeID: "deleted")),
                TripStop(kind: .landmark(buildingID: "a")),
            ]),
        ])
        let buildings = [building("noCoords", latitude: nil, longitude: nil), building("a")]
        let steps = TripTour.steps(for: trip, buildings: buildings, customPlaces: [])

        XCTAssertEqual(steps.map(\.name), ["a"])
        XCTAssertEqual(steps.first?.stopNumber, 1)
        XCTAssertEqual(steps.first?.stopsInDay, 1)
    }

    // Checks an empty day is skipped without throwing off the next day's number
    func testEmptyDayKeepsLaterDayNumbers() {
        let trip = Trip(name: "Test", cityName: "Boston", days: [
            TripDay(stops: []),
            TripDay(stops: [TripStop(kind: .landmark(buildingID: "a"))]),
        ])
        let steps = TripTour.steps(for: trip, buildings: [building("a")], customPlaces: [])

        XCTAssertEqual(steps.map(\.dayNumber), [2])
    }
}

// MARK: - Trips anywhere (2.5)

@MainActor
final class TripAnywhereTests: XCTestCase {
    /// A trip exactly as the 2.4 app saves it: no "area" key. Dates are seconds
    /// since 2001 and enum cases are keyed by name, which is Codable's default.
    private let oldTripJSON = """
    [{"id":"t1","name":"Boston Weekend","cityName":"Boston","startDate":782870400,
      "days":[{"id":"d1","stops":[
        {"id":"s1","kind":{"landmark":{"buildingID":"boston-1"}}},
        {"id":"s2","kind":{"place":{"placeID":"p1"}}}
      ]}]}]
    """

    /// The 2.4 Trip struct, so we can check the old app can still read new data.
    private struct OldTrip: Decodable {
        let id: String
        let name: String
        let cityName: String
        let startDate: Date?
        let days: [TripDay]
    }

    // Checks a trip saved by 2.4 (no "area") still decodes, as a Boston trip with its stops
    func testDecodesOldFormatTrip() throws {
        let trips = try JSONDecoder().decode([Trip].self, from: Data(oldTripJSON.utf8))

        XCTAssertEqual(trips.count, 1)
        XCTAssertNil(trips[0].area)
        XCTAssertEqual(trips[0].listedCity, .boston)
        XCTAssertEqual(trips[0].days[0].stops.map(\.kind), [
            .landmark(buildingID: "boston-1"),
            .place(placeID: "p1"),
        ])
    }

    // Checks an old trip comes back in a store that loads it from UserDefaults
    func testStoreLoadsOldFormatTrip() {
        let suiteName = "TripAnywhereTests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data(oldTripJSON.utf8), forKey: "GlobalTripsKey")

        let store = TripStore(defaults: defaults, iCloud: nil)

        XCTAssertEqual(store.trips(in: "Boston").map(\.name), ["Boston Weekend"])
        XCTAssertTrue(store.anywhereTrips.isEmpty)
    }

    // Checks a place saved by 2.4 (with its extra Apple Maps details) still decodes
    func testDecodesOldFormatCustomPlace() throws {
        let json = """
        [{"id":"p1","name":"Joe's Pizza","address":"7 Carmine St","latitude":40.73,"longitude":-74.0,
          "cityName":"New York","websiteURL":"https://joespizzanyc.com","category":"MKPOICategoryRestaurant"}]
        """
        let places = try JSONDecoder().decode([CustomPlace].self, from: Data(json.utf8))

        XCTAssertEqual(places.first?.cityName, "New York")
        XCTAssertNil(places.first?.phoneNumber)
    }

    // Checks the 2.4 app can still read trips saved by 2.5, including anywhere trips
    func testOldAppCanReadNewTrips() throws {
        let krakow = Trip(name: "Kraków Trip", cityName: "Kraków",
                          area: TripArea(name: "Kraków", latitude: 50.06, longitude: 19.94))
        let data = try JSONEncoder().encode([krakow, Trip(name: "Boston Trip", cityName: "Boston")])

        let oldTrips = try JSONDecoder().decode([OldTrip].self, from: data)

        XCTAssertEqual(oldTrips.map(\.cityName), ["Kraków", "Boston"])
    }

    // Checks an anywhere trip keeps its area through saving and loading
    func testAnywhereTripRoundTrip() throws {
        let trip = Trip(name: "Kraków Trip", cityName: "Kraków",
                        area: TripArea(name: "Kraków", latitude: 50.06, longitude: 19.94))
        let decoded = try JSONDecoder().decode(Trip.self, from: JSONEncoder().encode(trip))

        XCTAssertEqual(decoded, trip)
        XCTAssertEqual(decoded.area?.name, "Kraków")
    }

    // Checks anywhere trips stay out of a Stamped city's planner and show in anywhereTrips
    func testAnywhereTripsAreSeparateFromCityTrips() {
        let suiteName = "TripAnywhereStoreTests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = TripStore(defaults: defaults, iCloud: nil)
        store.createTrip(name: "Boston Trip", cityName: "Boston")
        store.createTrip(name: "Kraków Trip", cityName: "Kraków",
                         area: TripArea(name: "Kraków", latitude: 50.06, longitude: 19.94))

        XCTAssertEqual(store.trips(in: "Boston").map(\.name), ["Boston Trip"])
        XCTAssertEqual(store.anywhereTrips.map(\.name), ["Kraków Trip"])
    }

    // Checks listedCity finds Stamped cities by name and is nil for anywhere else
    func testListedCity() {
        XCTAssertEqual(Trip(name: "A", cityName: "Boston").listedCity, .boston)
        XCTAssertNil(Trip(name: "B", cityName: "Kraków").listedCity)
    }

    // Checks an area named like a Stamped city (Paris, Texas) gets a different cityName
    func testAnywhereCityNameAvoidsListedNames() {
        XCTAssertEqual(Trip.anywhereCityName(for: "Kraków", context: "Kraków, Poland"), "Kraków")
        XCTAssertEqual(Trip.anywhereCityName(for: "Paris", context: "Paris, TX"), "Paris, TX")
        XCTAssertEqual(Trip.anywhereCityName(for: "Paris", context: nil), "Paris (Anywhere)")
        XCTAssertEqual(Trip.anywhereCityName(for: "Paris", context: "Paris"), "Paris (Anywhere)")
    }

    // Checks a search result near a Stamped city is spotted (the city, not a nearby campus like UCL), and one far away isn't
    func testListedCityNearCoordinate() {
        // About 2 km from central London
        XCTAssertEqual(CityLocation.City.listed(near: CLLocationCoordinate2D(latitude: 51.52, longitude: -0.10)), .london)
        // Kraków: hundreds of km from any Stamped city
        XCTAssertNil(CityLocation.City.listed(near: CLLocationCoordinate2D(latitude: 50.06, longitude: 19.94)))
    }
}
