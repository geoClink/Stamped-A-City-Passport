//
//  TicketmasterService.swift
//  Stamped! A City Passport
//
//  Fetches upcoming events near a city using the Ticketmaster Discovery API v2,
//  merged with SeatGeek's (SeatGeekService) when a SeatGeek client ID is set.
//  API key is read from Info.plist — never hardcoded.
//  Free tier: 5,000 calls/day.
//

import Foundation
import CoreLocation
import Combine

// MARK: - Model

struct TicketmasterEvent: Identifiable {
    let id: String
    let name: String
    let date: String           // e.g. "Sat, Sep 6"
    let time: String           // e.g. "7:30 PM"
    let venueName: String
    let category: EventCategory
    let priceRange: String?    // e.g. "$25 – $120"
    let ticketURL: URL?
    let imageURL: URL?
    /// Who sells the tickets: "Ticketmaster" or "SeatGeek".
    var sellerName = "Ticketmaster"
    /// When it starts, for putting both sellers' events in one date order.
    var startDate: Date? = nil

    enum EventCategory: String {
        case music       = "Music"
        case sports      = "Sports"
        case arts        = "Arts & Theatre"
        case film        = "Film"
        case miscellaneous = "Miscellaneous"
        case family      = "Family"
        case undefined   = "Event"

        var icon: String {
            switch self {
            case .music:        return "music.note"
            case .sports:       return "sportscourt"
            case .arts:         return "theatermasks"
            case .film:         return "film"
            case .family:       return "figure.and.child.holdinghands"
            default:            return "calendar.badge.clock"
            }
        }

        static func from(_ name: String?) -> EventCategory {
            switch name {
            case "Music":          return .music
            case "Sports":         return .sports
            case "Arts & Theatre": return .arts
            case "Film":           return .film
            case "Family":         return .family
            case "Miscellaneous":  return .miscellaneous
            default:               return .undefined
            }
        }
    }
}

// MARK: - Service

@MainActor
final class TicketmasterService: ObservableObject {
    static let shared = TicketmasterService()

    @Published var events: [TicketmasterEvent] = []
    @Published var isLoading = false
    @Published var failed = false

    private var cachedCityName = ""
    private var cacheTimestamp: Date?
    private let cacheTTL: TimeInterval = 7200 // 2 hours

    private var apiKey: String? {
        Bundle.main.object(forInfoDictionaryKey: "TICKETMASTER_API_KEY") as? String
    }

    private init() {}

