import Foundation
import SwiftUI
import Combine

// MARK: - Itinerary cache keys
private func cacheKey(for city: String) -> String {
    "itinerary_cache_\(city.lowercased().replacingOccurrences(of: " ", with: "_"))"
}
private func visitedFingerprintKey(for city: String) -> String {
    "itinerary_visited_count_\(city.lowercased().replacingOccurrences(of: " ", with: "_"))"
}
 
@MainActor
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
        guard state != .loading else { return } // Prevent duplicate in-flight calls
 
        let cityBuildings = BuildingRegistry.getAllBuildings(forCityName: city)
        guard !cityBuildings.isEmpty else {
            state = .error("No buildings found for \(city)")
            return
        }

        // Check cache — auto-invalidates if visited count has changed since last generation
        if let cached = loadCachedItinerary(for: city, cityBuildings: cityBuildings) {
            buildings = cityBuildings
            itinerary = cached
            state = .loaded
            print("✅ Loaded itinerary from cache for \(city)")
            return
        }

        state = .loading
        buildings = cityBuildings

        let planned = ItineraryPlanner.planCity(
            buildings: cityBuildings,
            days: days,
            visitedIDs: GlobalProgressManager.shared.visitedIDs
        )
        itinerary = planned
        state = .loaded

        cacheItinerary(planned, for: city, cityBuildings: cityBuildings)
        print("✅ Generated and cached itinerary for \(city) — \(planned.flatMap { $0 }.count) stops")
    }
 
    // MARK: - Cache read/write

    private func visitedCount(for cityBuildings: [Building]) -> Int {
        let visitedIDs = GlobalProgressManager.shared.visitedIDs
        return cityBuildings.filter { visitedIDs.contains($0.id) }.count
    }

    private func cacheItinerary(_ itinerary: [[PlannedStop]], for city: String, cityBuildings: [Building]) {
        guard let data = try? JSONEncoder().encode(itinerary) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(for: city))
        // Store how many buildings were visited when this itinerary was generated.
        // If that number changes the cache is stale and must regenerate.
        UserDefaults.standard.set(visitedCount(for: cityBuildings), forKey: visitedFingerprintKey(for: city))
    }

    private func loadCachedItinerary(for city: String, cityBuildings: [Building]) -> [[PlannedStop]]? {
        let storedFingerprint = UserDefaults.standard.integer(forKey: visitedFingerprintKey(for: city))
        guard storedFingerprint == visitedCount(for: cityBuildings) else {
            // Visited set has changed — bust the cache so the new itinerary skips newly-visited buildings
            UserDefaults.standard.removeObject(forKey: cacheKey(for: city))
            return nil
        }
        guard let data = UserDefaults.standard.data(forKey: cacheKey(for: city)),
              let decoded = try? JSONDecoder().decode([[PlannedStop]].self, from: data)
        else { return nil }
        return decoded
    }

    // MARK: - Clear cache for a city
    func clearCache(for city: String) {
        UserDefaults.standard.removeObject(forKey: cacheKey(for: city))
        UserDefaults.standard.removeObject(forKey: visitedFingerprintKey(for: city))
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
