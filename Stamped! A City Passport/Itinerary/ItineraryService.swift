import Foundation
import SwiftUI
import Combine
 
// MARK: - Singleton registry so JSON is only loaded once per app session
final class BuildingRegistryStore {
    static let shared = BuildingRegistryStore()
    private(set) var allBuildings: [String: [Building]] = [:]
 
    private init() {
        guard let url = Bundle.main.url(forResource: "BuildingRegistry", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [Building]].self, from: data)
        else {
            print("❌ BuildingRegistryStore: Failed to load BuildingRegistry.json")
            return
        }
        allBuildings = decoded
        print("✅ BuildingRegistryStore: Loaded \(decoded.keys.count) cities")
    }
 
    func buildings(for city: String) -> [Building]? {
        allBuildings[city]
    }
}
 
// MARK: - Itinerary cache key
private func cacheKey(for city: String) -> String {
    "itinerary_cache_\(city.lowercased().replacingOccurrences(of: " ", with: "_"))"
}
 
final class ItineraryService: ObservableObject {
    @Published var itinerary: [[PlannedStop]] = []
    @Published var buildings: [Building] = []
    @Published var state: LoadState = .idle
 
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }
 
    // MARK: - Generate Itinerary for a City
    func generateItinerary(for city: String, days: Int = 3) {
        guard state == .idle else { return } // Prevent double calls
 
        // Check cache first
        if let cached = loadCachedItinerary(for: city) {
            guard let cityBuildings = BuildingRegistryStore.shared.buildings(for: city) else { return }
            buildings = cityBuildings
            itinerary = cached
            state = .loaded
            print("✅ Loaded itinerary from cache for \(city)")
            return
        }
 
        state = .loading
 
        guard let cityBuildings = BuildingRegistryStore.shared.buildings(for: city),
              !cityBuildings.isEmpty else {
            state = .error("No buildings found for \(city)")
            print("❌ No buildings found for \(city)")
            return
        }
 
        buildings = cityBuildings
        let planned = ItineraryPlanner.planCity(buildings: cityBuildings, days: days)
        itinerary = planned
        state = .loaded
 
        // Cache the result
        cacheItinerary(planned, for: city)
        print("✅ Generated and cached itinerary for \(city) — \(planned.flatMap { $0 }.count) stops")
    }
 
    // MARK: - Cache read/write
    private func cacheItinerary(_ itinerary: [[PlannedStop]], for city: String) {
        guard let data = try? JSONEncoder().encode(itinerary) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(for: city))
    }
 
    private func loadCachedItinerary(for city: String) -> [[PlannedStop]]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(for: city)),
              let decoded = try? JSONDecoder().decode([[PlannedStop]].self, from: data)
        else { return nil }
        return decoded
    }
 
    // MARK: - Clear cache for a city (call if buildings data updates)
    func clearCache(for city: String) {
        UserDefaults.standard.removeObject(forKey: cacheKey(for: city))
        state = .idle
    }
 
    // MARK: - Helpers
    func building(for stop: PlannedStop) -> Building? {
        buildings.first { $0.id == stop.buildingID }
    }
 
    func formattedArrivalTime(offsetMins: Int, startHour: Int = 9) -> String {
        let totalMins = startHour * 60 + offsetMins
        let hour = (totalMins / 60) % 24
        let min = totalMins % 60
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return String(format: "%d:%02d %@", displayHour, min, period)
    }
}