    func fetchEvents(cityName: String, buildings: [Building]) async {
        if cachedCityName == cityName,
           let ts = cacheTimestamp,
           Date().timeIntervalSince(ts) < cacheTTL,
           !events.isEmpty {
            return
        }

        // Compute city centroid
        let coords = buildings.compactMap { b -> CLLocationCoordinate2D? in
            guard let lat = b.latitude, let lon = b.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        guard !coords.isEmpty else { return }
        let lat = coords.map { $0.latitude }.reduce(0, +) / Double(coords.count)
        let lon = coords.map { $0.longitude }.reduce(0, +) / Double(coords.count)
        let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)

        guard let key = apiKey, !key.isEmpty else {
            print("[Ticketmaster] API key missing from Info.plist")
            // SeatGeek alone still fills the list when it's set up
            guard SeatGeekService.isConfigured else { return }
            isLoading = true
            failed = false
            let seatGeek = await SeatGeekService.events(near: center, radius: "25mi", days: 60, limit: 8)
            events = seatGeek ?? []
            failed = seatGeek == nil
            if !failed {
                cachedCityName = cityName
                cacheTimestamp = Date()
            }
            isLoading = false
            return
        }

        // Date window: today → 60 days out
        let now = Date()
        let future = Calendar.current.date(byAdding: .day, value: 60, to: now) ?? now
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let startStr = iso.string(from: now)
        let endStr = iso.string(from: future)

        var comps = URLComponents(string: "https://app.ticketmaster.com/discovery/v2/events.json")!
        comps.queryItems = [
            URLQueryItem(name: "apikey", value: key),
            URLQueryItem(name: "latlong", value: "\(lat),\(lon)"),
            URLQueryItem(name: "radius", value: "25"),
            URLQueryItem(name: "unit", value: "miles"),
            URLQueryItem(name: "size", value: "8"),
            URLQueryItem(name: "sort", value: "date,asc"),
            URLQueryItem(name: "startDateTime", value: startStr),
            URLQueryItem(name: "endDateTime", value: endStr),
        ]

        guard let url = comps.url else { return }

        isLoading = true
        failed = false

        async let seatGeekRequest = SeatGeekService.events(near: center, radius: "25mi", days: 60, limit: 8)

        var ticketmasterEvents: [TicketmasterEvent]? = nil
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if (response as? HTTPURLResponse)?.statusCode == 200 {
                let decoded = try JSONDecoder().decode(TMResponse.self, from: data)
                ticketmasterEvents = (decoded._embedded?.events ?? []).compactMap(makeEvent)
            } else {
                print("[Ticketmaster] Bad status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
        } catch {
            print("[Ticketmaster] Error: \(error.localizedDescription)")
        }
        let seatGeekEvents = await seatGeekRequest

        // Failed only when neither seller answered
        if ticketmasterEvents == nil && (seatGeekEvents == nil || !SeatGeekService.isConfigured) {
            failed = true
        } else {
            events = Self.merged(ticketmasterEvents ?? [], seatGeekEvents ?? [], limit: 12)
            cachedCityName = cityName
            cacheTimestamp = Date()
            print("[Ticketmaster] Loaded \(events.count) events for \(cityName)")
        }

        isLoading = false
    }

    /// Both sellers' events in date order. An event both sell (same name, same day)
    /// shows once, from Ticketmaster.
    static func merged(_ ticketmaster: [TicketmasterEvent], _ seatGeek: [TicketmasterEvent], limit: Int) -> [TicketmasterEvent] {
        func key(_ event: TicketmasterEvent) -> String {
            event.name.lowercased().filter { $0.isLetter || $0.isNumber } + "|" + event.date
        }
        // The sellers often title the same event differently ("Spartans vs. Hoosiers" and
        // "Hoosiers at Spartans") and name the venue differently, so an event at the same
        // venue (GameDayService's matching) on the same day and time is the same event too
        func isSameSlot(_ seatGeekEvent: TicketmasterEvent, _ ticketmasterEvent: TicketmasterEvent) -> Bool {
            seatGeekEvent.date == ticketmasterEvent.date
                && seatGeekEvent.time == ticketmasterEvent.time
                && GameDayService.isAtVenue(seatGeekEvent.venueName, venueNames: [ticketmasterEvent.venueName])
        }
        let taken = Set(ticketmaster.map(key))
        let extra = seatGeek.filter { event in
            !taken.contains(key(event)) && !ticketmaster.contains { isSameSlot(event, $0) }
        }
        guard !extra.isEmpty else { return ticketmaster }
        let all = (ticketmaster + extra).enumerated().sorted { a, b in
            switch (a.element.startDate, b.element.startDate) {
            case let (x?, y?): return x < y
            default:           return a.offset < b.offset
            }
        }
        return Array(all.map(\.element).prefix(limit))
    }

    // MARK: - Events at one place

    /// Upcoming events at (or right around) one place, for its map card.
    /// Events whose venue name matches the place come first; if none match, the
    /// closest events within about 1 km are returned and `isAtVenue` is false.
    func events(near coordinate: CLLocationCoordinate2D, placeName: String) async -> (events: [TicketmasterEvent], isAtVenue: Bool) {
        async let seatGeekRequest = SeatGeekService.events(near: coordinate, radius: "1km", days: 90, limit: 20)
        let ticketmaster = await ticketmasterEvents(near: coordinate)
        let all = Self.merged(ticketmaster, await seatGeekRequest ?? [], limit: 40)

        let place = placeName.lowercased()
        let atVenue = all.filter { event in
            let venue = event.venueName.lowercased()
            return !venue.isEmpty && (venue.contains(place) || place.contains(venue))
        }
        return atVenue.isEmpty ? (Array(all.prefix(3)), false) : (Array(atVenue.prefix(5)), true)
    }

    /// Ticketmaster's events within about 1 km over the next 90 days, soonest first.
    private func ticketmasterEvents(near coordinate: CLLocationCoordinate2D) async -> [TicketmasterEvent] {
        guard let key = apiKey, !key.isEmpty else { return [] }

        let now = Date()
        let future = Calendar.current.date(byAdding: .day, value: 90, to: now) ?? now
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        var comps = URLComponents(string: "https://app.ticketmaster.com/discovery/v2/events.json")!
        comps.queryItems = [
            URLQueryItem(name: "apikey", value: key),
            URLQueryItem(name: "latlong", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "radius", value: "1"),
            URLQueryItem(name: "unit", value: "km"),
            URLQueryItem(name: "size", value: "20"),
            URLQueryItem(name: "sort", value: "date,asc"),
            URLQueryItem(name: "startDateTime", value: iso.string(from: now)),
            URLQueryItem(name: "endDateTime", value: iso.string(from: future)),
        ]
        guard let url = comps.url,
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(TMResponse.self, from: data)
        else { return [] }

        return (decoded._embedded?.events ?? []).compactMap(makeEvent)
    }

    // MARK: - Helpers

    /// Turns one raw API event into the app's event model.
    private func makeEvent(_ raw: TMEvent) -> TicketmasterEvent? {
            guard let name = raw.name else { return nil }

            // Date formatting
            let localDate = raw.dates?.start?.localDate ?? ""
            let localTime = raw.dates?.start?.localTime ?? ""
            let formattedDate = formatDate(localDate)
            let formattedTime = formatTime(localTime)

            let venue = raw._embedded?.venues?.first?.name ?? ""
            let segment = raw.classifications?.first?.segment?.name
            let category = TicketmasterEvent.EventCategory.from(segment)

            // Price range
            var priceStr: String? = nil
            if let min = raw.priceRanges?.first?.min,
               let max = raw.priceRanges?.first?.max {
                if max == 0 {
                    priceStr = "Free"
                } else if Int(min) == Int(max) {
                    priceStr = "$\(Int(min))"
                } else {
                    priceStr = "$\(Int(min)) – $\(Int(max))"
                }
            }

            // Best image: prefer 16:9 ratio at ~640px wide
            let imageURL = raw.images?
                .filter { $0.ratio == "16_9" }
                .sorted { ($0.width ?? 0) > ($1.width ?? 0) }
                .first
                .flatMap { URL(string: $0.url ?? "") }
                ?? raw.images?.first.flatMap { URL(string: $0.url ?? "") }

            let ticketURL = raw.url.flatMap { URL(string: $0) }

            return TicketmasterEvent(
                id: raw.id ?? UUID().uuidString,
                name: name,
                date: formattedDate,
                time: formattedTime,
                venueName: venue,
                category: category,
                priceRange: priceStr,
                ticketURL: ticketURL,
                imageURL: imageURL,
                startDate: startDate(localDate, localTime)
            )
    }

    private func startDate(_ day: String, _ time: String) -> Date? {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return parser.date(from: "\(day) \(time.isEmpty ? "00:00:00" : time)")
    }

    private func formatDate(_ iso: String) -> String {
        guard !iso.isEmpty else { return "" }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: iso) else { return iso }
        let out = DateFormatter()
        out.dateFormat = "EEE, MMM d"
        return out.string(from: date)
    }

