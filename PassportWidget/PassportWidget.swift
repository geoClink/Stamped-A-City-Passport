//
//  PassportWidget.swift
//  PassportWidget
//
//  Created by George Clinkscales on 9/5/26.
//

import WidgetKit
import SwiftUI

// MARK: - Data bridge
// Reads the same UserDefaults key that GlobalProgressManager writes.
// Replace the suiteName with your actual App Group ID once you've set one up.

struct PassportProgress {
    let visitedCount: Int

    var percentString: String { "\(visitedCount) landmarks" }

    static func load() -> PassportProgress {
        // Use App Group defaults so widget and app share the same store.
        // Replace "group.com.yourname.stamped" with your App Group identifier.
        let defaults = UserDefaults(suiteName: "group.stamped.passport") ?? .standard
        let ids = (defaults.array(forKey: "GlobalVisitedBuildingsKey") as? [String]) ?? []
        return PassportProgress(visitedCount: ids.count)
    }
}

// MARK: - Timeline

struct PassportEntry: TimelineEntry {
    let date: Date
    let progress: PassportProgress
}

struct PassportProvider: TimelineProvider {
    func placeholder(in context: Context) -> PassportEntry {
        PassportEntry(date: .now, progress: PassportProgress(visitedCount: 12))
    }

    func getSnapshot(in context: Context, completion: @escaping (PassportEntry) -> Void) {
        completion(PassportEntry(date: .now, progress: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PassportEntry>) -> Void) {
        let entry = PassportEntry(date: .now, progress: .load())
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Widget

struct PassportWidget: Widget {
    let kind: String = "PassportWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PassportProvider()) { entry in
            PassportWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Passport Progress")
        .description("See how many landmarks you've discovered.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Views

struct PassportWidgetEntryView: View {
    var entry: PassportEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(spacing: 6) {
            Image(systemName: "book.closed.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            Text("Stamped!")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text("\(entry.progress.visitedCount)")
                .font(.title.bold())
            Text("landmarks")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var mediumView: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "book.closed.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Stamped!")
                    .font(.headline.bold())
                Text("City Passport")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(entry.progress.visitedCount)")
                    .font(.largeTitle.bold())
                Text("landmarks visited")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    PassportWidget()
} timeline: {
    PassportEntry(date: .now, progress: PassportProgress(visitedCount: 23))
}

#Preview(as: .systemMedium) {
    PassportWidget()
} timeline: {
    PassportEntry(date: .now, progress: PassportProgress(visitedCount: 23))
}
