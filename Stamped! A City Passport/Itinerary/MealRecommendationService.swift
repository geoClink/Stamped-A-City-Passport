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

    // MARK: - Cache

    private func cacheKey(for city: String) -> String {
        "meals_\(city.lowercased().replacingOccurrences(of: " ", with: "_"))"
    }

    private func loadCache(for city: String) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(for: city)),
              let decoded = try? JSONDecoder().decode([Int: DayMeals].self, from: data),
              !decoded.isEmpty
        else { return false }
        mealsByDay = decoded
        return true
    }

    private func saveCache(for city: String) {
        guard let data = try? JSONEncoder().encode(mealsByDay) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(for: city))
    }

    func clearCache(for city: String) {
        UserDefaults.standard.removeObject(forKey: cacheKey(for: city))
        mealsByDay = [:]
    }

    // MARK: - Public entry point

    func generateMeals(for itinerary: [[PlannedStop]], buildings: [Building], cityKey: String) async {
        guard !isLoading else { return }
        if loadCache(for: cityKey) { return }

        isLoading = true
        defer { isLoading = false }

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

        saveCache(for: cityKey)
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

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.prefix(limit).compactMap { item in
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
