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

    /// The short row on the city page, picked from `loadedEvents` by `highlights`
    @Published var events: [TicketmasterEvent] = []
    /// Every event loaded so far from both sellers, soonest first, for See all
    @Published var loadedEvents: [TicketmasterEvent] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var canLoadMore = false
    @Published var failed = false

    /// Events per request from each seller. One request costs the same at 8 or 50.
    static let pageSize = 50
    /// How far ahead the city list looks; shows often go on sale months ahead
    static let daysAhead = 180
    /// Cards in the short row, and the most any one kind of event may take
    static let rowLimit = 12
    static let perCategoryLimit = 4

    private var searchCenter: CLLocationCoordinate2D?
    private var ticketmasterLoaded: [TicketmasterEvent] = []
    private var seatGeekLoaded: [TicketmasterEvent] = []
    private var nextPage = 0

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

        let hasTicketmasterKey = !(apiKey ?? "").isEmpty
        if !hasTicketmasterKey {
            print("[Ticketmaster] API key missing from Info.plist")
            // SeatGeek alone still fills the list when it's set up
            guard SeatGeekService.isConfigured else { return }
        }

        isLoading = true
        failed = false
        searchCenter = center
        ticketmasterLoaded = []
        seatGeekLoaded = []
        nextPage = 0
        loadedEvents = []
        events = []
        canLoadMore = false

        if await loadNextPage() {
            cachedCityName = cityName
            cacheTimestamp = Date()
            print("[Ticketmaster] Loaded \(loadedEvents.count) events for \(cityName)")
        } else {
            failed = true
        }

        isLoading = false
    }

    /// The next page from both sellers, for See all. Does nothing while a load is running
    /// or when both sellers have run out.
    func loadMore() async {
        guard canLoadMore, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true
        _ = await loadNextPage()
        isLoadingMore = false
    }

    /// Fetches page `nextPage` from both sellers and merges it into `loadedEvents`, then
    /// picks the short row (`events`) again. False when neither seller answered.
    private func loadNextPage() async -> Bool {
        guard let center = searchCenter else { return false }
        let page = nextPage

        // SeatGeek counts pages from 1, Ticketmaster from 0
        async let seatGeekRequest = SeatGeekService.events(near: center, radius: "25mi", days: Self.daysAhead,
                                                           limit: Self.pageSize, page: page + 1)
        let ticketmaster = await ticketmasterCityPage(near: center, page: page)
        let seatGeek = await seatGeekRequest

        // Failed only when neither seller answered
        guard ticketmaster != nil || (seatGeek != nil && SeatGeekService.isConfigured) else { return false }

        ticketmasterLoaded += (ticketmaster?.events ?? []).filter { Self.isUpcoming($0) }
        seatGeekLoaded += (seatGeek ?? []).filter { Self.isUpcoming($0) }
        nextPage += 1
        loadedEvents = Self.merged(ticketmasterLoaded, seatGeekLoaded, limit: .max)
        events = Self.highlights(from: loadedEvents, limit: Self.rowLimit, perCategory: Self.perCategoryLimit)

        // A full page means that seller may have more. Ticketmaster only pages through its
        // first 1,000 results, so it stops there.
        let ticketmasterHasMore = (ticketmaster?.rawCount ?? 0) == Self.pageSize
            && (nextPage + 1) * Self.pageSize <= 1000
        let seatGeekHasMore = (seatGeek?.count ?? 0) == Self.pageSize
        canLoadMore = ticketmasterHasMore || seatGeekHasMore
        return true
    }

    /// One page of Ticketmaster's events within 25 miles over the next `daysAhead` days,
    /// soonest first. `rawCount` is how many the page held before any were dropped, so a
    /// full page is still known to be full. Nil without a key or when the request failed.
    private func ticketmasterCityPage(near center: CLLocationCoordinate2D, page: Int) async -> (events: [TicketmasterEvent], rawCount: Int)? {
        guard let key = apiKey, !key.isEmpty else { return nil }

        let now = Date()
        let future = Calendar.current.date(byAdding: .day, value: Self.daysAhead, to: now) ?? now
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        var comps = URLComponents(string: "https://app.ticketmaster.com/discovery/v2/events.json")!
        comps.queryItems = [
            URLQueryItem(name: "apikey", value: key),
            URLQueryItem(name: "latlong", value: "\(center.latitude),\(center.longitude)"),
            URLQueryItem(name: "radius", value: "25"),
            URLQueryItem(name: "unit", value: "miles"),
            URLQueryItem(name: "size", value: "\(Self.pageSize)"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "sort", value: "date,asc"),
            URLQueryItem(name: "startDateTime", value: iso.string(from: now)),
            URLQueryItem(name: "endDateTime", value: iso.string(from: future)),
        ]
        guard let url = comps.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                print("[Ticketmaster] Bad status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }
            let raw = try JSONDecoder().decode(TMResponse.self, from: data)._embedded?.events ?? []
            return (raw.compactMap(makeEvent), raw.count)
        } catch {
            print("[Ticketmaster] Error: \(error.localizedDescription)")
            return nil
        }
    }

    /// False for an event whose date has passed. Long-running exhibits come back dated the
    /// day they opened ("Sat, Sep 12"), and a past date on the card reads as a mistake.
    /// Events without a date are kept.
    static func isUpcoming(_ event: TicketmasterEvent, now: Date = Date()) -> Bool {
        guard let start = event.startDate else { return true }
        return start >= Calendar.current.startOfDay(for: now)
    }

    /// The short row on the city page: the soonest events, but no more than `perCategory`
    /// of any one kind, so a week of games can't push every show and concert out.
    /// When there aren't enough other kinds to fill it, the soonest skipped events fill the rest.
    static func highlights(from events: [TicketmasterEvent], limit: Int, perCategory: Int) -> [TicketmasterEvent] {
        var countByCategory: [TicketmasterEvent.EventCategory: Int] = [:]
        var pickedIndices: [Int] = []
        var skippedIndices: [Int] = []
        for (index, event) in events.enumerated() {
            guard pickedIndices.count < limit else { break }
            if countByCategory[event.category, default: 0] < perCategory {
                countByCategory[event.category, default: 0] += 1
                pickedIndices.append(index)
            } else {
                skippedIndices.append(index)
            }
        }
        let fill = skippedIndices.prefix(max(0, limit - pickedIndices.count))
        // Back into date order
        return (pickedIndices + fill).sorted().map { events[$0] }
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
        guard !extra.isEmpty else { return Array(ticketmaster.prefix(limit)) }
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
