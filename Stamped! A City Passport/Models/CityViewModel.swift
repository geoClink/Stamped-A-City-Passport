//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/16/26.
//

import Combine
import Foundation
import SwiftUI

@MainActor
class CityViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var masteredCount: Int = 0
    @Published var totalCities: Int = 0
    @Published var searchText: String = ""
    
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    let allCities = CityLocation.City.allCases
    
    private let progressManager = GlobalProgressManager.shared
    
    init() {
        self.totalCities = allCities.count
        refreshData()
        
        progressManager.$visitedIDs
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Logic
    
    func refreshData() {
        self.masteredCount = allCities.filter { isCityCompleted($0) }.count
    }
    
    func isCityCompleted(_ city: CityLocation.City) -> Bool {
        let legacyComplete = UserDefaults.standard.bool(forKey: "completed_\(city.name)")
        
        let visitedCount = city.buildings.filter { progressManager.isVisited($0.id) }.count
        let isFullyVisited = visitedCount == city.buildings.count && !city.buildings.isEmpty
        
        return legacyComplete || isFullyVisited
    }
    
    // MARK: - Mastery Stats for Sidebar
    func masteryStats(for city: CityLocation.City) -> (tier: String, color: Color, progress: Double) {
        let stats = progressManager.getMastery(for: city.buildings)
        return (stats.tier, stats.color, stats.progress)
    }
    
    // MARK: - Sorted & Filtered Data
    
    var sortedCountries: [CityLocation.Country] {
        let matchingCities = allCities.filter { city in
            searchText.isEmpty || city.name.localizedCaseInsensitiveContains(searchText)
        }
        let countries = Set(matchingCities.map { $0.country })
        return Array(countries).sorted { $0.rawValue < $1.rawValue }
    }
    
    func filteredCities(for country: CityLocation.Country, query: String) -> [CityLocation.City] {
        allCities
            .filter { $0.country == country }
            .filter { city in
                query.isEmpty || city.name.localizedCaseInsensitiveContains(query)
            }
            .sorted { $0.name < $1.name }
    }
    
    func isCountryMastered(_ country: CityLocation.Country) -> Bool {
        let citiesInCountry = allCities.filter { $0.country == country }
        guard !citiesInCountry.isEmpty else { return false }
        return citiesInCountry.allSatisfy { isCityCompleted($0) }
    }
    
    func resetProgress() {
        progressManager.resetAllProgress()
        refreshData()
    }
}

// MARK: - Hierarchical Data Structure
struct ContinentGroup: Identifiable {
    let id: CityLocation.Continent
    let countries: [CountryGroup]
}

struct CountryGroup: Identifiable {
    let id: CityLocation.Country
    let cities: [CityLocation.City]
}

extension CityViewModel {
    var groupedByContinent: [ContinentGroup] {
        let filtered = allCities.filter { city in
            searchText.isEmpty || city.name.localizedCaseInsensitiveContains(searchText)
        }
        
        let continentDict = Dictionary(grouping: filtered) { $0.country.continent }
        
        return continentDict.map { (continent, citiesInContinent) in
            let countryDict = Dictionary(grouping: citiesInContinent) { $0.country }
            let countryGroups = countryDict.map { (country, citiesInCountry) in
                CountryGroup(
                    id: country,
                    cities: citiesInCountry.sorted { $0.name < $1.name }
                )
            }.sorted { $0.id.rawValue < $1.id.rawValue }
            
            return ContinentGroup(id: continent, countries: countryGroups)
        }.sorted { $0.id.rawValue < $1.id.rawValue }
    }
}
