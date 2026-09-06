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

    var priceString: String { "" }

    var ratingString: String { "" }

    var mapsURL: URL? {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "maps://?ll=\(latitude),\(longitude)&q=\(encoded)")
    }
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
            .restaurant, .cafe, .bakery, .brewery, .foodMarket, .nightlife
        ])

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()

            venues = response.mapItems.prefix(8).compactMap { item in
                guard let name = item.name else { return nil }
                // Use placemark coordinate (still the correct API on iOS)
                let lat = item.placemark.coordinate.latitude
                let lon = item.placemark.coordinate.longitude
                let category = item.pointOfInterestCategory.map { poiLabel($0) } ?? "Restaurant"
                return FoursquareVenue(
                    id: "\(name)-\(lat)-\(lon)",
                    name: name,
                    categoryName: category,
                    latitude: lat,
                    longitude: lon
                )
            }

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

    private func poiLabel(_ category: MKPointOfInterestCategory) -> String {
        switch category {
        case .restaurant:  return "Restaurant"
        case .cafe:        return "Café"
        case .bakery:      return "Bakery"
        case .brewery:     return "Brewery"
        case .foodMarket:  return "Market"
        case .nightlife:   return "Bar / Nightlife"
        default:           return "Dining"
        }
    }
}
