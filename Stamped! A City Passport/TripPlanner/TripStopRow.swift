//
//  TripStopRow.swift
//  Stamped! A City Passport
//
//  One stop in a trip day: icon, name, detail line, and the walk to the next stop.
//

import SwiftUI

struct TripStopRow: View {
    let stop: ResolvedTripStop
    /// Position in the day (1, 2, 3…), matching the pin on the route map.
    let number: Int
    /// nil for the last stop of the day, or when a location is missing.
    let walkMinutesToNext: Int?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The icon tile grows with the text, so large sizes don't crowd the symbol
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 28

    /// Orange for landmarks; pink for saved places, matching their pins on the city map
    private var tint: Color { stop.isLandmark ? DS.Palette.accent : DS.Palette.wishlist }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Space.m) {
            StopNumberBadge(number: number, isLandmark: stop.isLandmark)
                .padding(.top, 1)
                .accessibilityHidden(true)

            Image(systemName: stop.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: iconSize, height: iconSize)
                .background(
                    tint.opacity(0.15),
                    in: RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text(stop.name)
                    .font(.body.weight(.medium))
                if let subtitle = stop.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                }
                if let walkMinutesToNext {
                    // HStack rather than Label: inside a List, Label gives the icon a wide column
                    HStack(spacing: DS.Space.xs) {
                        Image(systemName: "figure.walk")
                        Text("\(walkMinutesToNext) min walk to next")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, DS.Space.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var text = "Stop \(number), \(stop.name), \(stop.isLandmark ? "landmark" : "saved place")"
        if let walkMinutesToNext {
            text += ", \(walkMinutesToNext) minute walk to next stop"
        }
        return text
    }
}
