//
//  WeatherSection.swift
//  Stamped! A City Passport
//

import SwiftUI

// MARK: - Weather Section

struct WeatherSection: View {
    @ObservedObject var weather: WeatherManager
    let isHighContrast: Bool
    var brandColor: Color { isHighContrast ? .primary : Color.adventureOrange }

    @ScaledMetric(relativeTo: .title2) private var weatherIconSize: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader("Weather", systemImage: "cloud.sun.fill", isHighContrast: isHighContrast)
                .dsPageMargin()

            // One card that holds current conditions + forecast strip (or the loading/failed state)
            VStack(alignment: .leading, spacing: 0) {
                if weather.isLoading {
                    HStack(spacing: DS.Space.s) {
                        ProgressView().scaleEffect(0.7)
                        Text("Fetching weather…")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(DS.Space.l)
                } else if weather.failed || weather.temperature.isEmpty {
                    ContentUnavailableView(
                        "Weather Unavailable",
                        systemImage: "exclamationmark.triangle.fill",
                        description: Text("Could not load weather for this city.")
                    )
                    .padding(DS.Space.l)
                } else {
                    // Current conditions row
                    HStack(spacing: DS.Space.m) {
                        Image(systemName: weather.symbolName)
                            .font(.system(size: weatherIconSize))
                            .weatherSymbolStyle(weather.symbolName)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(weather.temperature)
                                .font(.title).fontWeight(.bold).foregroundColor(.primary)
                            Text(weather.conditionDescription)
                                .font(.subheadline).foregroundColor(isHighContrast ? .primary : .secondary)
                        }

                        Spacer()
                    }
                    .padding(DS.Space.l)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Current weather: \(weather.temperature), \(weather.conditionDescription)")

                    // Divider between current and forecast
                    if !weather.forecast.isEmpty {
                        Divider()
                            .padding(.horizontal, DS.Space.l)

                        // Forecast — fixed-width cells in a scroll view, edge to edge inside the card
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                ForEach(weather.forecast) { day in
                                    ForecastDayCell(day: day, brandColor: brandColor)
                                }
                            }
                            .padding(.vertical, DS.Space.m)
                            .padding(.horizontal, DS.Space.s)
                        }
                    }
                }
            }
            .dsCard(padding: 0, isHighContrast: isHighContrast)
            .dsPageMargin()

            if !weather.isLoading && !weather.failed && !weather.temperature.isEmpty {
                Text("Weather data from Open-Meteo. Stamped is not responsible for forecast inaccuracies.")
                    .font(.caption2)
                    .foregroundColor(isHighContrast ? .primary : .secondary)
                    .dsPageMargin()
            }
        }
    }
}

// MARK: - Single Forecast Day

private struct ForecastDayCell: View {
    let day: DayForecast
    let brandColor: Color

    @ScaledMetric(relativeTo: .caption) private var forecastIconSize: CGFloat = 22
    /// Fixed so the ScrollView can compute its content size, but scaled so the labels fit at large text sizes
    @ScaledMetric(relativeTo: .caption) private var cellWidth: CGFloat = 64

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: day.date)
    }

    var body: some View {
        VStack(spacing: DS.Space.xs) {
            Text(dayLabel)
                .font(.caption2).fontWeight(.medium).foregroundColor(.secondary)
                .lineLimit(1).minimumScaleFactor(0.8)
            Image(systemName: day.symbolName)
                .font(.system(size: forecastIconSize))
                .weatherSymbolStyle(day.symbolName)
            Text(day.high)
                .font(.caption).fontWeight(.semibold).foregroundColor(.primary)
            Text(day.low)
                .font(.caption2).foregroundColor(.secondary)
        }
        .frame(width: cellWidth)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dayLabel), high \(day.high), low \(day.low)")
    }
}

private extension View {
    /// Multicolor clouds are white, which vanishes on a light card, so cloud and fog
    /// symbols use gray layers; sun, moon and storm symbols keep their colors.
    @ViewBuilder
    func weatherSymbolStyle(_ symbolName: String) -> some View {
        if symbolName.contains("sun") || symbolName.contains("moon") || symbolName.contains("bolt") {
            symbolRenderingMode(.multicolor)
        } else {
            symbolRenderingMode(.hierarchical).foregroundStyle(.secondary)
        }
    }
}
