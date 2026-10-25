//
//  Trip.swift
//  Stamped! A City Passport
//
//  A trip the user plans themselves: a city, an optional start date,
//  and a list of days, each with an ordered list of stops.
//
//  Two kinds of trip share this struct:
//  - A listed-city trip: `cityName` is a Stamped city ("New York"), `area` is nil.
//  - An anywhere trip (2.5): `cityName` is just a label ("Kraków") and `area`
//    says where the map centres. Its stops are Apple Maps places only.
//  - A college road trip (2.5): an anywhere trip whose days are each one campus's
//    landmarks. `cityName` is a label ("College Road Trip"), `area` is the first
//    campus, and `isCollegeRoadTrip` is true. Building ids are unique across every
//    city, so its landmark stops are looked up in all cities (`LandmarkIndex`),
//    and a road trip is still recognised by its landmark stops if an older app
//    re-saved it without the flag.
//
//  `cityName` stays a required String on purpose: the 2.4 app reads the same
//  saved JSON, and a missing or null `cityName` would make its decode fail.
//

import Foundation
import CoreLocation

struct Trip: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    /// The Stamped city this trip is in (e.g. "New York"), matching `CityLocation.City.name`.
    /// For an anywhere trip it's the searched area's name instead (e.g. "Kraków").
    let cityName: String
    var startDate: Date? = nil
    var days: [TripDay] = [TripDay()]
    /// Where an anywhere trip's map centres. nil for listed-city trips.
    /// Optional, so trips saved before 2.5 (with no "area" key) still decode.
    var area: TripArea? = nil
    /// True for a campus's ready-made "Campus Visit" trip, so tapping
    /// "Plan a Campus Visit" again opens it instead of making another.
    /// Optional, so trips saved without it (and the 2.4 app's JSON) still decode.
    var isCampusVisit: Bool? = nil
    /// True for a trip made by "Plan a College Road Trip" (one campus per day).
    /// Optional, so trips saved without it (and the 2.4 app's JSON) still decode.
    var isCollegeRoadTrip: Bool? = nil

    /// The Stamped city this trip belongs to, or nil for an anywhere trip.
    var listedCity: CityLocation.City? {
        CityLocation.City(rawValue: cityName)
    }

    /// The `cityName` to use for an anywhere trip. If the searched name is
    /// also a Stamped city's name (Paris, Texas vs Paris), use the longer
    /// address ("Paris, TX") so the trip isn't mistaken for the listed city.
    static func anywhereCityName(for name: String, context: String?) -> String {
        guard CityLocation.City(rawValue: name) != nil else { return name }
        let longer = context?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !longer.isEmpty, CityLocation.City(rawValue: longer) == nil {
            return longer
        }
        return "\(name) (Anywhere)"
    }

    /// The calendar date of a day, when the trip has a start date.
    func date(ofDayAt index: Int) -> Date? {
        guard let startDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: index, to: startDate)
    }

    /// Total number of stops across every day.
    var stopCount: Int {
        days.reduce(0) { $0 + $1.stops.count }
    }

    // MARK: College road trips

    /// True for a college road trip. Besides the flag, a trip outside the Stamped
    /// cities that holds built-in landmarks can only be a road trip (anywhere trips
    /// add Apple Maps places only), which covers a trip the 2.4 app re-saved
    /// without `isCollegeRoadTrip`.
    var isRoadTrip: Bool {
        guard listedCity == nil else { return false }
        return isCollegeRoadTrip == true || days.contains { $0.landmarkIDs.first != nil }
    }

    /// The Stamped city or campus a day is at: the city of the day's first
    /// built-in landmark, or nil for a day with no landmarks.
    func city(ofDayAt index: Int) -> CityLocation.City? {
        guard days.indices.contains(index) else { return nil }
        return days[index].landmarkIDs.lazy.compactMap { LandmarkIndex.city(ofBuilding: $0) }.first
    }

    /// The campuses a road trip visits, in day order, each listed once.
    var roadTripCampuses: [CityLocation.City] {
        var seen: Set<CityLocation.City> = []
        return days.indices.compactMap { city(ofDayAt: $0) }.filter { $0.isCampus && seen.insert($0).inserted }
    }

    /// Every built-in landmark on the trip, from whichever city it's in.
    /// Lets a trip outside one city (a road trip) show its landmark stops.
    var landmarkBuildings: [Building] {
        var seen: Set<String> = []
        return days.flatMap(\.landmarkIDs).compactMap { id in
            seen.insert(id).inserted ? LandmarkIndex.building(withID: id) : nil
        }
    }
}

extension TripDay {
    /// The building ids of the day's landmark stops, in order.
    var landmarkIDs: [String] {
        stops.compactMap { stop in
            if case .landmark(let buildingID) = stop.kind { return buildingID }
            return nil
        }
    }
}

/// Every built-in landmark by id, across all cities and campuses.
/// Building ids are unique app-wide, so one id names one building in one city.
enum LandmarkIndex {
    private static let entries: [String: (building: Building, city: CityLocation.City)] = {
        var result: [String: (building: Building, city: CityLocation.City)] = [:]
        for city in CityLocation.City.allCases {
            for building in city.buildings where result[building.id] == nil {
                result[building.id] = (building, city)
            }
        }
        return result
    }()

    static func building(withID id: String) -> Building? { entries[id]?.building }
    static func city(ofBuilding id: String) -> CityLocation.City? { entries[id]?.city }
}

/// The place an anywhere trip is planned around, picked from an Apple Maps search.
struct TripArea: Codable, Hashable {
    var name: String
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct TripDay: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var stops: [TripStop] = []
}

/// One stop on a day. It has its own `id` so the same landmark can appear
/// on two different days and still be told apart in lists.
struct TripStop: Identifiable, Codable, Hashable {
    /// What the stop points at.
    enum Kind: Codable, Hashable {
        /// A built-in landmark, by `Building.id`.
        case landmark(buildingID: String)
        /// A place saved from Apple Maps, by `CustomPlace.id`.
        case place(placeID: String)
    }

    var id: String = UUID().uuidString
    let kind: Kind
}

extension CityLocation.City {
    /// The closest Stamped city to a point, if one is within `maxMeters`.
    /// Used to suggest planning in a listed city (with stamps) instead of anywhere.
    /// Campuses are skipped: searching "London" should suggest London, not UCL.
    static func listed(near coordinate: CLLocationCoordinate2D, maxMeters: Double = 20_000) -> CityLocation.City? {
        let point = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let withDistances = cityCases.map { city in
            (city, point.distance(from: CLLocation(latitude: city.coordinate.lat, longitude: city.coordinate.lon)))
        }
        guard let closest = withDistances.min(by: { $0.1 < $1.1 }), closest.1 <= maxMeters else { return nil }
        return closest.0
    }
}

extension CityLocation.City {
    /// A shorter campus name for trip names: "Duke University" → "Duke",
    /// "University of Georgia" → "Georgia". Names without those words stay as they are.
    var campusVisitShortName: String {
        var shortName = name
        for prefix in ["The ", "University of "] where shortName.hasPrefix(prefix) {
            shortName.removeFirst(prefix.count)
        }
        if shortName.hasSuffix(" University") {
            shortName.removeLast(" University".count)
        }
        return shortName
    }
}
