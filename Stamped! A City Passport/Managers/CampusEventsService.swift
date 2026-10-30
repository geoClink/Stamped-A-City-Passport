//
//  CampusEventsService.swift
//  Stamped! A City Passport
//
//  Upcoming events from a campus's own public calendar (lectures, concerts, exhibitions,
//  games, open days), shown on the campus page next to the Ticketmaster/SeatGeek events.
//  Which campus uses which feed is in Models/CampusEventFeeds.swift.
//
//  Two feed kinds:
//  - Localist's public read API (no key): https://<host>/api/2/events (developer.localist.com/doc/api)
//  - An iCalendar (.ics) subscription, e.g. the MSU Libraries' LibCal feed
//
//  Only factual fields are kept: title, start, venue and a short plain-text summary.
//  Photos are never used, and every event links to the school's own event page.
//

import Foundation
import Combine

// MARK: - Model

struct CampusEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let isAllDay: Bool
    /// The campus's time zone, so a Yale lecture shows Yale's local time wherever the user is.
    let timeZone: TimeZone
    /// Venue or room; empty when the feed has none.
    let venue: String
    /// At most `CampusEventsService.summaryLength` characters of plain text; may be empty.
    let summary: String
    /// The event's page on the school's own calendar.
    let url: URL

    /// e.g. "Thu, Oct 29", in the user's language.
    var dateText: String {
        var style = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day()
        style.timeZone = timeZone
        return start.formatted(style)
    }

    /// e.g. "7:30 PM", or "All day".
    var timeText: String {
        if isAllDay { return NSLocalizedString("All day", comment: "Campus events: an event with no start time") }
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return start.formatted(style)
    }
}

// MARK: - Service

@MainActor
final class CampusEventsService: ObservableObject {
    static let shared = CampusEventsService()

    /// The campus `events` belong to; the page checks it so it never shows another school's list.
    @Published private(set) var campus: CityLocation.City?
    @Published private(set) var events: [CampusEvent] = []
    @Published private(set) var isLoading = false

    /// How far ahead to look, and how many events to show at most.
    static let daysAhead = 30
    static let maxEvents = 15
    static let summaryLength = 140

    private var cache: [CityLocation.City: (events: [CampusEvent], fetched: Date)] = [:]
    private let cacheTTL: TimeInterval = 7200 // 2 hours, like TicketmasterService

    private init() {}

    func fetchEvents(for campus: CityLocation.City) async {
        self.campus = campus
        guard let feed = campus.eventFeed else {
            events = []
            isLoading = false
            return
        }
        if let cached = cache[campus], Date().timeIntervalSince(cached.fetched) < cacheTTL {
            events = cached.events
            isLoading = false
            return
        }

        events = []
        isLoading = true
        let now = Date()
        let fetched = await Self.download(feed.source, now: now)

        // The user may have opened another campus while this one was loading
        guard self.campus == campus else { return }
        if let fetched {
            let upcoming = Self.upcoming(fetched, now: now)
            events = upcoming
            cache[campus] = (upcoming, Date())
            print("[CampusEvents] Loaded \(upcoming.count) events for \(campus.name)")
        }
        isLoading = false
    }

