//
//  MealRecommendationService.swift
//  Stamped!
//
//  Uses MKLocalSearch to find real restaurant recommendations near each day's
//  itinerary stops. No API key required — pulls live Apple Maps data.
//

import Foundation
import MapKit
import Combine

// MARK: - Model

struct MealRecommendation: Identifiable, Codable {
    let id: String
    let name: String
    let category: String
    let mealType: MealType
    let latitude: Double
    let longitude: Double
    let websiteURL: String?
    let phoneNumber: String?

    enum MealType: String, Codable {
        case breakfast, lunch, dinner
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var mapsURL: URL? {
        // Deep-links into Apple Maps to the exact place
        var components = URLComponents(string: "maps://")!
        components.queryItems = [
            URLQueryItem(name: "q", value: name),
            URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
        ]
        return components.url
    }
}

// Recommendations for one day of the itinerary
struct DayMeals: Codable {
    let dayNumber: Int
    var breakfast: [MealRecommendation]
    var lunch: [MealRecommendation]
    var dinner: [MealRecommendation]
}

// MARK: - Service

@MainActor
final class MealRecommendationService: ObservableObject {
    @Published var mealsByDay: [Int: DayMeals] = [:]
    @Published var isLoading = false

    private let searchRadiusMeters: Double = 600
    /// A result farther than this from the stop is dropped. Apple Maps treats the search region
    /// as a hint and can answer with places near the device instead (Detroit restaurants on an
    /// Asheville plan when the phone was in Michigan).
    static let maxDistanceMeters: CLLocationDistance = 1500

    // MARK: - Cache

    /// What a saved plan's meals were found for, so they're only reused for the same stops
    private struct CachedMeals: Codable {
        let signature: String
        let mealsByDay: [Int: DayMeals]
    }

    /// v2: v1 was keyed by city alone, so it kept far-away results and reused meals after the
    /// itinerary changed. The new key drops those saved results.
    private func cacheKey(for city: String) -> String {
        "meals_v2_\(city.lowercased().replacingOccurrences(of: " ", with: "_"))"
    }

    /// The stops of every day, in order: "a,b|c,d"
    static func signature(of itinerary: [[PlannedStop]]) -> String {
        itinerary.map { $0.map(\.buildingID).joined(separator: ",") }.joined(separator: "|")
    }

    private func loadCache(for city: String, signature: String) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(for: city)),
              let decoded = try? JSONDecoder().decode(CachedMeals.self, from: data),
              decoded.signature == signature, !decoded.mealsByDay.isEmpty
        else { return false }
        mealsByDay = decoded.mealsByDay
        return true
    }

    private func saveCache(for city: String, signature: String) {
        guard let data = try? JSONEncoder().encode(CachedMeals(signature: signature, mealsByDay: mealsByDay)) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(for: city))
    }

    func clearCache(for city: String) {
        UserDefaults.standard.removeObject(forKey: cacheKey(for: city))
        mealsByDay = [:]
    }

    // MARK: - Public entry point

    func generateMeals(for itinerary: [[PlannedStop]], buildings: [Building], cityKey: String) async {
        guard !isLoading else { return }
        let signature = Self.signature(of: itinerary)
        if loadCache(for: cityKey, signature: signature) { return }

        isLoading = true
        defer { isLoading = false }
        // A new or changed plan: don't show the old plan's meals while searching
        mealsByDay = [:]

        for (dayIndex, stops) in itinerary.enumerated() {
            let dayBuildings = stops.compactMap { stop in buildings.first { $0.id == stop.buildingID } }
            guard !dayBuildings.isEmpty else { continue }

            let dayNumber = dayIndex + 1
            async let breakfast = search(near: dayBuildings.first!, mealType: .breakfast)
            async let lunch     = search(near: midday(of: dayBuildings), mealType: .lunch, limit: 5)
            async let dinner    = search(near: dayBuildings.last!, mealType: .dinner, limit: 5)

            let breakfastResult = await breakfast
            let lunchResult = await lunch
            let dinnerResult = await dinner

            // Remove dinner results that already appear in lunch so there's no overlap
            let lunchNames = Set(lunchResult.map { $0.name })
            let uniqueDinner = dinnerResult.filter { !lunchNames.contains($0.name) }

            mealsByDay[dayNumber] = DayMeals(
                dayNumber: dayNumber,
                breakfast: breakfastResult,
                lunch: Array(lunchResult.prefix(3)),
                dinner: Array((uniqueDinner.isEmpty ? dinnerResult : uniqueDinner).prefix(3))
            )
        }

        saveCache(for: cityKey, signature: signature)
    }

    // MARK: - Search

    private func search(near building: Building, mealType: MealRecommendation.MealType, limit: Int = 3) async -> [MealRecommendation] {
        guard let lat = building.latitude, let lon = building.longitude else { return [] }

        let query: String
        switch mealType {
        case .breakfast: query = "breakfast cafe"
        case .lunch:     query = "lunch bistro cafe"
        case .dinner:    query = "restaurant bar dining"
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            latitudinalMeters: searchRadiusMeters,
            longitudinalMeters: searchRadiusMeters
        )
        request.resultTypes = .pointOfInterest
        // Only places inside the region, not ones near wherever the device is
        request.regionPriority = .required
        let center = CLLocation(latitude: lat, longitude: lon)

        do {
            let response = try await MKLocalSearch(request: request).start()
            let nearby = response.mapItems.filter { item in
                let coordinate: CLLocationCoordinate2D
                if #available(iOS 26.0, macOS 26.0, *) {
                    coordinate = item.location.coordinate
                } else {
                    guard let loc = item.placemark.location else { return false }
                    coordinate = loc.coordinate
                }
                return Self.isNearby(coordinate, to: center)
            }
            return nearby.prefix(limit).compactMap { item in
                guard let name = item.name else { return nil }
                let coord: CLLocationCoordinate2D
                if #available(iOS 26.0, *) {
                    coord = item.location.coordinate
                } else {
                    guard let loc = item.placemark.location else { return nil }
                    coord = loc.coordinate
                }
                let itemLat = coord.latitude
                let itemLon = coord.longitude

                let category = item.pointOfInterestCategory.map { poiCategoryName($0) } ?? "Restaurant"

                return MealRecommendation(
                    id: "\(mealType.rawValue)_\(name)_\(dayKey(lat: itemLat, lon: itemLon))",
                    name: name,
                    category: category,
                    mealType: mealType,
                    latitude: itemLat,
                    longitude: itemLon,
                    websiteURL: item.url?.absoluteString,
                    phoneNumber: item.phoneNumber
                )
            }
        } catch {
            print("[MealRecommendationService] Search failed for \(mealType.rawValue) near \(building.name): \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Helpers

    /// True when a place is close enough to the stop to suggest for a meal there
    static func isNearby(_ coordinate: CLLocationCoordinate2D, to center: CLLocation) -> Bool {
        center.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) <= maxDistanceMeters
    }

    // Returns the building closest to the middle of the day's list
    private func midday(of buildings: [Building]) -> Building {
        buildings[buildings.count / 2]
    }

    private func dayKey(lat: Double, lon: Double) -> String {
        String(format: "%.4f_%.4f", lat, lon)
    }

    private func poiCategoryName(_ category: MKPointOfInterestCategory) -> String {
        switch category {
        case .bakery:       return "Bakery"
        case .cafe:         return "Café"
        case .restaurant:   return "Restaurant"
        case .brewery:      return "Brewery"
        case .winery:       return "Winery"
        case .foodMarket:   return "Food Market"
        default:            return "Restaurant"
        }
    }
}
