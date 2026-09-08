import Foundation
import SwiftUI

struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    let category: Category
    private let _check: (GlobalProgressManager, [CityLocation.City]) -> Bool

    enum Category: String, CaseIterable, Identifiable {
        case all = "All"
        case landmarks = "Landmarks"
        case cities = "Cities"
        case mastery = "Mastery"
        case continents = "Continents"
        var id: String { rawValue }
        var systemIcon: String {
            switch self {
            case .all: return "star"
            case .landmarks: return "building.columns"
            case .cities: return "map"
            case .mastery: return "checkmark.seal"
            case .continents: return "globe"
            }
        }
    }

    init(id: String, title: String, description: String, icon: String, color: Color, category: Category,
         check: @escaping (GlobalProgressManager, [CityLocation.City]) -> Bool) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.color = color
        self.category = category
        self._check = check
    }

    func isEarned(manager: GlobalProgressManager, cities: [CityLocation.City]) -> Bool {
        _check(manager, cities)
    }
}

// MARK: - All Achievements
extension Achievement {
    static let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    static let allAchievements: [Achievement] = [

        // MARK: Landmarks
        Achievement(id: "first_stamp", title: "First Stamp",
                    description: "Visit your very first landmark",
                    icon: "trophy.fill", color: gold, category: .landmarks) { m, _ in
            m.visitedIDs.count >= 1
        },
        Achievement(id: "on_the_move", title: "On The Move",
                    description: "Visit 10 landmarks",
                    icon: "figure.walk", color: .green, category: .landmarks) { m, _ in
            m.visitedIDs.count >= 10
        },
        Achievement(id: "passport_regular", title: "Passport Regular",
                    description: "Visit 50 landmarks",
                    icon: "star.fill", color: .blue, category: .landmarks) { m, _ in
            m.visitedIDs.count >= 50
        },
        Achievement(id: "century_club", title: "Century Club",
                    description: "Visit 100 landmarks",
                    icon: "seal.fill", color: .purple, category: .landmarks) { m, _ in
            m.visitedIDs.count >= 100
        },
        Achievement(id: "night_stamper", title: "Night Stamper",
                    description: "Stamp a landmark between midnight and 5am",
                    icon: "moon.stars.fill", color: .indigo, category: .landmarks) { m, _ in
            m.visitDates.values.contains { Calendar.current.component(.hour, from: $0) < 5 }
        },
        Achievement(id: "weekend_wanderer", title: "Weekend Wanderer",
                    description: "Stamp a landmark on a Saturday or Sunday",
                    icon: "sun.max.fill", color: .orange, category: .landmarks) { m, _ in
            m.visitDates.values.contains {
                let w = Calendar.current.component(.weekday, from: $0)
                return w == 1 || w == 7
            }
        },

        // MARK: Cities
        Achievement(id: "first_destination", title: "First Destination",
                    description: "Stamp a landmark in any city",
                    icon: "mappin.fill", color: .red, category: .cities) { m, cities in
            cities.contains { $0.buildings.contains { m.visitedIDs.contains($0.id) } }
        },
        Achievement(id: "multi_city", title: "Multi-City",
                    description: "Stamp landmarks in 5 different cities",
                    icon: "map.fill", color: .teal, category: .cities) { m, cities in
            cities.filter { $0.buildings.contains { m.visitedIDs.contains($0.id) } }.count >= 5
        },
        Achievement(id: "jet_setter", title: "Jet Setter",
                    description: "Stamp landmarks in 15 different cities",
                    icon: "airplane", color: .adventureOrange, category: .cities) { m, cities in
            cities.filter { $0.buildings.contains { m.visitedIDs.contains($0.id) } }.count >= 15
        },
        Achievement(id: "world_traveler", title: "World Traveler",
                    description: "Stamp landmarks in 30 different cities",
                    icon: "globe.americas.fill", color: .indigo, category: .cities) { m, cities in
            cities.filter { $0.buildings.contains { m.visitedIDs.contains($0.id) } }.count >= 30
        },

        // MARK: Mastery
        Achievement(id: "completionist", title: "Completionist",
                    description: "Collect every stamp in a single city",
                    icon: "checkmark.seal.fill", color: .green, category: .mastery) { m, cities in
            cities.contains { m.isCityComplete($0) }
        },
        Achievement(id: "triple_crown", title: "Triple Crown",
                    description: "Fully complete 3 cities",
                    icon: "crown.fill", color: gold, category: .mastery) { m, cities in
            cities.filter { m.isCityComplete($0) }.count >= 3
        },
        Achievement(id: "city_master", title: "City Master",
                    description: "Fully complete 10 cities",
                    icon: "rosette", color: .purple, category: .mastery) { m, cities in
            cities.filter { m.isCityComplete($0) }.count >= 10
        },

        // MARK: Continents
        Achievement(id: "bi_continental", title: "Bi-Continental",
                    description: "Stamp landmarks on 2 different continents",
                    icon: "globe", color: .teal, category: .continents) { m, cities in
            Set(cities.filter { $0.buildings.contains { m.visitedIDs.contains($0.id) } }
                .map { $0.country.continent }).count >= 2
        },
        Achievement(id: "old_world", title: "Old World",
                    description: "Stamp landmarks in both Europe and Asia",
                    icon: "building.columns.fill", color: .brown, category: .continents) { m, cities in
            let c = Set(cities.filter { $0.buildings.contains { m.visitedIDs.contains($0.id) } }
                .map { $0.country.continent })
            return c.contains(.europe) && c.contains(.asia)
        },
        Achievement(id: "world_citizen", title: "World Citizen",
                    description: "Stamp landmarks on 4 different continents",
                    icon: "globe.europe.africa.fill", color: .blue, category: .continents) { m, cities in
            Set(cities.filter { $0.buildings.contains { m.visitedIDs.contains($0.id) } }
                .map { $0.country.continent }).count >= 4
        },
    ]
}
