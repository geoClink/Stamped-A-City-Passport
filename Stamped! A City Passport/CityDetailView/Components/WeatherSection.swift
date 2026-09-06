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
        VStack(alignment: .leading, spacing: 12) {
            Label("WEATHER", systemImage: "cloud.sun.fill")
                .font(.system(.caption, design: .default))
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .kerning(1.2)
                .padding(.horizontal)

            if weather.isLoading {
                HStack(spacing: 10) {
                    ProgressView().scaleEffect(0.7)
                    Text("Fetching weather…")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding(.horizontal)
            } else if weather.failed || weather.temperature.isEmpty {
                ContentUnavailableView(
                    "Weather Unavailable",
                    systemImage: "exclamationmark.triangle.fill",
                    description: Text("Could not load weather for this city.")
                )
                .padding(.horizontal)
            } else {
                // One card that holds current conditions + forecast strip
                VStack(alignment: .leading, spacing: 0) {

                    // Current conditions row
                    HStack(spacing: 12) {
                        Image(systemName: weather.symbolName)
                            .font(.system(size: weatherIconSize))
                            .symbolRenderingMode(.multicolor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(weather.temperature)
                                .font(.title).fontWeight(.bold).foregroundColor(.primary)
                            Text(weather.conditionDescription)
                                .font(.subheadline).foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Current weather: \(weather.temperature), \(weather.conditionDescription)")

                    // Divider between current and forecast
                    if !weather.forecast.isEmpty {
                        Divider()
                            .padding(.horizontal, 16)

                        // Forecast — fixed-width cells in a scroll view
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                ForEach(weather.forecast) { day in
                                    ForecastDayCell(day: day, brandColor: brandColor)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 8)
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)

                Text("Weather data from Open-Meteo. Stamped is not responsible for forecast inaccuracies.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - Single Forecast Day

private struct ForecastDayCell: View {
    let day: DayForecast
    let brandColor: Color

    @ScaledMetric(relativeTo: .caption) private var forecastIconSize: CGFloat = 22

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: day.date)
    }

    var body: some View {
        VStack(spacing: 5) {
            Text(dayLabel)
                .font(.caption2).fontWeight(.medium).foregroundColor(.secondary)
            Image(systemName: day.symbolName)
                .font(.system(size: forecastIconSize))
                .symbolRenderingMode(.multicolor)
            Text(day.high)
                .font(.caption).fontWeight(.semibold).foregroundColor(.primary)
            Text(day.low)
                .font(.caption2).foregroundColor(.secondary)
        }
        .frame(width: 64) // fixed width so ScrollView can compute content size
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dayLabel), high \(day.high), low \(day.low)")
    }
}
