//
//  BuildingTimelineSection.swift
//  Stamped! A City Passport
//
//  Horizontal chronological strip of buildings ordered by year built.
//

import SwiftUI

struct BuildingTimelineSection: View {
    let buildings: [Building]
    let visitedIDs: Set<String>
    let isHighContrast: Bool

    private var sorted: [Building] {
        buildings.sorted { $0.yearBuilt < $1.yearBuilt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("CHRONOLOGY", systemImage: "clock.arrow.circlepath")
                .font(.system(.caption, design: .default))
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .kerning(1.2)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, building in
                        let isVisited = visitedIDs.contains(building.id)
                        let isLast = index == sorted.count - 1

                        HStack(spacing: 0) {
                            TimelineCell(building: building, isVisited: isVisited, isHighContrast: isHighContrast)

                            if !isLast {
                                Rectangle()
                                    .fill(isHighContrast ? Color.primary.opacity(0.4) : Color.secondary.opacity(0.25))
                                    .frame(width: 20, height: 1)
                                    // Align connector with the dot in TimelineCell (~16pt from top of content)
                                    .padding(.bottom, 28)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
        }
    }
}

// MARK: - Individual cell

private struct TimelineCell: View {
    let building: Building
    let isVisited: Bool
    let isHighContrast: Bool

    private var accent: Color { isHighContrast ? .primary : .adventureOrange }

    var body: some View {
        VStack(spacing: 6) {
            Text(String(building.yearBuilt))
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(isVisited ? accent : .secondary)

            Circle()
                .fill(isVisited ? accent : Color.secondary.opacity(0.3))
                .frame(width: 10, height: 10)
                .overlay(
                    Circle().stroke(isVisited ? accent : Color.clear, lineWidth: 1.5)
                        .scaleEffect(1.8)
                        .opacity(0.3)
                )

            Text(building.name)
                .font(.caption2)
                .fontWeight(isVisited ? .semibold : .regular)
                .foregroundColor(isVisited ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 88)
        }
        .frame(width: 100)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isVisited
                    ? (isHighContrast ? Color.primary.opacity(0.08) : Color.adventureOrange.opacity(0.07))
                    : Color(UIColor.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isVisited ? accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(building.yearBuilt), \(building.name), \(isVisited ? "stamped" : "not yet visited")")
    }
}
