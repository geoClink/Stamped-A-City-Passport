//
//  WeatherManager.swift
//  Stamped! A City Passport
//
//  Uses Open-Meteo (free, no API key, global coverage) to fetch current
//  conditions and a 3-day forecast keyed by building centroid.
//  Replaces WeatherKit — no entitlement or provisioning required.
//

import Foundation
import CoreLocation
import Combine

struct DayForecast: Identifiable {
    let id = UUID()
    let date: Date
    let high: String
    let low: String
    let symbolName: String
    let conditionDescription: String
}

@MainActor
final class WeatherManager: ObservableObject {
    static let shared = WeatherManager()

    @Published var temperature: String = ""
    @Published var symbolName: String = ""
    @Published var conditionDescription: String = ""
    @Published var isDaylight: Bool = true
    @Published var forecast: [DayForecast] = []
    @Published var isLoading = false
    @Published var failed = false

    private var cachedCityName = ""
    private var cacheTimestamp: Date?
    private let cacheTTL: TimeInterval = 1800

    private init() {}

    func fetchWeather(cityName: String, buildings: [Building]) async {
        if cachedCityName == cityName,
           let ts = cacheTimestamp,
           Date().timeIntervalSince(ts) < cacheTTL,
           !temperature.isEmpty { return }

        let coords = buildings.compactMap { b -> CLLocationCoordinate2D? in
            guard let lat = b.latitude, let lon = b.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        guard !coords.isEmpty else { return }

        let lat = coords.map { $0.latitude }.reduce(0, +) / Double(coords.count)
        let lon = coords.map { $0.longitude }.reduce(0, +) / Double(coords.count)

        isLoading = true
        failed = false

        // Respect device locale for temperature unit
        let useFahrenheit = Locale.current.measurementSystem == .us
        let unit = useFahrenheit ? "fahrenheit" : "celsius"
        let suffix = useFahrenheit ? "°F" : "°C"

        let urlString = "https://api.open-meteo.com/v1/forecast" +
            "?latitude=\(lat)&longitude=\(lon)" +
            "&current=temperature_2m,weather_code,is_day" +
            "&daily=weather_code,temperature_2m_max,temperature_2m_min" +
            "&temperature_unit=\(unit)" +
            "&timezone=auto&forecast_days=8"

        guard let url = URL(string: urlString) else { isLoading = false; return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                failed = true; isLoading = false; return
            }

            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

            let code = decoded.current.weather_code
            let isDay = decoded.current.is_day == 1

            temperature = "\(Int(decoded.current.temperature_2m.rounded()))\(suffix)"
            symbolName = wmoSymbol(code: code, isDay: isDay)
            conditionDescription = wmoDescription(code: code)
            isDaylight = isDay

            let parser = DateFormatter()
            parser.dateFormat = "yyyy-MM-dd"

            forecast = zip(decoded.daily.time, zip(decoded.daily.weather_code,
                           zip(decoded.daily.temperature_2m_max, decoded.daily.temperature_2m_min)))
                .prefix(7)
                .compactMap { (dateStr, rest) in
                    let (wCode, (high, low)) = rest
                    guard let date = parser.date(from: dateStr) else { return nil }
                    return DayForecast(
                        date: date,
                        high: "\(Int(high.rounded()))\(suffix)",
                        low: "\(Int(low.rounded()))\(suffix)",
                        symbolName: wmoSymbol(code: wCode, isDay: true),
                        conditionDescription: wmoDescription(code: wCode)
                    )
                }

            cachedCityName = cityName
            cacheTimestamp = Date()
            print("[Weather] ✅ \(cityName): \(temperature), \(conditionDescription)")

        } catch {
            failed = true
            print("[Weather] Error: \(error)")
        }

        isLoading = false
    }

    // MARK: - WMO code → SF Symbol

    private func wmoSymbol(code: Int, isDay: Bool) -> String {
        switch code {
        case 0, 1:       return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 2:          return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3:          return "cloud.fill"
        case 45, 48:     return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57:     return "cloud.sleet.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 66, 67:     return "cloud.sleet.fill"
        case 71, 73, 75, 77: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86:     return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default:         return "cloud.fill"
        }
    }

    private func wmoDescription(code: Int) -> String {
        switch code {
        case 0:          return "Clear Sky"
        case 1:          return "Mainly Clear"
        case 2:          return "Partly Cloudy"
        case 3:          return "Overcast"
        case 45, 48:     return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 56, 57:     return "Freezing Drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67:     return "Freezing Rain"
        case 71, 73, 75: return "Snow"
        case 77:         return "Snow Grains"
        case 80, 81, 82: return "Rain Showers"
        case 85, 86:     return "Snow Showers"
        case 95:         return "Thunderstorm"
        case 96, 99:     return "Thunderstorm with Hail"
        default:         return "Cloudy"
        }
    }
}

// MARK: - Open-Meteo response shapes

private struct OpenMeteoResponse: Codable {
    let current: OMCurrent
    let daily: OMDaily
}

private struct OMCurrent: Codable {
    let temperature_2m: Double
    let weather_code: Int
    let is_day: Int
}

private struct OMDaily: Codable {
    let time: [String]
    let weather_code: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
}
