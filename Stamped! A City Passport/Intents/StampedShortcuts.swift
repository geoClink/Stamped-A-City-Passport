//
//  StampedShortcuts.swift
//  Stamped! A City Passport
//
//  Siri and Shortcuts actions: "Open my passport" and "Open a city". Both open the app and
//  go through NavigationManager, the same way a website link or a Spotlight result does.
//  The spoken phrases are translated in each language's AppShortcuts.strings; titles and
//  descriptions are in Localizable.strings.
//
//  iPhone, iPad and Mac only: the Vision Pro app has its own city list (no CityLocation.City),
//  so these files aren't part of the Tally-AVP target.
//

import AppIntents

// MARK: - City or campus, as Shortcuts sees it

/// A city or campus the Shortcuts app can list, search and pass to "Open a City".
struct CityEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "City or Campus")
    static let defaultQuery = CityEntityQuery()

    /// The city's raw value ("Paris", "McGill University"), which is also how stamps save it
    let id: String
    let name: String
    let isCampus: Bool

    init(city: CityLocation.City) {
        id = city.rawValue
        name = city.name
        isCampus = city.isCampus
    }

    var city: CityLocation.City? { CityLocation.City(rawValue: id) }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: isCampus ? "Campus" : "City",
            image: .init(systemName: isCampus ? "graduationcap.fill" : "building.2.fill")
        )
    }
}

/// Finds cities and campuses for the Shortcuts picker and for Siri ("Open Paris in Stamped!").
/// Its functions are @MainActor because the app's city data and navigation live on the main thread.
struct CityEntityQuery: EntityStringQuery {
    @MainActor func entities(for identifiers: [String]) async throws -> [CityEntity] {
        identifiers.compactMap(CityLocation.City.init(rawValue:)).map(CityEntity.init(city:))
    }

    /// Every city, then every campus, each A to Z: the list the picker shows before you type,
    /// and the names Siri listens for
    @MainActor func suggestedEntities() async throws -> [CityEntity] {
        let sorted = { (places: [CityLocation.City]) in places.sorted { $0.name < $1.name } }
        return (sorted(CityLocation.City.cityCases) + sorted(CityLocation.City.campusCases))
            .map(CityEntity.init(city:))
    }

    /// Typing in the picker: "sao" finds São Paulo (accents and capitals don't matter)
    @MainActor func entities(matching string: String) async throws -> [CityEntity] {
        try await suggestedEntities().filter { $0.name.localizedStandardContains(string) }
    }
}

// MARK: - Actions

struct OpenPassportIntent: AppIntent {
    static let title: LocalizedStringResource = "Open My Passport"
    static let description = IntentDescription("Opens your passport of collected stamps in Stamped!.")
    static let openAppWhenRun = true

    @MainActor func perform() async throws -> some IntentResult {
        NavigationManager.shared.passportRequested = true
        return .result()
    }
}

struct OpenCityIntent: AppIntent {
    static let title: LocalizedStringResource = "Open a City"
    static let description = IntentDescription("Opens a city or campus page in Stamped!.")
    static let openAppWhenRun = true

    @Parameter(title: "City or Campus", requestValueDialog: "Which city or campus?")
    var city: CityEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$city)")
    }

    @MainActor func perform() async throws -> some IntentResult {
        // The same path a website link takes (WebLinkRouter → spotlightCity → CityListView)
        NavigationManager.shared.spotlightCity = city.city
        return .result()
    }
}

// MARK: - Siri phrases

/// The phrases Siri and Spotlight know without any setup. Each must name the app.
struct StampedShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenPassportIntent(),
            phrases: [
                "Open my passport in \(.applicationName)",
                "Show my passport in \(.applicationName)",
                "Show my \(.applicationName) passport",
            ],
            shortTitle: "My Passport",
            systemImageName: "book.closed.fill"
        )
        AppShortcut(
            intent: OpenCityIntent(),
            phrases: [
                "Open \(\.$city) in \(.applicationName)",
                "Show \(\.$city) in \(.applicationName)",
                // No city named: Siri asks "Which city or campus?"
                "Open a city in \(.applicationName)",
            ],
            shortTitle: "Open a City",
            systemImageName: "building.2.fill"
        )
    }
}
