//
//  LandmarkEntity.swift
//  Stamped! A City Passport
//
//  A landmark as Shortcuts sees it, for "Open a Landmark". Like CityEntity, but the id
//  also names the city, because the same building id could appear in two cities.
//

import AppIntents

/// A landmark the Shortcuts app can list, search by name and pass to "Open a Landmark".
struct LandmarkEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Landmark")
    static let defaultQuery = LandmarkEntityQuery()

    /// "<city raw value>|<building id>", e.g. "Paris|eiffel_tower"
    let id: String
    let name: String
    let cityName: String

    init(building: Building, city: CityLocation.City) {
        id = "\(city.rawValue)|\(building.id)"
        name = building.name
        cityName = city.name
    }

    /// Looks a saved id back up; nil if the city or landmark is no longer in the app
    init?(id: String) {
        let parts = id.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let city = CityLocation.City(rawValue: parts[0]),
              let building = city.buildings.first(where: { $0.id == parts[1] })
        else { return nil }
        self.init(building: building, city: city)
    }

    var city: CityLocation.City? {
        id.split(separator: "|", maxSplits: 1).first.flatMap { CityLocation.City(rawValue: String($0)) }
    }

    var buildingID: String {
        id.split(separator: "|", maxSplits: 1).last.map(String.init) ?? ""
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(cityName)",
            image: .init(systemName: "building.columns.fill")
        )
    }

    /// Every landmark in every city and campus
    static func all() -> [LandmarkEntity] {
        CityLocation.City.allCases.flatMap { city in
            city.buildings.map { LandmarkEntity(building: $0, city: city) }
        }
    }
}

/// Finds landmarks for the Shortcuts picker and for Siri's "Which landmark?" follow-up.
/// No Siri phrase names a landmark directly: there are over a thousand, far more than Siri
/// should learn as phrases, so Siri asks for the name instead.
struct LandmarkEntityQuery: EntityStringQuery {
    @MainActor func entities(for identifiers: [String]) async throws -> [LandmarkEntity] {
        identifiers.compactMap(LandmarkEntity.init(id:))
    }

    /// Every landmark A to Z: the list the picker shows before you type
    @MainActor func suggestedEntities() async throws -> [LandmarkEntity] {
        LandmarkEntity.all().sorted { $0.name < $1.name }
    }

    /// Typing "eiffel" finds the Eiffel Tower; typing a city's name lists its landmarks
    @MainActor func entities(matching string: String) async throws -> [LandmarkEntity] {
        try await suggestedEntities().filter {
            $0.name.localizedStandardContains(string) || $0.cityName.localizedStandardContains(string)
        }
    }
}
