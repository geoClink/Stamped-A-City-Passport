//
//  FoursquareService.swift
//  Stamped! A City Passport
//
//  Fetches nearby restaurants using MKLocalSearch (Apple Maps data).
//  Free, no API key, works on all networks.
//  Ratings and price tiers are not available from MapKit — venue cards
//  show category and a tap-to-Maps action instead.
//

import Foundation
import CoreLocation
import MapKit
import Combine

// MARK: - Model

struct FoursquareVenue: Identifiable {
    let id: String
    let name: String
    let rating: Double? = nil
    let price: Int? = nil
    let categoryName: String
    let latitude: Double
    let longitude: Double
    /// The Apple Maps place itself, so a tap can open Apple's place card (photos, hours, ratings).
    let mapItem: MKMapItem
    /// Straight-line meters from the city's center, used to sort and to show "3 min walk".
    let distanceMeters: CLLocationDistance

    var priceString: String { "" }

    var ratingString: String { "" }
}

// MARK: - Service

@MainActor
final class FoursquareService: ObservableObject {
    static let shared = FoursquareService()

    @Published var venues: [FoursquareVenue] = []
    @Published var isLoading = false
    @Published var failed = false

    private var cachedCityName = ""
    private var cacheTimestamp: Date?
    private let cacheTTL: TimeInterval = 3600

    private init() {}

    func fetchTopEats(cityName: String, near coordinate: CLLocationCoordinate2D) async {
        if cachedCityName == cityName,
           let ts = cacheTimestamp,
           Date().timeIntervalSince(ts) < cacheTTL,
           !venues.isEmpty {
            return
        }

        isLoading = true
        failed = false

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "restaurant"
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 5000,
            longitudinalMeters: 5000
        )
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .restaurant, .cafe, .bakery, .brewery, .winery, .foodMarket, .nightlife
        ])

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()

            let topVenues = response.mapItems.prefix(8).compactMap { item -> FoursquareVenue? in
                guard let name = item.name else { return nil }
                let lat = item.displayCoordinate.latitude
                let lon = item.displayCoordinate.longitude
                return FoursquareVenue(
                    id: "\(name)-\(lat)-\(lon)",
                    name: name,
                    categoryName: DiningPlaceLabel.category(for: item),
                    latitude: lat,
                    longitude: lon,
                    mapItem: item,
                    distanceMeters: DiningPlaceLabel.distance(from: coordinate, to: item)
                )
            }
            // Nearest first, so the list reads like a walk out from the center.
            venues = topVenues.sorted { $0.distanceMeters < $1.distanceMeters }

            cachedCityName = cityName
            cacheTimestamp = Date()
            print("[NearbyEats] ✅ Loaded \(venues.count) venues for \(cityName) via MapKit")
        } catch {
            failed = true
            print("[NearbyEats] ❌ MKLocalSearch error: \(error)")
        }

        isLoading = false
    }

    func fetchTopEats(cityName: String, buildings: [Building]) async {
        let coords = buildings.compactMap { b -> CLLocationCoordinate2D? in
            guard let lat = b.latitude, let lon = b.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        guard !coords.isEmpty else { return }
        let lat = coords.map { $0.latitude }.reduce(0, +) / Double(coords.count)
        let lon = coords.map { $0.longitude }.reduce(0, +) / Double(coords.count)
        await fetchTopEats(cityName: cityName, near: CLLocationCoordinate2D(latitude: lat, longitude: lon))
    }
}

// MARK: - Shared labels

/// Labels for a dining place from Apple Maps, shared by the city page ("Nearby Dining")
/// and the building page ("Local Flavors") so both read the same way.
enum DiningPlaceLabel {
    /// Average walking speed in meters per second (about 4.7 km/h).
    private static let walkingSpeed: Double = 1.3
    /// Past this many minutes, show a distance ("1.2 km") instead of a walk time.
    private static let maxWalkMinutes = 20

    /// A short, translated category, e.g. "Café" or "Bakery".
    static func category(for item: MKMapItem) -> String {
        switch item.pointOfInterestCategory {
        case .cafe:       return String(localized: "dining.cafe")
        case .bakery:     return String(localized: "dining.bakery")
        case .brewery:    return String(localized: "dining.brewery")
        case .winery:     return String(localized: "dining.winery")
        case .foodMarket: return String(localized: "dining.market")
        // MapKit has no separate "bar" category; nightlife covers bars and clubs.
        case .nightlife:  return String(localized: "dining.bar")
        default:          return String(localized: "dining.restaurant")
        }
    }

    /// Straight-line meters between a point and the place (no routing call, so it's free and instant).
    static func distance(from origin: CLLocationCoordinate2D, to item: MKMapItem) -> CLLocationDistance {
        let start = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let place = CLLocation(latitude: item.displayCoordinate.latitude, longitude: item.displayCoordinate.longitude)
        return start.distance(from: place)
    }

    /// "4 min walk" for close places, otherwise "1.2 km" or "0.8 mi" depending on the units setting.
    static func distanceText(meters: CLLocationDistance, useMetric: Bool) -> String {
        // Round up so we never promise a shorter walk than it is, with 1 min as the floor.
        let minutes = max(1, Int((meters / walkingSpeed / 60).rounded(.up)))
        if minutes <= maxWalkMinutes {
            // Localizable.stringsdict handles plurals ("1 min walk", "徒歩5分").
            return String.localizedStringWithFormat(NSLocalizedString("dining.minWalk", comment: "Walk time to a restaurant"), minutes)
        }

        let measurement = Measurement(value: meters, unit: UnitLength.meters)
            .converted(to: useMetric ? .kilometers : .miles)
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter.string(from: measurement)
    }
}
