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

    // Places with no build year (lakes, mountains) can't go on a timeline.
    private var sorted: [Building] {
        buildings
            .filter(\.hasKnownYear)
            .sorted { $0.yearBuilt < $1.yearBuilt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader("Chronology", systemImage: "clock.arrow.circlepath", isHighContrast: isHighContrast)
                .dsPageMargin()

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
                .padding(DS.Space.l)
            }
            // The strip scrolls edge to edge inside the card
            .dsCard(padding: 0, isHighContrast: isHighContrast)
            .dsPageMargin()
        }
    }
}

// MARK: - Individual cell

private struct TimelineCell: View {
    let building: Building
    let isVisited: Bool
    let isHighContrast: Bool

    private var accent: Color { isHighContrast ? .primary : DS.Palette.accent }

    /// Fixed so the strip lines up, but scaled so two-line names still fit at large text sizes
    @ScaledMetric(relativeTo: .caption2) private var cellWidth: CGFloat = 100

    var body: some View {
        VStack(spacing: DS.Space.s) {
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
                .minimumScaleFactor(0.85)
                .frame(width: cellWidth - DS.Space.m)
        }
        .frame(width: cellWidth)
        .padding(.vertical, DS.Space.m)
        .padding(.horizontal, DS.Space.xs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                .fill(isVisited
                    ? (isHighContrast ? Color.primary.opacity(0.08) : DS.Palette.accent.opacity(0.07))
                    : Color(UIColor.tertiarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                .stroke(isVisited ? accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(String(building.yearBuilt)), \(building.name), \(isVisited ? "stamped" : "not yet visited")")
    }
}
