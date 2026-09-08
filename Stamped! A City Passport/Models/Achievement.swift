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
        Achievement(id: "around_the_world", title: "Around The World",
                    description: "Stamp landmarks on all 6 continents",
                    icon: "globe.americas.fill", color: .indigo, category: .continents) { m, cities in
            let visited = Set(cities.filter { $0.buildings.contains { m.visitedIDs.contains($0.id) } }
                .map { $0.country.continent })
            return CityLocation.Continent.allCases.allSatisfy { visited.contains($0) }
        },
        Achievement(id: "continent_conqueror", title: "Continent Conqueror",
                    description: "Fully complete a city on every continent",
                    icon: "flag.checkered.2.crossed", color: gold, category: .continents) { m, cities in
            let completedContinents = Set(cities.filter { m.isCityComplete($0) }.map { $0.country.continent })
            return CityLocation.Continent.allCases.allSatisfy { completedContinents.contains($0) }
        },

        // MARK: Landmarks — Extra
        Achievement(id: "early_bird", title: "Early Bird",
                    description: "Stamp a landmark before 8am",
                    icon: "sunrise.fill", color: .yellow, category: .landmarks) { m, _ in
            m.visitDates.values.contains { Calendar.current.component(.hour, from: $0) < 8 }
        },
        Achievement(id: "frequent_flyer", title: "Frequent Flyer",
                    description: "Stamp 5 landmarks in a single day",
                    icon: "airplane.departure", color: .cyan, category: .landmarks) { m, _ in
            let grouped = Dictionary(grouping: m.visitDates.values) {
                Calendar.current.startOfDay(for: $0)
            }
            return grouped.values.contains { $0.count >= 5 }
        },
        Achievement(id: "seasoned_traveler", title: "Seasoned Traveler",
                    description: "Stamp landmarks across 3 different calendar months",
                    icon: "calendar", color: .mint, category: .landmarks) { m, _ in
            Set(m.visitDates.values.map { Calendar.current.component(.month, from: $0) }).count >= 3
        },
        Achievement(id: "new_year_stamp", title: "New Year's Stamp",
                    description: "Stamp a landmark on January 1st",
                    icon: "party.popper.fill", color: .pink, category: .landmarks) { m, _ in
            m.visitDates.values.contains {
                let cal = Calendar.current
                return cal.component(.month, from: $0) == 1 && cal.component(.day, from: $0) == 1
            }
        },
        Achievement(id: "birthday_stamp", title: "Birthday Stamp",
                    description: "Stamp a landmark on your birthday",
                    icon: "gift.fill", color: .pink, category: .landmarks) { m, _ in
            let ts = UserDefaults.standard.double(forKey: "birthdayTimestamp")
            guard ts > 0 else { return false }
            let bday = Date(timeIntervalSince1970: ts)
            let cal = Calendar.current
            let bMonth = cal.component(.month, from: bday)
            let bDay = cal.component(.day, from: bday)
            return m.visitDates.values.contains {
                cal.component(.month, from: $0) == bMonth && cal.component(.day, from: $0) == bDay
            }
        },

        // MARK: Cities — Extra
        Achievement(id: "home_turf", title: "Home Turf",
                    description: "Fully complete any US city",
                    icon: "house.fill", color: .blue, category: .cities) { m, cities in
            cities.filter { $0.country == .unitedStates }.contains { m.isCityComplete($0) }
        },
        Achievement(id: "island_hopper", title: "Island Hopper",
                    description: "Stamp landmarks in Honolulu, Bali, and Zanzibar",
                    icon: "beach.umbrella.fill", color: .teal, category: .cities) { m, _ in
            let islands: [CityLocation.City] = [.honolulu, .bali, .zanzibar]
            return islands.allSatisfy { city in
                city.buildings.contains { m.visitedIDs.contains($0.id) }
            }
        },

        // MARK: Mastery — Extra
        Achievement(id: "halfway_there", title: "Halfway There",
                    description: "Reach 50% completion in any city",
                    icon: "chart.pie.fill", color: .orange, category: .mastery) { m, cities in
            cities.contains { city in
                let total = city.buildings.count
                guard total > 0 else { return false }
                let visited = city.buildings.filter { m.visitedIDs.contains($0.id) }.count
                return visited > 0 && Double(visited) / Double(total) >= 0.5
            }
        },
        Achievement(id: "grand_slam", title: "Grand Slam",
                    description: "Fully complete 25 cities",
                    icon: "trophy.circle.fill", color: gold, category: .mastery) { m, cities in
            cities.filter { m.isCityComplete($0) }.count >= 25
        },
        Achievement(id: "legend", title: "Legend",
                    description: "Collect 500 total stamps",
                    icon: "star.circle.fill", color: .purple, category: .mastery) { m, _ in
            m.visitedIDs.count >= 500
        },
    ]
}
