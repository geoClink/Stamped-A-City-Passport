//
//  Trip.swift
//  Stamped! A City Passport
//
//  A trip the user plans themselves: a city, an optional start date,
//  and a list of days, each with an ordered list of stops.
//

import Foundation

struct Trip: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    /// The Stamped city this trip is in (e.g. "New York"), matching `CityLocation.City.name`.
    let cityName: String
    var startDate: Date? = nil
    var days: [TripDay] = [TripDay()]

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
