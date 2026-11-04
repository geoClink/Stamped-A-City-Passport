//
//  StampedShortcuts.swift
//  Stamped! A City Passport
//
//  Siri and Shortcuts actions. "Open my passport", "Open a city", "Open a landmark",
//  "Start a walking tour" and "What's near me" (OpenNearbyIntent.swift) open the app and go
//  through NavigationManager, the same way a website link or a Spotlight result does.
//  "Show my progress" (ShowProgressIntent.swift) answers without opening the app.
//  The spoken phrases are translated in AppShortcuts.xcstrings; titles, descriptions and
//  dialogs are in Localizable.strings.
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

struct OpenLandmarkIntent: AppIntent {
    static let title: LocalizedStringResource = "Open a Landmark"
    static let description = IntentDescription("Opens a landmark's page in Stamped!.")
    static let openAppWhenRun = true

    @Parameter(title: "Landmark", requestValueDialog: "Which landmark?")
    var landmark: LandmarkEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$landmark)")
    }

    @MainActor func perform() async throws -> some IntentResult {
        guard let city = landmark.city else { return .result() }
        // The city opens first; its page (or on Mac its map) then opens the landmark
        NavigationManager.shared.landmarkRequest = LandmarkRequest(city: city, buildingID: landmark.buildingID)
        NavigationManager.shared.spotlightCity = city
        return .result()
    }
}

/// The city map's Tour: it flies from landmark to landmark in walking order.
struct StartWalkingTourIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a Walking Tour"
    static let description = IntentDescription("Opens a city's map in Stamped! and starts the tour of its landmarks, in walking order.")
    static let openAppWhenRun = true

    @Parameter(title: "City or Campus", requestValueDialog: "Which city or campus?")
    var city: CityEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Start a walking tour of \(\.$city)")
    }

    @MainActor func perform() async throws -> some IntentResult {
        guard let place = city.city else { return .result() }
        // The city page opens its map, and the map starts the tour (CityDetailView, CityMapView)
        NavigationManager.shared.tourRequestCity = place
        NavigationManager.shared.spotlightCity = place
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
        AppShortcut(
            intent: ShowProgressIntent(),
            phrases: [
                "Show my progress in \(.applicationName)",
                "How many stamps do I have in \(.applicationName)",
                "Show my \(.applicationName) progress",
            ],
            shortTitle: "My Progress",
            systemImageName: "chart.pie.fill"
        )
        AppShortcut(
            intent: OpenNearbyIntent(),
            phrases: [
                "What's near me in \(.applicationName)",
                "Show what's nearby in \(.applicationName)",
            ],
            shortTitle: "What's Near Me",
            systemImageName: "location.fill"
        )
        AppShortcut(
            intent: StartWalkingTourIntent(),
            phrases: [
                "Start a walking tour of \(\.$city) in \(.applicationName)",
                "Tour \(\.$city) in \(.applicationName)",
                // No city named: Siri asks "Which city or campus?"
                "Start a walking tour in \(.applicationName)",
            ],
            shortTitle: "Walking Tour",
            systemImageName: "figure.walk"
        )
        AppShortcut(
            intent: OpenLandmarkIntent(),
            phrases: [
                // Siri asks "Which landmark?" (LandmarkEntityQuery says why there's no name here)
                "Open a landmark in \(.applicationName)",
                "Find a landmark in \(.applicationName)",
            ],
            shortTitle: "Open a Landmark",
            systemImageName: "building.columns.fill"
        )
    }
}
