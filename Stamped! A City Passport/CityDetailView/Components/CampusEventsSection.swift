//
//  CampusEventsSection.swift
//  Stamped! A City Passport
//
//  "Campus Events" on a campus page: the next few weeks from the school's own public calendar
//  (CampusEventsService). Shows nothing for campuses without a feed or with no events.
//  Factual fields only and no photos; each card opens the school's event page.
//

import SwiftUI

struct CampusEventsSection: View {
    @ObservedObject var service: CampusEventsService
    let campus: CityLocation.City
    let isHighContrast: Bool
    var brandColor: Color { isHighContrast ? .primary : Color.adventureOrange }

    @State private var browserLink: BrowserLink?

    /// Only this campus's events, never the list left over from the last campus opened
    private var isShowing: Bool {
        campus.campusEventFeed != nil && service.campus == campus && (service.isLoading || !service.events.isEmpty)
    }

    var body: some View {
        if isShowing, let feed = campus.campusEventFeed {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                DSSectionHeader("Campus Events", systemImage: "graduationcap.fill", isHighContrast: isHighContrast)
                    .dsPageMargin()

                VStack(alignment: .leading, spacing: 0) {
                    if service.isLoading {
                        HStack(spacing: DS.Space.s) {
                            ProgressView().scaleEffect(0.7)
                            Text("Finding campus events…")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .padding(DS.Space.l)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: DS.Space.m) {
                                ForEach(service.events) { event in
                                    CampusEventCard(event: event, brandColor: brandColor, isHighContrast: isHighContrast) {
                                        HapticManager.shared.trigger(.selection)
                                        browserLink = BrowserLink(url: event.url)
                                    }
                                }
                            }
                            .padding(DS.Space.l)
                        }
                    }
                }
                .dsCard(padding: 0, isHighContrast: isHighContrast)
                .dsPageMargin()

                // Credit the school whose calendar this is
                Text(String(format: NSLocalizedString("From the %@ calendar", comment: "Campus events: credit line, e.g. From the Purdue events calendar"), feed.calendarName))
                    .font(.caption2)
                    .foregroundColor(isHighContrast ? .primary : .secondary)
                    .dsPageMargin()
            }
            .inAppBrowser(item: $browserLink)
        }
    }
}

// MARK: - Event card (horizontal scroll)

private struct CampusEventCard: View {
    let event: CampusEvent
    let brandColor: Color
    let isHighContrast: Bool
    let onTap: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var cardWidth: CGFloat = 220
    @ScaledMetric(relativeTo: .subheadline) private var badgeSize: CGFloat = 36

    var body: some View {
        Button(action: onTap) { cardContent }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(NSLocalizedString("Opens the event page", comment: "Campus events: VoiceOver hint for an event card"))
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                    .fill(brandColor.opacity(0.15))
                    .frame(width: badgeSize, height: badgeSize)
                Image(systemName: "calendar")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(brandColor)
            }

            // Event name — up to 3 lines so long lecture titles are readable
            Text(event.title)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if !event.summary.isEmpty {
                Text(event.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)

            // Date / time / venue
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Label(event.dateText + " · " + event.timeText, systemImage: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if !event.venue.isEmpty {
                    Label(event.venue, systemImage: "mappin")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            HStack {
                Text("Event Details")
                    .font(.caption.bold())
                    .foregroundColor(brandColor)
                Image(systemName: "arrow.up.right")
                    .font(.caption2.bold())
                    .foregroundColor(brandColor)
            }
        }
        .padding(DS.Space.m)
        .frame(width: cardWidth, alignment: .leading)
        // A card inside the section card: one step lighter/darker and the small radius
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                .fill(isHighContrast ? Color(UIColor.systemBackground) : Color(UIColor.tertiarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
    }

    private var accessibilityLabel: String {
        var parts = [event.title, event.dateText, event.timeText]
        if !event.venue.isEmpty { parts.append(event.venue) }
        return parts.joined(separator: ", ")
    }
}
