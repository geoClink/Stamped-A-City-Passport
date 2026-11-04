//
//  ShowProgressIntent.swift
//  Stamped! A City Passport
//
//  "Show My Progress": Siri says how many landmarks you've stamped, and Shortcuts or Siri
//  shows a small card with the same numbers. It runs without opening the app.
//

import AppIntents
import SwiftUI

/// The passport's totals across every city and campus.
struct PassportProgress {
    var stampedLandmarks = 0
    var totalLandmarks = 0
    /// Cities and campuses with at least one stamp
    var placesVisited = 0
    /// Cities and campuses with every landmark stamped
    var placesCompleted = 0

    var fraction: Double {
        totalLandmarks > 0 ? Double(stampedLandmarks) / Double(totalLandmarks) : 0
    }

    @MainActor static func current() -> PassportProgress {
        let visited = GlobalProgressManager.shared.visitedIDs
        var progress = PassportProgress()
        for city in CityLocation.City.allCases {
            let buildings = city.buildings
            guard !buildings.isEmpty else { continue }
            let stamped = buildings.filter { visited.contains($0.id) }.count
            progress.stampedLandmarks += stamped
            progress.totalLandmarks += buildings.count
            if stamped > 0 { progress.placesVisited += 1 }
            if stamped == buildings.count { progress.placesCompleted += 1 }
        }
        return progress
    }

    /// What Siri says. Written as "label: number" so no language needs plural forms.
    var dialog: IntentDialog {
        if stampedLandmarks == 0 {
            return IntentDialog("You haven't stamped any landmarks yet. Open a city in Stamped! to collect your first stamp.")
        }
        return IntentDialog("Landmarks stamped: \(stampedLandmarks) of \(totalLandmarks). Cities and campuses visited: \(placesVisited). Completed: \(placesCompleted).")
    }
}

struct ShowProgressIntent: AppIntent {
    static let title: LocalizedStringResource = "Show My Progress"
    static let description = IntentDescription("Tells you how many landmarks you've stamped and how many cities you've visited, without opening Stamped!.")

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let progress = PassportProgress.current()
        return .result(dialog: progress.dialog, view: PassportProgressSnippet(progress: progress))
    }
}

// MARK: - Card

/// The card under Siri's answer: a ring for the share of landmarks stamped, then the three totals.
struct PassportProgressSnippet: View {
    let progress: PassportProgress

    var body: some View {
        HStack(spacing: 16) {
            ProgressRing(fraction: progress.fraction)
            VStack(alignment: .leading, spacing: 6) {
                StatRow(
                    label: "Landmarks stamped",
                    value: "\(progress.stampedLandmarks.formatted()) / \(progress.totalLandmarks.formatted())"
                )
                StatRow(label: "Cities and campuses visited", value: progress.placesVisited.formatted())
                StatRow(label: "Completed", value: progress.placesCompleted.formatted())
            }
        }
        .padding()
    }
}

private struct ProgressRing: View {
    let fraction: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.adventureOrange.opacity(0.2), lineWidth: 8)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.adventureOrange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                .font(.headline)
                .monospacedDigit()
        }
        .frame(width: 72, height: 72)
        // The rows beside it already say the numbers
        .accessibilityHidden(true)
    }
}

private struct StatRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}
