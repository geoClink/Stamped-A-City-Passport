//
//  PassportWidget.swift
//  PassportWidget
//
//  Created by George Clinkscales on 9/5/26.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct PassportEntry: TimelineEntry {
    let date: Date
    let progress: PassportProgress
}

struct PassportProvider: TimelineProvider {
    func placeholder(in context: Context) -> PassportEntry {
        PassportEntry(date: .now, progress: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (PassportEntry) -> Void) {
        // The widget gallery shows sample stamps to someone who hasn't stamped anything yet
        let progress = PassportProgress.load()
        let shown = context.isPreview && progress.landmarkCount == 0 ? .sample : progress
        completion(PassportEntry(date: .now, progress: shown))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PassportEntry>) -> Void) {
        // The app reloads the widget after each stamp; the hourly refresh is only a backstop
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
        .description("Your stamps, cities and latest landmark at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Views

struct PassportWidgetEntryView: View {
    var entry: PassportEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemLarge:
                LargePassportView(progress: entry.progress)
            case .systemMedium:
                MediumPassportView(progress: entry.progress)
            default:
                SmallPassportView(progress: entry.progress)
            }
        }
        // A tap anywhere opens the latest stamp's city; with no stamps it just opens the app.
        // (The large size also links each row to its own city.)
        .widgetURL(entry.progress.latestStamp?.cityURL)
    }
}

/// Small: the latest stamp and how many landmarks are stamped.
struct SmallPassportView: View {
    let progress: PassportProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            StampBadge(cityName: progress.latestStamp?.cityName, size: 62)
            Spacer(minLength: 4)
            Text(progress.landmarkCount, format: .number)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
                .widgetAccentable()
            // Two strings, not a plural: a plural form has to show the number, and it's above
            Text(progress.landmarkCount == 1
                 ? LocalizedStringKey("landmark stamped")
                 : LocalizedStringKey("landmarks stamped"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Medium: the latest stamp, its city, and city and landmark totals.
struct MediumPassportView: View {
    let progress: PassportProgress

    var body: some View {
        HStack(spacing: 16) {
            StampBadge(cityName: progress.latestStamp?.cityName, size: 104)

            VStack(alignment: .leading, spacing: 4) {
                if let latest = progress.latestStamp {
                    Text("Latest stamp")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(latest.cityName)
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    StampDetailLine(stamp: latest)
                } else {
                    EmptyPassportMessage()
                }
                Spacer(minLength: 0)
                ProgressTotals(progress: progress)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Large: totals and the five most recent stamps, each linking to its city.
struct LargePassportView: View {
    let progress: PassportProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "Stamped!")
                        .font(.system(.title3, design: .serif, weight: .bold))
                    ProgressTotals(progress: progress)
                }
                Spacer()
                StampBadge(cityName: progress.latestStamp?.cityName, size: 64)
            }

            Divider()

            if progress.recentStamps.isEmpty {
                EmptyPassportMessage()
                Spacer(minLength: 0)
            } else {
                Text("Recent stamps")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                ForEach(progress.recentStamps, id: \.self) { stamp in
                    RecentStampRow(stamp: stamp)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Pieces

/// A round, dashed passport stamp with the city's name, tilted like it was stamped by hand.
/// With no city yet it shows an empty stamp outline.
struct StampBadge: View {
    let cityName: String?
    let size: CGFloat

    @Environment(\.widgetRenderingMode) private var renderingMode

    /// The app's orange in full color; in tinted or accented home screens the system
    /// recolors accentable views, so plain primary is enough there
    private var ink: Color {
        renderingMode == .fullColor ? Color("AccentColor") : .primary
    }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(ink, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
            Circle()
                .inset(by: size * 0.09)
                .strokeBorder(ink.opacity(0.6), lineWidth: 1)

            if let cityName {
                VStack(spacing: 1) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: size * 0.2))
                    Text(cityName.uppercased())
                        .font(.system(size: size * 0.13, weight: .heavy, design: .serif))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                }
                .foregroundStyle(ink)
                .padding(size * 0.17)
            } else {
                Image(systemName: "seal")
                    .font(.system(size: size * 0.3))
                    .foregroundStyle(ink.opacity(0.6))
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(-8))
        .widgetAccentable()
        .accessibilityHidden(cityName == nil)
        .accessibilityLabel(Text("Passport stamp for \(cityName ?? "")"))
    }
}

/// "7 cities · 42 landmarks"
struct ProgressTotals: View {
    let progress: PassportProgress

    var body: some View {
        HStack(spacing: 4) {
            Text("widget.cityCount \(progress.cityCount)")
            Text(verbatim: "·")
            Text("widget.landmarkCount \(progress.landmarkCount)")
        }
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

/// "Willis Tower · Nov 4"
struct StampDetailLine: View {
    let stamp: WidgetStamp

    var body: some View {
        HStack(spacing: 4) {
            Text(stamp.landmarkName)
                .lineLimit(1)
            if let date = stamp.date {
                Text(verbatim: "·")
                Text(date, format: .dateTime.month(.abbreviated).day())
                    .fixedSize()
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

struct RecentStampRow: View {
    let stamp: WidgetStamp

    var body: some View {
        // A Link inside a medium or large widget opens its own URL instead of the widget's
        if let url = stamp.cityURL {
            Link(destination: url) { RecentStampRowContent(stamp: stamp) }
        } else {
            RecentStampRowContent(stamp: stamp)
        }
    }
}

/// "✓ Willis Tower / Chicago · Nov 4"
struct RecentStampRowContent: View {
    let stamp: WidgetStamp

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(Color("AccentColor"))
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 1) {
                Text(stamp.landmarkName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(stamp.cityName)
                    if let date = stamp.date {
                        Text(verbatim: "·")
                        Text(date, format: .dateTime.month(.abbreviated).day())
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

struct EmptyPassportMessage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("No stamps yet")
                .font(.headline)
            Text("Stamp a landmark to start your passport.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    PassportWidget()
} timeline: {
    PassportEntry(date: .now, progress: .sample)
    PassportEntry(date: .now, progress: .empty)
}

#Preview("Medium", as: .systemMedium) {
    PassportWidget()
} timeline: {
    PassportEntry(date: .now, progress: .sample)
    PassportEntry(date: .now, progress: .empty)
}

#Preview("Large", as: .systemLarge) {
    PassportWidget()
} timeline: {
    PassportEntry(date: .now, progress: .sample)
    PassportEntry(date: .now, progress: .empty)
}
