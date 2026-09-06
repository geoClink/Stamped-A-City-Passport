//
//  TopEatsSection.swift
//  Stamped! A City Passport
//

import SwiftUI

struct TopEatsSection: View {
    @ObservedObject var service: FoursquareService
    let isHighContrast: Bool
    var brandColor: Color { isHighContrast ? .primary : Color.adventureOrange }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("NEARBY DINING", systemImage: "fork.knife.circle.fill")
                .font(.system(.caption, design: .default))
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .kerning(1.2)

            if service.isLoading {
                HStack(spacing: 10) {
                    ProgressView().scaleEffect(0.7)
                    Text("Finding nearby spots…")
                        .font(.caption).foregroundColor(.secondary)
                }
            } else if service.venues.isEmpty {
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
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(service.venues.enumerated()), id: \.element.id) { index, venue in
                        VenueRow(venue: venue, rank: index + 1, brandColor: brandColor)
                        if index < service.venues.count - 1 {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)

                Text("Dining data from Apple Maps. Stamped is not responsible for the quality of listed venues.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Single venue row

private struct VenueRow: View {
    let venue: FoursquareVenue
    let rank: Int
    let brandColor: Color

    @ScaledMetric(relativeTo: .caption) private var rankBadgeSize: CGFloat = 30

    var body: some View {
        if let url = venue.mapsURL {
            Link(destination: url) {
                rowContent
            }
            .simultaneousGesture(TapGesture().onEnded {
                HapticManager.shared.trigger(.selection)
            })
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(rank == 1 ? brandColor : Color(UIColor.tertiarySystemBackground))
                    .frame(width: rankBadgeSize, height: rankBadgeSize)
                Text("\(rank)")
                    .font(.caption.bold())
                    .foregroundColor(rank == 1 ? .white : .secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(venue.name)
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                Text(venue.categoryName)
                    .font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.system(size: 11)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(rank), \(venue.name), \(venue.categoryName)")
        .accessibilityHint("Opens in Apple Maps")
    }
}
