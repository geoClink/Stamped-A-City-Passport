//
//  LandmarkAccessibilitySection.swift
//  Stamped! A City Passport
//
//  "Accessibility" on a landmark's page: whether there's step-free (wheelchair) access
//  and accessible toilets, from OpenStreetMap. Useful for wheelchair users, families
//  with strollers and anyone who'd rather avoid steps.
//
//  Shows nothing at all when OSM has no wheelchair tag for the landmark. The wording
//  says it's community data that may be out of date, and links to the OSM feature so
//  people can check it (or fix it).
//

import SwiftUI

struct LandmarkAccessibilitySection: View {
    let building: Building
    var isHighContrast = false

    @State private var browserLink: BrowserLink?

    var body: some View {
        if let accessibility = LandmarkAccessibilityStore.accessibility(for: building.id),
           let access = accessibility.stepFreeAccess {
            section(accessibility, access: access)
        }
    }

    private func section(_ accessibility: LandmarkAccessibility, access: LandmarkAccessibility.StepFreeAccess) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader("Accessibility", systemImage: "figure.roll", isHighContrast: isHighContrast)

            VStack(alignment: .leading, spacing: DS.Space.m) {
                AccessibilityFactRow(
                    label: "Step-free access",
                    value: access.valueText,
                    systemImage: access.systemImage,
                    isHighContrast: isHighContrast
                )
                if let hasToilets = accessibility.hasAccessibleToilets {
                    AccessibilityFactRow(
                        label: "Accessible toilets",
                        value: hasToilets ? "Yes" : "No",
                        systemImage: hasToilets ? "checkmark.circle.fill" : "xmark.circle.fill",
                        isHighContrast: isHighContrast
                    )
                }

                Text("Mapped by OpenStreetMap volunteers and may be out of date. Check with the venue before you go.")
                    .font(.caption)
                    .foregroundStyle(isHighContrast ? Color.primary : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let osmURL = accessibility.osmURL {
                    Button {
                        browserLink = BrowserLink(url: osmURL)
                    } label: {
                        Label("View on OpenStreetMap", systemImage: "arrow.up.right.square")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(isHighContrast ? Color.primary : DS.Palette.accent)
                    .accessibilityHint(Text("Opens this place on openstreetmap.org"))
                }

                // Required by the ODbL licence; it's a credit line, so it isn't translated
                Text(verbatim: "© OpenStreetMap contributors")
                    .font(.caption2)
                    .foregroundStyle(isHighContrast ? Color.primary : Color.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCard(isHighContrast: isHighContrast)
        }
        .inAppBrowser(item: $browserLink)
    }
}

// MARK: - Row

/// An icon, a small label ("Step-free access") and its answer ("Partly").
/// VoiceOver reads it as one item: "Step-free access, Partly".
private struct AccessibilityFactRow: View {
    let label: LocalizedStringKey
    let value: LocalizedStringKey
    let systemImage: String
    var isHighContrast = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.m) {
            Image(systemName: systemImage)
                .font(.body.weight(isHighContrast ? .bold : .regular))
                .foregroundStyle(isHighContrast ? Color.primary : DS.Palette.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.monospaced().bold())
                    .textCase(.uppercase)
                    .foregroundStyle(isHighContrast ? Color.primary : Color.secondary)
                Text(value)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Wording and icons

private extension LandmarkAccessibility.StepFreeAccess {
    /// What we tell the visitor. Never colour alone: the words and icon differ too.
    var valueText: LocalizedStringKey {
        switch self {
        case .yes: return "Yes"
        case .limited: return "Partly"
        case .no: return "No"
        }
    }

    var systemImage: String {
        switch self {
        case .yes: return "checkmark.circle.fill"
        case .limited: return "exclamationmark.circle.fill"
        case .no: return "xmark.circle.fill"
        }
    }
}
