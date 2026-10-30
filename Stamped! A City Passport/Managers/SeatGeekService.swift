//
//  SeatGeekService.swift
//  Stamped! A City Passport
//
//  A second source of upcoming events, from the SeatGeek Platform API, so cities
//  Ticketmaster covers thinly still get a full events list. TicketmasterService
//  merges these in; the rest of the app only sees TicketmasterEvent.
//
//  Client ID is read from Info.plist (SEATGEEK_CLIENT_ID) — never hardcoded.
//  Without it every call returns nothing and the app behaves as before.
//  Free: sign up at seatgeek.com/account/develop.
//

import Foundation
import CoreLocation

enum SeatGeekPartner {
    /// The SeatGeek partner (affiliate) ID, added to ticket links as "aid".
    /// Leave nil until SeatGeek's partner program approves the app, then paste the ID
    /// here. Double-check the parameter name against a link from the partner dashboard.
    static let affiliateID: String? = nil
}

enum SeatGeekService {
    private static var clientID: String? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "SEATGEEK_CLIENT_ID") as? String,
              !id.isEmpty else { return nil }
        return id
    }

    static var isConfigured: Bool { clientID != nil }

    /// Upcoming events within `radius` (e.g. "25mi", "1km") of a point, soonest first.
    /// `page` counts from 1. Returns nil when the request failed, and [] when there's no client ID.
    static func events(near coordinate: CLLocationCoordinate2D, radius: String, days: Int, limit: Int, page: Int = 1) async -> [TicketmasterEvent]? {
        guard let clientID else { return [] }

        let now = Date()
        let future = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        let utc = DateFormatter()
        utc.locale = Locale(identifier: "en_US_POSIX")
        utc.timeZone = TimeZone(identifier: "UTC")
        utc.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        var comps = URLComponents(string: "https://api.seatgeek.com/2/events")!
        comps.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "lat", value: "\(coordinate.latitude)"),
            URLQueryItem(name: "lon", value: "\(coordinate.longitude)"),
            URLQueryItem(name: "range", value: radius),
            URLQueryItem(name: "per_page", value: "\(limit)"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "sort", value: "datetime_utc.asc"),
            URLQueryItem(name: "datetime_utc.gte", value: utc.string(from: now)),
            URLQueryItem(name: "datetime_utc.lte", value: utc.string(from: future)),
        ]
        guard let url = comps.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                print("[SeatGeek] Bad status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }
            let decoded = try JSONDecoder().decode(SGResponse.self, from: data)
            return decoded.events.compactMap(makeEvent)
        } catch {
            print("[SeatGeek] Error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Helpers

    private static func makeEvent(_ raw: SGEvent) -> TicketmasterEvent? {
        guard let name = raw.title ?? raw.short_title else { return nil }

        // datetime_local is the venue's own clock, like Ticketmaster's localDate/localTime
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let start = raw.datetime_local.flatMap(parser.date(from:))

        var date = ""
        var time = ""
        if let start, raw.date_tbd != true {
            let dayOut = DateFormatter()
            dayOut.dateFormat = "EEE, MMM d"
            date = dayOut.string(from: start)
            if raw.time_tbd != true {
                let timeOut = DateFormatter()
                timeOut.dateFormat = "h:mm a"
                time = timeOut.string(from: start)
            }
        }

        var priceStr: String? = nil
        if let min = raw.stats?.lowest_price, let max = raw.stats?.highest_price {
            priceStr = Int(min) == Int(max) ? "$\(Int(min))" : "$\(Int(min)) – $\(Int(max))"
        } else if let min = raw.stats?.lowest_price {
            priceStr = "From $\(Int(min))"
        }

        return TicketmasterEvent(
            id: "seatgeek-\(raw.id)",
            name: name,
            date: date,
            time: time,
            venueName: raw.venue?.name ?? "",
            category: category(for: raw),
            priceRange: priceStr,
            ticketURL: raw.url.flatMap(ticketURL(from:)),
            imageURL: raw.performers?.first(where: { $0.image != nil })?.image.flatMap { URL(string: $0) },
            sellerName: "SeatGeek",
            startDate: start
        )
    }

    /// SeatGeek's types are finer than Ticketmaster's segments ("nba", "broadway_tickets_national"…),
    /// so this goes by the top-level taxonomy, falling back to the type.
    private static func category(for raw: SGEvent) -> TicketmasterEvent.EventCategory {
        let names = (raw.taxonomies ?? []).compactMap(\.name) + [raw.type ?? ""]
        if names.contains(where: { $0 == "concert" || $0 == "music_festival" }) { return .music }
        if names.contains("sports") { return .sports }
        if names.contains(where: { $0 == "theater" || $0 == "comedy" || $0.contains("broadway") || $0 == "classical" || $0 == "dance_performance_tour" }) { return .arts }
        if names.contains("family") { return .family }
        if names.contains("film") { return .film }
        return .undefined
    }

    private static func ticketURL(from string: String) -> URL? {
        guard var comps = URLComponents(string: string) else { return nil }
        if let aid = SeatGeekPartner.affiliateID, !aid.isEmpty {
            comps.queryItems = (comps.queryItems ?? []) + [URLQueryItem(name: "aid", value: aid)]
        }
        return comps.url
    }
}

// MARK: - SeatGeek API response shapes

private struct SGResponse: Decodable {
    let events: [SGEvent]
}

private struct SGEvent: Decodable {
    let id: Int
    let title: String?
    let short_title: String?
    let url: String?
    let datetime_local: String?
    let date_tbd: Bool?
    let time_tbd: Bool?
    let type: String?
    let taxonomies: [SGTaxonomy]?
    let venue: SGVenue?
    let performers: [SGPerformer]?
    let stats: SGStats?
}

private struct SGTaxonomy: Decodable {
    let name: String?
}

private struct SGVenue: Decodable {
    let name: String?
}

private struct SGPerformer: Decodable {
    let image: String?
}

private struct SGStats: Decodable {
    let lowest_price: Double?
    let highest_price: Double?
}