    private func formatTime(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }
        let parser = DateFormatter()
        parser.dateFormat = "HH:mm:ss"
        guard let date = parser.date(from: raw) else { return "" }
        let out = DateFormatter()
        out.dateFormat = "h:mm a"
        return out.string(from: date)
    }
}

// MARK: - Ticketmaster API response shapes

private struct TMResponse: Decodable {
    let _embedded: TMEmbedded?
}

private struct TMEmbedded: Decodable {
    let events: [TMEvent]?
}

private struct TMEvent: Decodable {
    let id: String?
    let name: String?
    let url: String?
    let dates: TMDates?
    let classifications: [TMClassification]?
    let priceRanges: [TMPriceRange]?
    let images: [TMImage]?
    let _embedded: TMEventEmbedded?
}

private struct TMDates: Decodable {
    let start: TMStart?
}

private struct TMStart: Decodable {
    let localDate: String?
    let localTime: String?
}

private struct TMClassification: Decodable {
    let segment: TMSegment?
}

private struct TMSegment: Decodable {
    let name: String?
}

private struct TMPriceRange: Decodable {
    let min: Double?
    let max: Double?
}

private struct TMImage: Decodable {
    let url: String?
    let ratio: String?
    let width: Int?
}

private struct TMEventEmbedded: Decodable {
    let venues: [TMVenue]?
}

private struct TMVenue: Decodable {
    let name: String?
}

// MARK: - Every event around a point (Game Day)

extension TicketmasterService {
    /// Both sellers' events within `radiusKm` of a point over the next `days`, soonest first,
    /// with nothing filtered out (unlike `events(near:placeName:)`), so the campus Game Day
    /// section can pick the home games itself. Sellers place a campus's venues at slightly
    /// different points, so one wider search finds them more reliably than one per venue.
    func allEvents(near coordinate: CLLocationCoordinate2D, radiusKm: Int, days: Int) async -> [TicketmasterEvent] {
        async let seatGeekRequest = SeatGeekService.events(near: coordinate, radius: "\(radiusKm)km", days: days, limit: 50)

        var ticketmaster: [TicketmasterEvent] = []
        if let key = apiKey, !key.isEmpty {
            let now = Date()
            let future = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]

            var comps = URLComponents(string: "https://app.ticketmaster.com/discovery/v2/events.json")!
            comps.queryItems = [
                URLQueryItem(name: "apikey", value: key),
                URLQueryItem(name: "latlong", value: "\(coordinate.latitude),\(coordinate.longitude)"),
                URLQueryItem(name: "radius", value: "\(radiusKm)"),
                URLQueryItem(name: "unit", value: "km"),
                URLQueryItem(name: "size", value: "50"),
                URLQueryItem(name: "sort", value: "date,asc"),
                URLQueryItem(name: "startDateTime", value: iso.string(from: now)),
                URLQueryItem(name: "endDateTime", value: iso.string(from: future)),
            ]
            if let url = comps.url,
               let (data, response) = try? await URLSession.shared.data(from: url),
               (response as? HTTPURLResponse)?.statusCode == 200,
               let decoded = try? JSONDecoder().decode(TMResponse.self, from: data) {
                ticketmaster = (decoded._embedded?.events ?? []).compactMap(makeEvent)
            }
        }

        return Self.merged(ticketmaster, await seatGeekRequest ?? [], limit: 100)
    }
}
