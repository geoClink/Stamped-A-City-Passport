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
    /// Campuses with every landmark stamped; they're passport stamps too, counted apart from cities
    @Published var masteredCampusCount: Int = 0
    @Published var totalCities: Int = 0
    @Published var searchText: String = ""
    
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    let allCities = CityLocation.City.allCases
    // City counts and the continent sections leave campuses out (they have their own section)
    let cityCases = CityLocation.City.cityCases
    
    private let progressManager = GlobalProgressManager.shared
    
    init() {
        self.totalCities = cityCases.count
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
        self.masteredCount = cityCases.filter { isCityCompleted($0) }.count
        self.masteredCampusCount = CityLocation.City.campusCases.filter { isCityCompleted($0) }.count
    }
    
    func isCityCompleted(_ city: CityLocation.City) -> Bool {
        let visitedCount = city.buildings.filter { progressManager.isVisited($0.id) }.count
        return visitedCount == city.buildings.count && !city.buildings.isEmpty
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
        return Array(countries).sorted { $0.localizedName.localizedStandardCompare($1.localizedName) == .orderedAscending }
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
        let citiesInCountry = cityCases.filter { $0.country == country }
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

/// One group inside "Campus Architecture": a US athletic conference, or a country.
struct CampusGroup: Identifiable {
    enum Kind: Hashable {
        case conference(CampusConference)
        /// The country's name; Australian states share one "Australia" group.
        case country(String)
    }

    let kind: Kind
    let campuses: [CityLocation.City]

    var id: Kind { kind }

    var title: String {
        switch kind {
        case .conference(let conference): return conference.title
        case .country(let name):
            // `name` stays English (it's the group's identity); the header shows it in the app's language
            let shown = name == "Australia"
                ? CityLocation.Country.localizedRegion("AU", english: name)
                : CityLocation.Country(rawValue: name)?.localizedName ?? name
            return shown.localizedUppercase
        }
    }
}

extension CityViewModel {
    var groupedByContinent: [ContinentGroup] {
        let filtered = cityCases.filter { city in
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
            }.sorted { $0.id.localizedName.localizedStandardCompare($1.id.localizedName) == .orderedAscending }
            
            return ContinentGroup(id: continent, countries: countryGroups)
        }.sorted { $0.id.rawValue < $1.id.rawValue }
    }

    /// Campuses for the "Campus Architecture" section: US campuses by conference first,
    /// then every other country's campuses.
    var campusGroups: [CampusGroup] {
        let campuses = CityLocation.City.campusCases
        let bySortName: (CityLocation.City, CityLocation.City) -> Bool = { $0.campusSortName < $1.campusSortName }

        let conferenceGroups = CampusConference.allCases.compactMap { conference -> CampusGroup? in
            let members = campuses.filter { $0.conference == conference }
            return members.isEmpty ? nil : CampusGroup(kind: .conference(conference), campuses: members.sorted(by: bySortName))
        }
        // The city list treats New South Wales, Victoria and Queensland as separate places;
        // for a handful of campuses one "Australia" group reads better.
        let australianStates: Set<CityLocation.Country> = [.newSouthWales, .victoria, .queensland]
        let countryDict = Dictionary(grouping: campuses.filter { $0.conference == nil }) {
            australianStates.contains($0.country) ? "Australia" : $0.country.rawValue
        }
        let countryGroups = countryDict.map { (name, members) in
            CampusGroup(kind: .country(name), campuses: members.sorted(by: bySortName))
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }

        return conferenceGroups + countryGroups
    }

    func isCampusGroupMastered(_ group: CampusGroup) -> Bool {
        !group.campuses.isEmpty && group.campuses.allSatisfy { isCityCompleted($0) }
    }
}
