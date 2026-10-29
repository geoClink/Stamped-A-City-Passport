//
//  PlaceEventsView.swift
//  Stamped! A City Passport
//
//  Upcoming Ticketmaster and SeatGeek events at a place, shown on its map card.
//  Shows nothing at all while loading or when there are no events, so cards
//  for places without events don't change.
//

import SwiftUI
import CoreLocation

struct PlaceEventsView: View {
    let coordinate: CLLocationCoordinate2D
    let placeName: String
    /// Landmarks only show events actually at the venue; saved places also show nearby ones.
    var includeNearby = true
    let onOpenTickets: (URL) -> Void

    @State private var events: [TicketmasterEvent] = []
    @State private var isAtVenue = false
    @ScaledMetric(relativeTo: .callout) private var iconColumnWidth: CGFloat = 28

    var body: some View {
        Group {
            if !events.isEmpty {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    DSSectionHeader(isAtVenue ? "Upcoming Events Here" : "Happening Nearby",
                                    systemImage: "ticket.fill")
                    ForEach(events.prefix(3)) { event in
                        eventRow(event)
                    }
                }
            }
        }
        // Reloads when the card switches to a different place
        .task(id: placeName) {
            events = []
            let result = await TicketmasterService.shared.events(near: coordinate, placeName: placeName)
            guard !Task.isCancelled else { return }
            if result.isAtVenue || includeNearby {
                isAtVenue = result.isAtVenue
                events = result.events
            }
        }
    }

    private func eventRow(_ event: TicketmasterEvent) -> some View {
        Button {
            if let url = event.ticketURL { onOpenTickets(url) }
        } label: {
            HStack(spacing: DS.Space.s) {
                Image(systemName: event.category.icon)
                    .font(.callout)
                    .foregroundStyle(DS.Palette.accent)
                    .frame(width: iconColumnWidth)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text([event.date, event.time, isAtVenue ? nil : event.venueName]
                            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: DS.Space.xs)
                if event.ticketURL != nil {
                    Text("Tickets")
                        .font(.caption.bold())
                        .foregroundStyle(DS.Palette.accent)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(event.ticketURL == nil)
        .accessibilityHint(event.ticketURL != nil ? "Opens tickets" : "")
    }
}
