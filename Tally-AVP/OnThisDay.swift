//
//  OnThisDay.swift
//  Tally-AVP
//
//  "On this day": events from Wikipedia's daily feed (no key) that involve one of
//  the app's landmarks or cities, shown at the top of the city list. Tapping one
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
    static let maxEvents = 3

    private var cache: [String: [DayEvent]] = [:]

    /// Today's events that name a landmark (best) or a city, newest first
    func events(on date: Date, landmarks: [String: [String]], cities: [String]) async -> [DayEvent] {
        let parts = Calendar.current.dateComponents([.month, .day], from: date)
        guard let month = parts.month, let day = parts.day else { return [] }
        let key = String(format: "%02d/%02d", month, day)
        if let cached = cache[key] { return cached }

        guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/feed/onthisday/events/\(key)") else { return [] }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Stamped-A-City-Passport/2.10 (visionOS)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let feed = try? JSONDecoder().decode(Feed.self, from: data) else { return [] }

        var landmarkEvents: [DayEvent] = []
        var cityEvents: [DayEvent] = []
        for event in feed.events {
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
        let result = Array((landmarkEvents + cityEvents).prefix(Self.maxEvents))
        cache[key] = result
        return result
    }

    private static func landmarkMatch(titles: Set<String>, text: String,
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

    private struct Feed: Decodable {
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
    let onSelectCity: (String) -> Void

    private let store = VisionStore.shared
    @State private var events: [DayEvent] = []

    var body: some View {
        Group {
            if !events.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("On This Day", systemImage: "calendar")
                        .font(.headline)
                    ForEach(events) { event in
                        Button { onSelectCity(event.cityName) } label: {
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
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text("Opens \(event.cityName)"))
                    }
                    Text("From Wikipedia (CC BY-SA)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 12)
            }
        }
        .task {
            let landmarks = store.buildingsByCity.mapValues { $0.map(\.name) }
            events = await OnThisDayService.shared.events(on: .now, landmarks: landmarks, cities: store.cityNames)
        }
    }
}
