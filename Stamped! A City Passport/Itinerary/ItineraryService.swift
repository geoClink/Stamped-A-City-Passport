import Foundation
import SwiftUI
import Combine

final class ItineraryService: ObservableObject {
    @Published var itinerary: [[PlannedStop]] = []
    @Published var buildings: [Building] = []

    private var allBuildings: [String: [Building]] = [:]

    init() {
        loadBuildings()
    }

    // MARK: - Load from local JSON

    private func loadBuildings() {
        guard let url = Bundle.main.url(forResource: "BuildingRegistry", withExtension: "json"),

              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [Building]].self, from: data)
        else {
            print("Failed to load buildings.json")
            return
        }
        allBuildings = decoded
    }

    // MARK: - Generate Itinerary for a City

    func generateItinerary(for city: String, days: Int = 3) {
        guard let cityBuildings = allBuildings[city], !cityBuildings.isEmpty else {
            print("No buildings found for \(city)")
            return
        }

        buildings = cityBuildings
        itinerary = ItineraryPlanner.planCity(
            buildings: cityBuildings,
            days: days
        )
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