    /// The feed's events, or nil when the request failed.
    private static func download(_ source: CampusEventSource, now: Date) async -> [CampusEvent]? {
        let url: URL
        switch source {
        case .localist(let host):
            var comps = URLComponents()
            comps.scheme = "https"
            comps.host = host
            comps.path = "/api/2/events"
            comps.queryItems = [
                // The 40 most popular events of the next 30 days, one entry per recurring event.
                // Sorting by date instead would fill the list with today's events alone.
                URLQueryItem(name: "pp", value: "40"),
                URLQueryItem(name: "days", value: String(daysAhead)),
                URLQueryItem(name: "sort", value: "ranking"),
                URLQueryItem(name: "distinct", value: "true"),
            ]
            guard let built = comps.url else { return nil }
            url = built
        case .ical(let icalURL):
            url = icalURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                print("[CampusEvents] Bad status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }
            switch source {
            case .localist:
                return try parseLocalist(data, now: now)
            case .ical:
                return parseICal(String(decoding: data, as: UTF8.self), now: now)
            }
        } catch {
            print("[CampusEvents] Error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Events still to come (all-day events count for their whole day) within `daysAhead`,
    /// soonest first, at most `maxEvents`.
    static func upcoming(_ events: [CampusEvent], now: Date) -> [CampusEvent] {
        let end = now.addingTimeInterval(TimeInterval(daysAhead) * 86_400)
        let kept = events.filter { event in
            guard event.start <= end else { return false }
            return event.isAllDay ? event.start > now.addingTimeInterval(-86_400) : event.start >= now
        }
        var seen = Set<String>()
        let unique = kept.filter { seen.insert($0.id).inserted }
        let sorted = unique.sorted { ($0.start, $0.title) < ($1.start, $1.title) }
        return Array(sorted.prefix(maxEvents))
    }
}

// MARK: - Localist

private struct LocalistResponse: Decodable {
    let events: [Item]
    struct Item: Decodable { let event: LocalistEvent }
}

/// The few Localist fields the app uses (keys are snake_case in the JSON).
private struct LocalistEvent: Decodable {
    let id: Int
    let title: String
    let localistUrl: String?
    let locationName: String?
    let location: String?
    let descriptionText: String?
    /// "inperson", "hybrid" or "virtual"
    let experience: String?
    let status: String?
    let eventInstances: [Instance]

    struct Instance: Decodable { let eventInstance: Detail }
    struct Detail: Decodable {
        let start: String
        let allDay: Bool?
    }
}

extension CampusEventsService {
    /// Turns a Localist `/api/2/events` response into events. Online-only and cancelled events
    /// are left out, since the page is for people visiting the campus.
    static func parseLocalist(_ data: Data, now: Date) throws -> [CampusEvent] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(LocalistResponse.self, from: data)

        return response.events.compactMap { item in
            let event = item.event
            guard event.experience != "virtual",
                  !["canceled", "cancelled"].contains(event.status ?? ""),
                  let link = event.localistUrl, let url = URL(string: link), url.scheme == "https"
            else { return nil }

            // A recurring event lists several instances: use the first one that hasn't passed
            let instances = event.eventInstances.compactMap { instance -> (start: Date, allDay: Bool, timeZone: TimeZone)? in
                let detail = instance.eventInstance
                guard let start = localistDate(detail.start) else { return nil }
                return (start, detail.allDay ?? false, localistTimeZone(detail.start))
            }
            let firstUpcoming = instances.first { instance in
                instance.allDay ? instance.start > now.addingTimeInterval(-86_400) : instance.start >= now
            }
            guard let next = firstUpcoming ?? instances.first else { return nil }

            let venue = [event.locationName, event.location]
                .compactMap { $0.map(cleanText) }
                .first { !$0.isEmpty } ?? ""
            // Some online events are marked in person but give "Online" as the place
            guard !["online", "virtual", "zoom"].contains(venue.lowercased()) else { return nil }

            return CampusEvent(
                id: "localist-\(event.id)",
                title: cleanText(event.title),
                start: next.start,
                isAllDay: next.allDay,
                timeZone: next.timeZone,
                venue: venue,
                summary: shortSummary(event.descriptionText ?? ""),
                url: url
            )
        }
    }

    /// "2026-10-29T19:30:00-04:00" → a Date.
    private static func localistDate(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }

    /// The time zone of the offset at the end of "2026-10-29T19:30:00-04:00" (here UTC-4),
    /// so times show as the campus's local time.
    private static func localistTimeZone(_ text: String) -> TimeZone {
        if text.hasSuffix("Z") { return TimeZone(secondsFromGMT: 0) ?? .current }
        let offset = text.suffix(6) // "-04:00"
        guard let sign = offset.first, sign == "+" || sign == "-",
              let hours = Int(offset.dropFirst().prefix(2)),
              let minutes = Int(offset.suffix(2))
        else { return .current }
        let seconds = (hours * 3600 + minutes * 60) * (sign == "-" ? -1 : 1)
        return TimeZone(secondsFromGMT: seconds) ?? .current
    }
}

// MARK: - iCalendar

extension CampusEventsService {
    /// Turns an iCalendar (.ics) feed into events. Handles the parts of RFC 5545 these feeds use:
    /// folded lines, escaped text, and UTC, TZID, floating and all-day start times.
    /// Recurrence rules aren't expanded (LibCal lists each date as its own event).
    static func parseICal(_ text: String, now: Date) -> [CampusEvent] {
        // Unfold: a line starting with a space or tab continues the line before it
        var lines: [String] = []
        for rawLine in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            if let first = rawLine.first, first == " " || first == "\t", !lines.isEmpty {
                lines[lines.count - 1] += rawLine.dropFirst()
            } else {
                lines.append(rawLine)
            }
        }

        // The calendar's own time zone, for start times written without one
        var calendarTimeZone = TimeZone.current
        var events: [CampusEvent] = []
        var properties: [String: (params: [String: String], value: String)]? = nil

        for line in lines {
            guard let property = splitICalLine(line) else { continue }
            switch (property.name, property.value) {
            case ("BEGIN", "VEVENT"):
                properties = [:]
            case ("END", "VEVENT"):
                if let found = properties, let event = makeICalEvent(found, calendarTimeZone: calendarTimeZone) {
                    events.append(event)
                }
                properties = nil
            case ("X-WR-TIMEZONE", let identifier):
                if properties == nil, let zone = TimeZone(identifier: identifier) { calendarTimeZone = zone }
            default:
                // Keep the first value of each property inside the event
                if properties != nil, properties?[property.name] == nil {
                    properties?[property.name] = (property.params, property.value)
                }
            }
        }
        return events
    }

    private static func makeICalEvent(_ properties: [String: (params: [String: String], value: String)],
                                      calendarTimeZone: TimeZone) -> CampusEvent? {
        guard let title = properties["SUMMARY"].map({ cleanText(unescapeICal($0.value)) }), !title.isEmpty,
              let start = properties["DTSTART"],
              let link = properties["URL"]?.value, let url = URL(string: link), url.scheme == "https",
              properties["STATUS"]?.value.uppercased() != "CANCELLED"
        else { return nil }

        let isAllDay = start.params["VALUE"] == "DATE" || start.value.count == 8
        let timeZone: TimeZone
        if start.value.hasSuffix("Z") {
            // A UTC time: still show it in the campus's time zone
            timeZone = calendarTimeZone
        } else {
            timeZone = start.params["TZID"].flatMap { TimeZone(identifier: $0) } ?? calendarTimeZone
        }
        guard let startDate = icalDate(start.value, isAllDay: isAllDay, timeZone: timeZone) else { return nil }

        return CampusEvent(
            id: "ical-" + (properties["UID"]?.value ?? link),
            title: title,
            start: startDate,
            isAllDay: isAllDay,
            timeZone: timeZone,
            venue: cleanText(unescapeICal(properties["LOCATION"]?.value ?? "")),
            summary: shortSummary(unescapeICal(properties["DESCRIPTION"]?.value ?? "")),
            url: url
        )
    }

    /// `NAME;PARAM=x;PARAM2="y:z":value` → name, params and value. The value starts at the first
    /// colon outside quotes, since quoted parameters (e.g. an organizer's name) can hold colons.
    private static func splitICalLine(_ line: String) -> (name: String, params: [String: String], value: String)? {
        var insideQuotes = false
        guard let colon = line.firstIndex(where: { character in
            if character == "\"" { insideQuotes.toggle() }
            return character == ":" && !insideQuotes
        }) else { return nil }

        let head = line[..<colon].split(separator: ";").map(String.init)
        guard let name = head.first?.uppercased() else { return nil }
        var params: [String: String] = [:]
        for param in head.dropFirst() {
            let pair = param.split(separator: "=", maxSplits: 1).map(String.init)
            if pair.count == 2 {
                params[pair[0].uppercased()] = pair[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        return (name, params, String(line[line.index(after: colon)...]))
    }

    /// "20261029T193000Z", "20261029T193000" or "20261029" → a Date.
    private static func icalDate(_ text: String, isAllDay: Bool, timeZone: TimeZone) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if text.hasSuffix("Z") {
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        } else {
            formatter.timeZone = timeZone
            formatter.dateFormat = isAllDay ? "yyyyMMdd" : "yyyyMMdd'T'HHmmss"
        }
        return formatter.date(from: String(text.prefix(isAllDay ? 8 : 16)))
    }

    /// iCal text escapes: \n is a line break, and \, \; \\ stand for the character itself.
    private static func unescapeICal(_ text: String) -> String {
        var result = ""
        var escaping = false
        for character in text {
            if escaping {
                result.append(character == "n" || character == "N" ? "\n" : character)
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                result.append(character)
            }
        }
        return result
    }
}

// MARK: - Text clean-up

extension CampusEventsService {
    /// Plain text: no HTML tags or entities, no invisible characters, single spaces.
    static func cleanText(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'"]
        for (entity, character) in entities {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        result = result.replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\u{200B}", with: "")
        // Line breaks and runs of spaces become one space
        return result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The clean text cut to `summaryLength` characters at a word break, with "…" when cut.
    static func shortSummary(_ text: String) -> String {
        let clean = cleanText(text)
        guard clean.count > summaryLength else { return clean }
        let cut = clean.prefix(summaryLength)
        var atWord = String(cut.lastIndex(of: " ").map { cut[..<$0] } ?? cut)
        // No dangling comma or colon before the "…"
        while let last = atWord.last, last == " " || last == "," || last == ";" || last == ":" || last == "." {
            atWord.removeLast()
        }
        return atWord + "…"
    }
}
