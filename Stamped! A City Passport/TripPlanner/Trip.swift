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
