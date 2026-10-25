//
//  WeatherManager.swift
//  Stamped! A City Passport
//
//  Uses Apple WeatherKit to fetch current conditions and a 7-day forecast
//  keyed by building centroid.
//  Requires the WeatherKit entitlement, and WeatherKit enabled for the app ID
//  under both Capabilities and App Services in the Apple Developer portal.
//

import Foundation
import CoreLocation
import Combine
import WeatherKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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
    /// True when WeatherKit rejected the request because the app isn't authorized
    /// (missing entitlement, or WeatherKit not enabled for the app ID in the developer portal).
    @Published var notAuthorized = false
    /// Apple Weather mark and legal link — required wherever WeatherKit data is shown.
    @Published var attribution: WeatherAttribution?

    /// Debug builds surface the setup error in the city view so a missing capability is easy to spot.
    var showsSetupError: Bool {
        #if DEBUG
        return notAuthorized
        #else
        return false
        #endif
    }

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
        notAuthorized = false

        // Respect device locale for temperature unit
        let useFahrenheit = Locale.current.measurementSystem == .us
        let unit: UnitTemperature = useFahrenheit ? .fahrenheit : .celsius
        let suffix = useFahrenheit ? "°F" : "°C"
        func format(_ t: Measurement<UnitTemperature>) -> String {
            "\(Int(t.converted(to: unit).value.rounded()))\(suffix)"
        }

        do {
            let service = WeatherService.shared
            let (current, daily) = try await service.weather(
                for: CLLocation(latitude: lat, longitude: lon),
                including: .current, .daily
            )
            if attribution == nil {
                attribution = try? await service.attribution
            }

            temperature = format(current.temperature)
            symbolName = filledSymbol(current.symbolName)
            conditionDescription = current.condition.description
            isDaylight = current.isDaylight

            forecast = daily.forecast.prefix(7).map { day in
                DayForecast(
                    date: displayDate(for: day.date, longitude: lon),
                    high: format(day.highTemperature),
                    low: format(day.lowTemperature),
                    symbolName: filledSymbol(day.symbolName),
                    conditionDescription: day.condition.description
                )
            }

            cachedCityName = cityName
            cacheTimestamp = Date()
            print("[Weather] ✅ \(cityName): \(temperature), \(conditionDescription)")

        } catch {
            failed = true
            if Self.isAuthorizationError(error) {
                notAuthorized = true
                print("""
                [Weather] ❌ WeatherKit is not authorized for this app (\(error)).
                [Weather]    Check: the WeatherKit entitlement is in the build, and WeatherKit is enabled
                [Weather]    for \(Bundle.main.bundleIdentifier ?? "this app ID") under BOTH Capabilities and
                [Weather]    App Services in Certificates, Identifiers & Profiles. It can take ~30 min to activate.
                """)
            } else {
                print("[Weather] Error: \(error)")
            }
        }

        isLoading = false
    }

    // MARK: - Helpers

    /// WeatherKit's JWT/auth failures surface as WeatherError.permissionDenied or as an
    /// opaque WeatherDaemon "WDSJWTAuthenticatorServiceListener" error.
    private static func isAuthorizationError(_ error: Error) -> Bool {
        if let weatherError = error as? WeatherError, case .permissionDenied = weatherError { return true }
        let text = "\((error as NSError).domain) \(String(reflecting: error))"
        return text.contains("JWTAuthenticator")
    }

    /// WeatherKit returns outline symbols ("cloud.sun"); prefer the filled variant when one exists.
    private func filledSymbol(_ name: String) -> String {
        let filled = name.hasSuffix(".fill") ? name : name + ".fill"
        #if canImport(UIKit)
        return UIImage(systemName: filled) != nil ? filled : name
        #elseif canImport(AppKit)
        return NSImage(systemSymbolName: filled, accessibilityDescription: nil) != nil ? filled : name
        #else
        return name
        #endif
    }

    /// A forecast day's date is midnight in the city's time zone, which can fall on the
    /// previous weekday in the device's time zone. Read the city's calendar day using a
    /// longitude-based offset (city noon stays on the same day), then rebuild it as noon
    /// on that day in the device's calendar so the weekday label is right.
    private func displayDate(for date: Date, longitude: Double) -> Date {
        var cityCalendar = Calendar(identifier: .gregorian)
        cityCalendar.timeZone = TimeZone(secondsFromGMT: Int(longitude / 15 * 3600)) ?? .current
        var parts = cityCalendar.dateComponents([.year, .month, .day], from: date.addingTimeInterval(12 * 3600))
        parts.hour = 12
        return Calendar.current.date(from: parts) ?? date
    }
}
