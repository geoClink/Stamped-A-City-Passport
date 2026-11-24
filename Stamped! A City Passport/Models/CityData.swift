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
enum CityDetailsStore {
    private static var cache: [String: CityLocation.City.CityDetails]?

    private static func load() -> [String: CityLocation.City.CityDetails] {
        if let cached = cache { return cached }
        let decoded = loadDetails(for: Bundle.main.preferredLocalizations)
        cache = decoded
        return decoded
    }

    /// Reads the CityDetails.json for the first language in `localizations` that has one,
    /// or the English file at the top of the bundle.
    ///
    /// Why not just `Bundle.main.url(forResource: "CityDetails", withExtension: "json")`?
    /// Bundle checks the top of the bundle before any .lproj folder, and the English
    /// file lives there (Resources/CityDetails.json), so that call returned English for
    /// every language. Here each language's folder ("es.lproj") is asked for by name first.
    static func loadDetails(for localizations: [String], in bundle: Bundle = .main) -> [String: CityLocation.City.CityDetails] {
        var folders: [String] = []
        for localization in localizations {
            folders.append("\(localization).lproj")
            // "pt-BR" → "pt", so a Brazilian setting still finds pt.lproj ("zh-Hans" has its own folder)
            if let base = localization.split(separator: "-").first, String(base) != localization {
                folders.append("\(base).lproj")
            }
        }
        folders.append("") // last: the English file at the top of the bundle

        for folder in folders {
            guard let url = bundle.url(forResource: "CityDetails", withExtension: "json",
                                       subdirectory: folder.isEmpty ? nil : folder) else { continue }
            if let details = decodeDetails(at: url) { return details }
        }
        print("CityDetailsStore: Failed to load CityDetails.json")
        return [:]
    }

    private static func decodeDetails(at url: URL) -> [String: CityLocation.City.CityDetails]? {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: CityLocation.City.CityDetails].self, from: data)
        else { return nil }
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
