//
//  CampusTraditionsSection.swift
//  Stamped! A City Passport
//
//  The campus traditions scavenger hunt on a campus page: things a visitor can do
//  ("Rub John Harvard's foot"), checked off one by one, synced through iCloud.
//

import SwiftUI

struct CampusTraditionsSection: View {
    let campus: CityLocation.City
    var isHighContrast: Bool

    @ObservedObject private var progressManager = GlobalProgressManager.shared
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    /// Traditions whose full description is showing
    @State private var expandedIDs: Set<String> = []
    @ScaledMetric(relativeTo: .body) private var mapButtonSize: CGFloat = 36

    private var traditions: [CampusTradition] { campus.traditions }
    private var doneCount: Int { traditions.filter { progressManager.isTraditionDone($0.id) }.count }
    private var allDone: Bool { !traditions.isEmpty && doneCount == traditions.count }

    /// The school's color, like the campus stamp; orange when it has none
    private var accent: Color {
        isHighContrast ? .primary : (campus.stampColor(darkMode: colorScheme == .dark) ?? DS.Palette.accent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader(title: "CAMPUS TRADITIONS", systemImage: "flag.checkered", isHighContrast: isHighContrast) {
                // A ring in the school's color fills up as traditions are checked off
                HStack(spacing: DS.Space.s) {
                    ZStack {
                        Circle().stroke(accent.opacity(0.2), lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: traditions.isEmpty ? 0 : CGFloat(doneCount) / CGFloat(traditions.count))
                            .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(), value: doneCount)
                    }
                    .frame(width: 18, height: 18)
                    Text("\(doneCount)/\(traditions.count)")
                        .font(.caption.monospaced().bold())
                        .foregroundColor(accent)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(format: NSLocalizedString("%d of %d traditions done", comment: "Campus page: traditions progress for VoiceOver"), doneCount, traditions.count))
            }
            .dsPageMargin()

            if allDone {
                Label(NSLocalizedString("Traditions Keeper", comment: "Campus page: badge shown when every tradition on a campus is done"), systemImage: "flag.checkered")
                    .font(.caption.bold())
                    .padding(.horizontal, DS.Space.m)
                    .padding(.vertical, DS.Space.xs)
                    .background(accent.opacity(isHighContrast ? 0 : 0.15))
                    .foregroundColor(accent)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(isHighContrast ? Color.primary : .clear, lineWidth: 1))
                    .dsPageMargin()
                    .transition(.scale.combined(with: .opacity))
            }

            // Same list card as Landmarks: hairline dividers, or bordered rows in high contrast
            VStack(spacing: isHighContrast ? DS.Space.m : 0) {
                ForEach(traditions) { tradition in
                    row(tradition)
                    if !isHighContrast && tradition.id != traditions.last?.id {
                        Divider().padding(.leading, DS.Space.l)
                            .accessibilityHidden(true)
                    }
                }
            }
            .dsCard(padding: isHighContrast ? DS.Space.m : 0, isHighContrast: isHighContrast)
            .dsPageMargin()

            Text(CampusDisclaimer.text)
                .font(.caption2)
                .foregroundColor(isHighContrast ? .primary : .secondary)
                .dsPageMargin()
        }
    }

    private func row(_ tradition: CampusTradition) -> some View {
        let isDone = progressManager.isTraditionDone(tradition.id)
        let isExpanded = expandedIDs.contains(tradition.id)
        return HStack(alignment: .top, spacing: DS.Space.m) {
            Button {
                withAnimation(.spring()) { progressManager.toggleTradition(tradition.id) }
                HapticManager.shared.trigger(isDone ? .selection : .success)
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isDone ? accent : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDone
                ? NSLocalizedString("Done", comment: "Campus tradition: VoiceOver state when completed")
                : NSLocalizedString("Not done", comment: "Campus tradition: VoiceOver state when not completed"))
            .accessibilityHint(NSLocalizedString("Double tap to check this tradition off.", comment: "Campus tradition: VoiceOver hint for the checkbox"))

            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text(tradition.name)
                    .font(isHighContrast ? .headline.bold() : .headline)
                    .strikethrough(isDone && !isHighContrast, color: .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                // One line until tapped, so the list reads like a checklist, not a page of text
                Text(tradition.description)
                    .font(.subheadline)
                    .foregroundColor(isHighContrast ? .primary : .secondary)
                    .lineLimit(isExpanded ? nil : 1)
                    .fixedSize(horizontal: false, vertical: isExpanded)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.snappy) {
                    if isExpanded { expandedIDs.remove(tradition.id) } else { expandedIDs.insert(tradition.id) }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint(isExpanded ? "" : NSLocalizedString("Double tap to read more.", comment: "Campus tradition row: VoiceOver hint to expand the description"))

            Spacer(minLength: 0)

            Button {
                let encoded = tradition.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "maps://?ll=\(tradition.latitude),\(tradition.longitude)&q=\(encoded)") {
                    openURL(url)
                }
            } label: {
                Image(systemName: "map")
                    .font(.body)
                    .foregroundColor(accent)
                    .frame(width: mapButtonSize, height: mapButtonSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(format: NSLocalizedString("Show %@ in Maps", comment: "Campus tradition: VoiceOver label for the map button"), tradition.name))
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
