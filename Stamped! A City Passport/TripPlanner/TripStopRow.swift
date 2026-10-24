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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            StopNumberBadge(number: number, isLandmark: stop.isLandmark)
                .padding(.top, 1)
                .accessibilityHidden(true)

            Image(systemName: stop.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(stop.isLandmark ? Color.adventureOrange : Color.pink)
                .frame(width: 28, height: 28)
                .background(
                    (stop.isLandmark ? Color.adventureOrange : Color.pink).opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 7)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(stop.name)
                    .font(.body.weight(.medium))
                if let subtitle = stop.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let walkMinutesToNext {
                    // HStack rather than Label: inside a List, Label gives the icon a wide column
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                        Text("\(walkMinutesToNext) min walk to next")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 2)
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
