//
//  OnThisDay.swift
//  Stamped! A City Passport
//
//  "On this day": events from Wikipedia's daily feed (no key) that involve one of
//  the app's landmarks or cities, shown at the top of the city list (the iPhone's
//  home screen, the Vision Pro's list of cities). Tapping one
//  opens that city. The feed is English Wikipedia's, matched against the
//  landmarks' and cities' English names.
//

import SwiftUI

nonisolated struct DayEvent: Identifiable, Hashable, Sendable {
    let year: Int
    let text: String
    let cityName: String
    /// The landmark it's about, when it's about one
    let landmarkName: String?

    var id: String { "\(year)-\(text)" }
}

actor OnThisDayService {
    static let shared = OnThisDayService()
    nonisolated static let maxEvents = 3

    private var cache: [String: [DayEvent]] = [:]

    /// Today's events that name a landmark (best) or a city, newest first
    func events(on date: Date, landmarks: [String: [String]], cities: [String]) async -> [DayEvent] {
        let parts = Calendar.current.dateComponents([.month, .day], from: date)
        guard let month = parts.month, let day = parts.day else { return [] }
        let key = String(format: "%02d/%02d", month, day)
        if let cached = cache[key] { return cached }

        guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/feed/onthisday/events/\(key)") else { return [] }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Stamped-A-City-Passport/2.10", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        let result = Self.matchingEvents(in: data, landmarks: landmarks, cities: cities)
        cache[key] = result
        return result
    }

    /// The feed's events that name a landmark, then those that name a city
    nonisolated static func matchingEvents(in data: Data, landmarks: [String: [String]],
                                           cities: [String]) -> [DayEvent] {
        guard let feed = try? JSONDecoder().decode(Feed.self, from: data) else { return [] }
        var landmarkEvents: [DayEvent] = []
        var cityEvents: [DayEvent] = []
        for event in feed.events where isSuitable(event.text) {
            let titles = Set(event.pages.map { $0.titles.normalized.lowercased() })
            let text = event.text.lowercased()
            // A landmark: one of the event's articles is it, or the text names it in full
            if let match = Self.landmarkMatch(titles: titles, text: text, landmarks: landmarks) {
                landmarkEvents.append(DayEvent(year: event.year, text: event.text,
                                               cityName: match.city, landmarkName: match.name))
            } else if let city = cities.first(where: { titles.contains($0.lowercased()) }) {
                cityEvents.append(DayEvent(year: event.year, text: event.text, cityName: city, landmarkName: nil))
            }
        }
        return Array((landmarkEvents + cityEvents).prefix(Self.maxEvents))
    }

    /// This card is on a travel app's home screen, so wars and deaths are left out
    nonisolated static func isSuitable(_ text: String) -> Bool {
        let grim = #"\b(kill\w*|dead|deaths?|die[sd]?|massacre\w*|murder\w*|executed|execution|hanged|sentenced|"#
            + #"rape\w*|bomb\w*|terror\w*|genocide|assassinat\w*|suicide|wars?|shot|shooting|attack\w*|crash\w*)\b"#
        return text.range(of: grim, options: [.regularExpression, .caseInsensitive]) == nil
    }

    nonisolated private static func landmarkMatch(titles: Set<String>, text: String,
                                      landmarks: [String: [String]]) -> (name: String, city: String)? {
        for (city, names) in landmarks {
            for name in names {
                let lower = name.lowercased()
                // Short names ("The Met") would match too much text
                if titles.contains(lower) || (lower.count >= 12 && text.contains(lower)) {
                    return (name, city)
                }
            }
        }
        return nil
    }

    nonisolated private struct Feed: Decodable {
        struct Event: Decodable {
            let text: String
            let year: Int
            let pages: [Page]
        }
        struct Page: Decodable {
            struct Titles: Decodable { let normalized: String }
            let titles: Titles
        }
        let events: [Event]
    }
}

/// The card at the top of the city list; hidden when nothing today involves the app's places
struct OnThisDayCard: View {
    /// Each city's landmark names, by city
    let landmarks: [String: [String]]
    let cities: [String]
    /// Space above the card, only when there's a card
    var topGap: CGFloat = 0
    let onSelectCity: (String) -> Void

    @State private var events: [DayEvent] = []

    var body: some View {
        Group {
            if events.isEmpty {
                // Nothing to show yet: a zero-height view just to run the lookup
                Color.clear.frame(height: 0)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Label("On This Day", systemImage: "calendar")
                        .font(.headline)
                    ForEach(events) { event in
                        // A tap gesture, not a Button: every Button in a List row fires on any tap in the row
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: "\(event.year) · \(event.landmarkName ?? event.cityName)")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                            Text(verbatim: event.text)
                                .font(.caption)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        #if os(visionOS)
                        .hoverEffect()
                        #endif
                        .onTapGesture { onSelectCity(event.cityName) }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { onSelectCity(event.cityName) }
                        .accessibilityHint(Text("Opens \(event.cityName)"))
                    }
                    Text("From Wikipedia (CC BY-SA)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                #if os(visionOS)
                .padding(.horizontal, 12)
                #endif
                .padding(.top, topGap)
            }
        }
        .task {
            events = await OnThisDayService.shared.events(on: .now, landmarks: landmarks, cities: cities)
        }
    }
}
