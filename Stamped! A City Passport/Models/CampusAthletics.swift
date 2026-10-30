//
//  CampusAthletics.swift
//  Stamped! A City Passport
//
//  Game Day data for a campus: the official athletics website, the stadiums and arenas
//  home games are played in (with a Commons photo and its credit), and NCAA team titles.
//  It comes from Resources/CampusAthletics.json, which says where each part was checked.
//  No team logos, mascots or wordmarks anywhere: those are trademarks.
//

import Foundation
import CoreLocation

/// One campus's entry in CampusAthletics.json. Every part is optional.
nonisolated struct CampusAthletics: Decodable {
    let athleticsURL: URL?
    let venues: [Venue]?
    let championships: Championships?

    struct Venue: Decodable {
        /// The campus landmark this venue is, for its coordinates
        let buildingID: String
        let name: String
        let photo: VenuePhoto?
    }

    /// A free-licence photo on Wikimedia Commons, credited as its licence asks
    struct VenuePhoto: Decodable, Hashable {
        let imageURL: URL
        let filePageURL: URL
        let author: String
        /// e.g. "CC BY-SA 4.0" or "Public domain"
        let license: String
        let licenseURL: URL?
    }

    struct Championships: Decodable {
        /// Where the list comes from, in English, e.g. "Wikipedia, “Michigan State Spartans”, citing the NCAA…"
        let source: String
        let sourceURL: URL
        let titles: [Title]
    }

    struct Title: Decodable, Hashable {
        /// English sport name; also the Localizable.strings key ("Men's basketball")
        let sport: String
        let years: [Int]
        /// Years the title was shared with another school
        var sharedYears: [Int]? = nil
    }
}

/// A place home games are played, with the coordinates the event search uses.
struct GameDayVenue: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let coordinate: CLLocationCoordinate2D
    var photo: CampusAthletics.VenuePhoto? = nil

    static func == (lhs: GameDayVenue, rhs: GameDayVenue) -> Bool { lhs.name == rhs.name }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }
}

/// Loads CampusAthletics.json once. It's English-only data, so there's one copy.
enum CampusAthleticsStore {
    nonisolated private struct File: Decodable {
        let campuses: [String: CampusAthletics]
    }

    /// Campus name ("Michigan State University", the raw value, as in CampusTraditions.json) → its data
    private static let byCampus: [String: CampusAthletics] = {
        guard let url = Bundle.main.url(forResource: "CampusAthletics", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return [:] }
        return decode(data)
    }()

    /// Separate from the bundle lookup so the tests can check the real file's format
    nonisolated static func decode(_ data: Data) -> [String: CampusAthletics] {
        (try? JSONDecoder().decode(File.self, from: data))?.campuses ?? [:]
    }

    static func athletics(for campus: CityLocation.City) -> CampusAthletics? {
        byCampus[campus.rawValue]
    }
}

extension CityLocation.City {
    /// The campus's Game Day data, or nil for cities and campuses without any.
    var athletics: CampusAthletics? {
        guard isCampus else { return nil }
        return CampusAthleticsStore.athletics(for: self)
    }

    /// Where to look for home games: the venues in CampusAthletics.json, or else the campus
    /// landmarks named like a stadium or arena ("Neyland Stadium", "Cassell Coliseum").
    var gameDayVenues: [GameDayVenue] {
        guard isCampus else { return [] }
        let byID = Dictionary(buildings.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        if let venues = athletics?.venues, !venues.isEmpty {
            return venues.compactMap { venue in
                guard let building = byID[venue.buildingID], let lat = building.latitude, let lon = building.longitude else { return nil }
                return GameDayVenue(name: venue.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), photo: venue.photo)
            }
        }

        let sportsWords = ["Stadium", "Arena", "Coliseum", "Fieldhouse", "Field House", "Pavilion"]
        let venues = buildings.compactMap { building -> GameDayVenue? in
            guard sportsWords.contains(where: { building.name.contains($0) }),
                  let lat = building.latitude, let lon = building.longitude else { return nil }
            return GameDayVenue(name: building.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        // Each venue costs an event search, so keep it to a few
        return Array(venues.prefix(3))
    }

    /// Names a home game's title would use for this school: its search aliases
    /// ("MSU", "Michigan State", "Spartans") and its name without "University of".
    var gameDayTeamNames: [String] {
        var names = searchAliases
        var short = name
        for prefix in ["The ", "University of "] where short.hasPrefix(prefix) {
            short.removeFirst(prefix.count)
        }
        // "Michigan State University" → "Michigan State"; "Texas at Austin" → "Texas"
        for marker in [" University", " College", " at ", ",", "–"] {
            if let range = short.range(of: marker) { short = String(short[..<range.lowerBound]) }
        }
        short = short.trimmingCharacters(in: .whitespaces)
        if !short.isEmpty, !names.contains(short) { names.append(short) }
        return names
    }
}
