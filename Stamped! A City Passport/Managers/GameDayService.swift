//
//  GameDayService.swift
//  Stamped! A City Passport
//
//  Upcoming home games for a campus's Game Day section. Nothing comes from a new source:
//  it asks the existing Ticketmaster + SeatGeek search (TicketmasterService) for events
//  around the campus's stadiums and arenas, then keeps the sports events at those venues
//  that name the school. Ticket links are the sellers' own links, as in Upcoming Events.
//

import Foundation
import CoreLocation

@MainActor
final class GameDayService {
    static let shared = GameDayService()

    /// Campus name → when it was loaded and its home games; kept for 2 hours like the events list
    private var cache: [String: (loaded: Date, games: [TicketmasterEvent])] = [:]
    private let cacheTTL: TimeInterval = 7200

    private init() {}

    /// The next home games at the campus's venues, soonest first. Empty when there are
    /// none, no venues are known, or no ticket seller is set up.
    func homeGames(for campus: CityLocation.City) async -> [TicketmasterEvent] {
        if let cached = cache[campus.rawValue], Date().timeIntervalSince(cached.loaded) < cacheTTL {
            return cached.games
        }
        let venues = campus.gameDayVenues
        guard !venues.isEmpty else { return [] }

        // One search around the middle of the venues, wide enough to reach all of them.
        // (Sellers don't always put a venue where the map does: Ticketmaster finds nothing
        // within 1 km of the Breslin Center, but its games show up from Spartan Stadium.)
        let (center, radiusKm) = Self.searchArea(for: venues.map(\.coordinate))
        let events = await TicketmasterService.shared.allEvents(near: center, radiusKm: radiusKm, days: 90)

        let games = Self.homeGames(from: events, venueNames: venues.map(\.name), teamNames: campus.gameDayTeamNames)
        cache[campus.rawValue] = (Date(), games)
        return games
    }

    /// The middle of the venues, and a radius (whole km, 2 to 5) that reaches every one with room to spare.
    static func searchArea(for coordinates: [CLLocationCoordinate2D]) -> (center: CLLocationCoordinate2D, radiusKm: Int) {
        let count = Double(max(coordinates.count, 1))
        let center = CLLocationCoordinate2D(
            latitude: coordinates.map(\.latitude).reduce(0, +) / count,
            longitude: coordinates.map(\.longitude).reduce(0, +) / count
        )
        let middle = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let farthest = coordinates
            .map { CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: middle) }
            .max() ?? 0
        let radius = Int((farthest / 1000).rounded(.up)) + 1
        return (center, min(max(radius, 2), 5))
    }

    // MARK: - Filtering

    /// Words many venue names share, so they can't tell two venues apart
    private static let genericVenueWords: Set<String> = [
        "the", "at", "of", "and", "stadium", "arena", "center", "centre", "field", "fieldhouse",
        "house", "ice", "student", "events", "event", "coliseum", "pavilion", "hall", "gym",
        "gymnasium", "park", "memorial",
    ]

    /// The home games among `events`: sports events at one of the campus's venues whose
    /// title names the school, without duplicates. Each venue gets its next `perVenue` games
    /// first, so a week of volleyball can't push the next football game off the list.
    static func homeGames(from events: [TicketmasterEvent], venueNames: [String], teamNames: [String],
                          perVenue: Int = 2, limit: Int = 6) -> [TicketmasterEvent] {
        var seen = Set<String>()
        var gamesByVenue: [Int: [TicketmasterEvent]] = [:]
        for event in soonestFirst(events) {
            guard event.category == .sports,
                  let venue = venueIndex(event.venueName, venueNames: venueNames),
                  mentionsTeam(event.name, teamNames: teamNames)
            else { continue }
            // The same game can come from both sellers, often titled differently
            // ("Spartans vs. Hoosiers" and "Hoosiers at Spartans"), so a game at the same
            // venue, day and time counts as already seen too. Before kickoff is set, both
            // sellers leave the time blank, and a venue holds one untimed game a day.
            let titleKey = words(event.name).joined() + "|" + event.date
            let slotKey = "\(venue)|\(event.date)|\(event.time)"
            guard !seen.contains(titleKey), !seen.contains(slotKey) else { continue }
            seen.insert(titleKey)
            seen.insert(slotKey)
            gamesByVenue[venue, default: []].append(event)
        }
        let picked = gamesByVenue.values.flatMap { $0.prefix(perVenue) }
        return Array(soonestFirst(picked).prefix(limit))
    }

    /// Events by start time; ones without a time keep their order at the end.
    private static func soonestFirst(_ events: [TicketmasterEvent]) -> [TicketmasterEvent] {
        events.enumerated().sorted { a, b in
            switch (a.element.startDate, b.element.startDate) {
            case let (x?, y?): return x == y ? a.offset < b.offset : x < y
            case (_?, nil):    return true
            case (nil, _?):    return false
            default:           return a.offset < b.offset
            }
        }
        .map(\.element)
    }

    /// True when a seller's venue name is one of ours.
    static func isAtVenue(_ eventVenue: String, venueNames: [String]) -> Bool {
        venueIndex(eventVenue, venueNames: venueNames) != nil
    }

    /// Which of our venues a seller's venue name is. Sellers use other names ("Jack Breslin
    /// Arena" for "Breslin Student Events Center"), so sharing a distinctive word is enough.
    static func venueIndex(_ eventVenue: String, venueNames: [String]) -> Int? {
        let eventWords = words(eventVenue)
        guard !eventWords.isEmpty else { return nil }
        return venueNames.firstIndex { venue in
            let distinctive = Set(words(venue)).subtracting(genericVenueWords)
            // "Memorial Stadium" is all generic words: then the whole name must match
            if distinctive.isEmpty {
                return eventWords.joined(separator: " ").contains(words(venue).joined(separator: " "))
            }
            return !distinctive.isDisjoint(with: eventWords)
        }
    }

    /// True when the event's title names the school as a whole word or phrase,
    /// so "MSU" matches "MSU Spartans vs Iowa" but not "MSUM".
    static func mentionsTeam(_ title: String, teamNames: [String]) -> Bool {
        let titleWords = " " + words(title).joined(separator: " ") + " "
        return teamNames.contains { name in
            let nameWords = words(name).joined(separator: " ")
            return !nameWords.isEmpty && titleWords.contains(" \(nameWords) ")
        }
    }

    /// Lowercased words, punctuation dropped: "Spartan Stadium-MI" → ["spartan", "stadium", "mi"]
    private static func words(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}
