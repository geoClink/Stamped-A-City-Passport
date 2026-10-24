//
//  PlanTripCard.swift
//  Stamped! A City Passport
//
//  The "Plan a Trip" card on the city page. Same look as the quiz card.
//

import SwiftUI

struct PlanTripCard: View {
    let cityName: String
    let isHighContrast: Bool
    let onTap: () -> Void

    @ObservedObject private var store = TripStore.shared

    private var tripCount: Int { store.trips(in: cityName).count }

    private var subtitle: String {
        switch tripCount {
        case 0: "Plan your days, stop by stop."
        case 1: "1 trip planned"
        default: "\(tripCount) trips planned"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "suitcase.rolling.fill")
                    .font(.title2)
                    .foregroundColor(isHighContrast ? .primary : .adventureOrange)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Plan a Trip")
                        .font(.headline)
                        .fontWeight(isHighContrast ? .black : .semibold)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .fontWeight(isHighContrast ? .bold : .regular)
                        .foregroundColor(isHighContrast ? .primary : .secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(isHighContrast ? .primary : .tertiary)
            }
            .padding()
            .background(isHighContrast ? Color(UIColor.systemBackground) : Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 3)
            )
        }
        .buttonStyle(RoundedButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Plan a Trip. \(subtitle)")
        .accessibilityHint("Opens the trip planner for \(cityName).")
    }
}
