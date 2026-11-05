//
//  HistoryTimelineSection.swift
//  Stamped! A City Passport
//
//  "Timeline" on a landmark's page (iPhone building page and the Vision Pro landmark
//  window): its dated moments from Wikidata, then "What the Papers Said", newspaper
//  pages from the year it was built (HistoryTimelineService).
//
//  Shows nothing while the timeline loads or when there is none. The newspapers load
//  on their own afterwards, since that search is slow.
//

import SwiftUI

struct HistoryTimelineSection: View {
    let building: Building
    let cityName: String
    var isHighContrast = false

    @State private var events: [HistoryEvent] = []
    @State private var clippings: [NewspaperClipping] = []
    @State private var searchingPapers = false

    var body: some View {
        Group {
            if !events.isEmpty {
                section
            } else {
                // Nothing to show yet: a zero-height view just to run the lookup
                Color.clear.frame(height: 0)
            }
        }
        .task(id: building.id) { await load() }
    }

    private func load() async {
        events = []
        clippings = []
        let service = HistoryTimelineService.shared
        events = await service.timeline(for: building)
        guard !events.isEmpty, building.hasKnownYear,
              HistoryTimelineService.newspaperYears.contains(building.yearBuilt) else { return }
        searchingPapers = true
        clippings = await service.clippings(for: building, cityName: cityName)
        searchingPapers = false
    }

    private var section: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader("Timeline", systemImage: "clock.arrow.circlepath", isHighContrast: isHighContrast)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(events) { event in
                    TimelineRow(event: event, isLast: event.id == events.last?.id, isHighContrast: isHighContrast)
                }
            }

            if searchingPapers {
                HStack(spacing: DS.Space.s) {
                    ProgressView()
                    Text("Searching old newspapers…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if !clippings.isEmpty {
                papersSection
            }

            Text(clippings.isEmpty
                 ? "Dates from Wikidata"
                 : "Dates from Wikidata · Newspapers from the Library of Congress, Chronicling America")
                .font(.caption2)
                .foregroundStyle(isHighContrast ? .primary : .secondary)
        }
        .animation(.easeInOut(duration: 0.2), value: clippings)
    }

    private var papersSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            Label("What the Papers Said", systemImage: "newspaper")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(clippings) { clipping in
                ClippingCard(clipping: clipping, isHighContrast: isHighContrast)
            }
            // The quotes are machine-read from century-old scans
            Text("Quotes are read automatically from old scans and may contain errors.")
                .font(.caption2)
                .foregroundStyle(isHighContrast ? .primary : .secondary)
        }
    }
}

// MARK: - Timeline row

private struct TimelineRow: View {
    let event: HistoryEvent
    let isLast: Bool
    var isHighContrast = false

    @ScaledMetric(relativeTo: .subheadline) private var yearWidth: CGFloat = 92

    var body: some View {
        HStack(alignment: .top, spacing: DS.Space.m) {
            Text(dateText)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(isHighContrast ? Color.primary : DS.Palette.accent)
                .frame(width: yearWidth, alignment: .trailing)
                .fixedSize(horizontal: false, vertical: true)

            // The dot and the line down to the next one
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(isHighContrast ? Color.primary : DS.Palette.accent, in: Circle())
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 2)
                        .frame(minHeight: 20)
                }
            }
            .accessibilityHidden(true)

            Text(title)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
                .padding(.bottom, isLast ? 0 : DS.Space.m)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        let label = event.label ?? ""
        switch event.kind {
        case .built: return String(localized: "Built", comment: "Timeline: the year a landmark was built")
        case .opened: return String(localized: "Opened", comment: "Timeline: the date a landmark opened")
        case .demolished: return String(localized: "Demolished", comment: "Timeline: the date a landmark was demolished or closed")
        case .event: return label
        case .heritage: return String(localized: "Listed: \(label)", comment: "Timeline: a heritage listing, e.g. \"Listed: National Historic Landmark\"")
        case .replaces: return String(localized: "Replaced \(label)", comment: "Timeline: the building that stood here before")
        case .replacedBy: return String(localized: "Replaced by \(label)", comment: "Timeline: the building that took its place")
        }
    }

    private var icon: String {
        switch event.kind {
        case .built: "hammer.fill"
        case .opened: "door.left.hand.open"
        case .demolished: "xmark"
        case .event: "star.fill"
        case .heritage: "seal.fill"
        case .replaces, .replacedBy: "arrow.triangle.swap"
        }
    }

    /// As exact as Wikidata knows it: "Jun 29, 1989", "June 1989", "1929", "1920s" or "c. 1500"
    private var dateText: String {
        // Wikidata dates are midnight UTC; in local time they could show the day before
        let utc = TimeZone(identifier: "UTC")!
        if event.year < 1 {
            return String(localized: "\(String(1 - event.year)) BC", comment: "Timeline: a year before the common era")
        }
        if let date = event.date, event.precision >= 11 {
            return date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: utc))
        }
        if let date = event.date, event.precision == 10 {
            return date.formatted(Date.FormatStyle(timeZone: utc).month(.abbreviated).year())
        }
        let year = String(event.year)
        if event.precision == 8 { return String(localized: "\(year)s", comment: "Timeline: a decade, e.g. \"1920s\"") }
        if event.precision < 8 { return String(localized: "c. \(year)", comment: "Timeline: an approximate year") }
        return year
    }
}

// MARK: - Newspaper clipping

private struct ClippingCard: View {
    let clipping: NewspaperClipping
    var isHighContrast = false

    @ScaledMetric(relativeTo: .subheadline) private var imageWidth: CGFloat = 72

    var body: some View {
        Link(destination: clipping.pageURL) {
            HStack(alignment: .top, spacing: DS.Space.m) {
                // The scanned front page, a hint of what opens
                AsyncImage(url: clipping.imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.secondary.opacity(0.15)
                }
                .frame(width: imageWidth, height: imageWidth * 1.3)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text(clipping.paper)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(clipping.date.formatted(Date.FormatStyle(date: .long, time: .omitted,
                                                                   timeZone: TimeZone(identifier: "UTC")!)))
                        .font(.caption)
                        .foregroundStyle(isHighContrast ? .primary : .secondary)
                    Text(clipping.quote)
                        .font(.callout.italic())
                        .foregroundStyle(.primary)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    Label("Read the page", systemImage: "arrow.up.right.square")
                        .font(.caption.bold())
                        .foregroundStyle(isHighContrast ? Color.primary : DS.Palette.accent)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Opens the newspaper page on loc.gov"))
    }
}
