//
//  TopEatsSection.swift
//  Stamped! A City Passport
//

import SwiftUI

struct TopEatsSection: View {
    @ObservedObject var service: FoursquareService
    /// The Stamped city, so a restaurant saved from its place card shows on this city's map.
    let cityName: String
    let isHighContrast: Bool
    var brandColor: Color { isHighContrast ? .primary : Color.adventureOrange }

    /// The restaurant whose Apple place card is open.
    @State private var tappedPlace: TappedApplePlace?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader("Nearby Dining", systemImage: "fork.knife.circle.fill", isHighContrast: isHighContrast)

            VStack(spacing: 0) {
                if service.isLoading {
                    HStack(spacing: DS.Space.s) {
                        ProgressView().scaleEffect(0.7)
                        Text("Finding nearby spots…")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DS.Space.l)
                } else if service.venues.isEmpty {
                    Group {
                        if service.failed {
                            ContentUnavailableView(
                                "Couldn't Load Restaurants",
                                systemImage: "fork.knife.circle",
                                description: Text("Check your connection and try again.")
                            )
                        } else {
                            ContentUnavailableView(
                                "No Results Nearby",
                                systemImage: "fork.knife.circle",
                                description: Text("No dining spots found in this area.")
                            )
                        }
                    }
                    .padding(DS.Space.l)
                } else {
                    ForEach(Array(service.venues.enumerated()), id: \.element.id) { index, venue in
                        VenueRow(venue: venue, rank: index + 1, brandColor: brandColor, isHighContrast: isHighContrast) {
                            tappedPlace = TappedApplePlace(mapItem: venue.mapItem)
                        }
                        if index < service.venues.count - 1 {
                            Divider().padding(.leading, DS.Space.l)
                        }
                    }
                }
            }
            .dsCard(padding: 0, isHighContrast: isHighContrast)

            if !service.isLoading && !service.venues.isEmpty {
                Text("Dining data from Apple Maps. Stamped is not responsible for the quality of listed venues.")
                    .font(.caption2)
                    .foregroundColor(isHighContrast ? .primary : .secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .dsPageMargin()
        .sheet(item: $tappedPlace) { place in
            ApplePlaceSheet(mapItem: place.mapItem, cityName: cityName)
        }
    }
}

// MARK: - Single venue row

private struct VenueRow: View {
    let venue: FoursquareVenue
    let rank: Int
    let brandColor: Color
    let isHighContrast: Bool
    /// Opens Apple's place card for this restaurant.
    let onTap: () -> Void

    @ScaledMetric(relativeTo: .caption) private var rankBadgeSize: CGFloat = 30
    /// The units setting (meters vs feet) from Settings.
    @AppStorage("use_metric_units") private var useMetric = true

    /// "4 min walk" or "1.2 km" from the city's center.
    private var distance: String {
        DiningPlaceLabel.distanceText(meters: venue.distanceMeters, useMetric: useMetric)
    }

    var body: some View {
        Button {
            HapticManager.shared.trigger(.selection)
            onTap()
        } label: {
            rowContent
        }
        .buttonStyle(.plain)
    }

    private var rowContent: some View {
        HStack(spacing: DS.Space.m) {
            ZStack {
                Circle()
                    .fill(rank == 1 ? brandColor : Color(UIColor.tertiarySystemGroupedBackground))
                    .frame(width: rankBadgeSize, height: rankBadgeSize)
                Text("\(rank)")
                    .font(.caption.bold())
                    .foregroundColor(rank == 1 ? (isHighContrast ? Color(UIColor.systemBackground) : .white) : .secondary)
                    .minimumScaleFactor(0.7)
            }

            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text(venue.name)
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                Text("\(distance) · \(venue.categoryName)")
                    .font(.caption).foregroundColor(isHighContrast ? .primary : .secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2).foregroundColor(.secondary)
        }
        .padding(.horizontal, DS.Space.l)
        .padding(.vertical, DS.Space.m)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(rank), \(venue.name), \(venue.categoryName), \(distance)")
        .accessibilityHint("Shows photos, hours and ratings")
    }
}
