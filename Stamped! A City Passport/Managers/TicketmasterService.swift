//
//  TicketmasterService.swift
//  Stamped! A City Passport
//
//  Fetches upcoming events near a city using the Ticketmaster Discovery API v2.
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

        guard let key = apiKey, !key.isEmpty else {
            print("[Ticketmaster] API key missing from Info.plist")
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

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                print("[Ticketmaster] Bad status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                failed = true
                isLoading = false
                return
            }

            let decoded = try JSONDecoder().decode(TMResponse.self, from: data)
            let rawEvents = decoded._embedded?.events ?? []

            events = rawEvents.compactMap { raw in
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
                    imageURL: imageURL
                )
            }

            cachedCityName = cityName
            cacheTimestamp = Date()
            print("[Ticketmaster] Loaded \(events.count) events for \(cityName)")
        } catch {
            failed = true
            print("[Ticketmaster] Error: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Helpers

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
