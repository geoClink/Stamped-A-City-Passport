//
//  StudentLifeSection.swift
//  Stamped! A City Passport
//
//  "Student Life" on a campus page, so a visiting student can picture living there:
//  residence neighborhoods, the union, study spots, dining halls and hangouts,
//  grouped by kind, each with a button that shows it in Maps.
//

import SwiftUI

struct StudentLifeSection: View {
    let campus: CityLocation.City
    var isHighContrast: Bool

    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    /// Spots whose full description is showing
    @State private var expandedIDs: Set<String> = []
    @ScaledMetric(relativeTo: .body) private var mapButtonSize: CGFloat = 36

    /// Only the categories this campus has, in the order the enum lists them
    private var groups: [(category: StudentLifeSpot.Category, spots: [StudentLifeSpot])] {
        let spots = campus.studentLife
        return StudentLifeSpot.Category.allCases.compactMap { category in
            let matching = spots.filter { $0.category == category }
            return matching.isEmpty ? nil : (category, matching)
        }
    }

    /// The school's color, like the traditions section; orange when it has none
    private var accent: Color {
        isHighContrast ? .primary : (campus.stampColor(darkMode: colorScheme == .dark) ?? DS.Palette.accent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader("STUDENT LIFE", systemImage: "house.and.flag", isHighContrast: isHighContrast)
                .dsPageMargin()

            ForEach(groups, id: \.category) { group in
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    Label(group.category.title, systemImage: group.category.systemImage)
                        .font(.subheadline.bold())
                        .foregroundColor(accent)
                        .accessibilityAddTraits(.isHeader)
                        .dsPageMargin()

                    // Same list card as the traditions: hairline dividers, or bordered rows in high contrast
                    VStack(spacing: isHighContrast ? DS.Space.m : 0) {
                        ForEach(group.spots) { spot in
                            row(spot)
                            if !isHighContrast && spot.id != group.spots.last?.id {
                                Divider().padding(.leading, DS.Space.l)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .dsCard(padding: isHighContrast ? DS.Space.m : 0, isHighContrast: isHighContrast)
                    .dsPageMargin()
                }
            }
        }
    }

    private func row(_ spot: StudentLifeSpot) -> some View {
        let isExpanded = expandedIDs.contains(spot.id)
        return HStack(alignment: .top, spacing: DS.Space.m) {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text(spot.name)
                    .font(isHighContrast ? .headline.bold() : .headline)
                    .fixedSize(horizontal: false, vertical: true)
                // Two lines until tapped, so the list stays easy to scan
                Text(spot.description)
                    .font(.subheadline)
                    .foregroundColor(isHighContrast ? .primary : .secondary)
                    .lineLimit(isExpanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: isExpanded)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.snappy) {
                    if isExpanded { expandedIDs.remove(spot.id) } else { expandedIDs.insert(spot.id) }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint(isExpanded ? "" : NSLocalizedString("Double tap to read more.", comment: "Campus tradition row: VoiceOver hint to expand the description"))

            Spacer(minLength: 0)

            // Opens Maps at the spot, the same way the traditions' map button does
            Button {
                let encoded = spot.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "maps://?ll=\(spot.latitude),\(spot.longitude)&q=\(encoded)") {
                    openURL(url)
                }
            } label: {
                Image(systemName: "map")
                    .font(.body)
                    .foregroundColor(accent)
                    .frame(width: mapButtonSize, height: mapButtonSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(format: NSLocalizedString("Show %@ in Maps", comment: "Campus tradition: VoiceOver label for the map button"), spot.name))
        }
        .padding(DS.Space.l)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                .fill(isHighContrast ? Color(.systemBackground) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
        )
    }
}
