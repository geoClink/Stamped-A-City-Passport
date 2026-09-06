//
//  CityData.swift
//  Stamped!
//

import Foundation

extension CityLocation.City {
    struct CityDetails: Codable {
        let nickname: String
        let airportName: String
        let airportCode: String
        let funFact: String
        let language: String
        let airportInfo: String
        let languageInfo: String
        let currencyInfo: String
        let currencyCode: String
        let transportation: String
        let transportationFact: String
    }

    var details: CityDetails {
        CityDetailsStore.details(for: self.rawValue)
    }
}

// Loads CityDetails.json once on first access, caches the result — same pattern as BuildingRegistry.
private enum CityDetailsStore {
    private static var cache: [String: CityLocation.City.CityDetails]?

    private static func load() -> [String: CityLocation.City.CityDetails] {
        if let cached = cache { return cached }
        guard let url = Bundle.main.url(forResource: "CityDetails", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: CityLocation.City.CityDetails].self, from: data)
        else {
            print("CityDetailsStore: Failed to load CityDetails.json")
            return [:]
        }
        cache = decoded
        return decoded
    }

    static func details(for cityName: String) -> CityLocation.City.CityDetails {
        if let entry = load()[cityName] { return entry }
        return CityLocation.City.CityDetails(
            nickname: cityName, airportName: "", airportCode: "---",
            funFact: "", language: "", airportInfo: "",
            languageInfo: "", currencyInfo: "", currencyCode: "USD",
            transportation: "", transportationFact: ""
        )
    }
}
