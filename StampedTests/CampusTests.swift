//
//  CampusTests.swift
//  StampedTests
//
//  Tests for the "Campus Architecture" collection: campus data is complete and
//  in the right place, ids are unique, and campuses stay out of the city counts.
//  Lives in StampedTests/ (a synchronized folder) so Xcode picks it up
//  without editing the project file.
//

import CoreLocation
import XCTest
@testable import Stamped_

final class CampusDataTests: XCTestCase {

    /// The raw registry JSON (city name → buildings), before the app removes any duplicates.
    private func rawRegistry() throws -> [String: [Building]] {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "BuildingRegistry", withExtension: "json"))
        return try JSONDecoder().decode([String: [Building]].self, from: Data(contentsOf: url))
    }

    // There is at least one campus, and every campus is in the registry JSON
    func testEveryCampusHasBuildings() {
        XCTAssertFalse(CityLocation.City.campusCases.isEmpty, "No campuses found")
        for campus in CityLocation.City.campusCases {
            // The quiz needs at least 4 landmarks with coordinates
            XCTAssertGreaterThanOrEqual(campus.buildings.count, 4, "\(campus.rawValue) needs 4+ buildings")
        }
    }

    // Every campus building has coordinates within 2 km of its campus's map centre
    func testCampusBuildingsAreNearTheirCampus() {
        for campus in CityLocation.City.campusCases {
            let centre = CLLocation(latitude: campus.coordinate.lat, longitude: campus.coordinate.lon)
            for building in campus.buildings {
                guard let lat = building.latitude, let lon = building.longitude else {
                    XCTFail("\(campus.rawValue) / \(building.name) has no coordinates")
                    continue
                }
                let km = CLLocation(latitude: lat, longitude: lon).distance(from: centre) / 1000
                XCTAssertLessThanOrEqual(km, 2.0, "\(campus.rawValue) / \(building.name) is \(km) km from the campus")
            }
        }
    }

    // No building id is used twice anywhere in the app (iCloud stamps are saved by id)
    func testNoDuplicateBuildingIDs() throws {
        let allIDs = try rawRegistry().values.flatMap { $0.map(\.id) }
        let duplicates = Dictionary(grouping: allIDs, by: { $0 }).filter { $0.value.count > 1 }.keys
        XCTAssertTrue(duplicates.isEmpty, "Duplicate ids: \(duplicates.sorted())")
    }

    // Campus building ids all start with "campus_", so they can never clash with a city's
    func testCampusIDsArePrefixed() {
        for campus in CityLocation.City.campusCases {
            for building in campus.buildings {
                XCTAssertTrue(building.id.hasPrefix("campus_"), "\(building.id) should start with campus_")
            }
        }
    }

    // Every registry key is a known city or campus (unknown keys are silently skipped by the app)
    func testEveryRegistryKeyIsKnown() throws {
        for name in try rawRegistry().keys {
            XCTAssertNotNil(CityLocation.City(rawValue: name), "'\(name)' isn't a CityLocation.City")
        }
    }

    // Every campus has real details (the placeholder fallback uses "---" as the airport code)
    func testEveryCampusHasDetails() {
        for campus in CityLocation.City.campusCases {
            XCTAssertNotEqual(campus.details.airportCode, "---", "\(campus.rawValue) is missing from CityDetails.json")
        }
    }

    // Every language's own CityDetails.json (de.lproj, ja.lproj...) has every campus,
    // otherwise campus pages show placeholder details in that language
    func testEveryLanguageHasCampusDetails() throws {
        let languages = Bundle.main.localizations.filter { $0 != "Base" && $0 != "en" }
        XCTAssertFalse(languages.isEmpty, "No app languages found")
        for language in languages {
            guard let url = Bundle.main.url(forResource: "CityDetails", withExtension: "json",
                                            subdirectory: nil, localization: language) else { continue }
            let details = try JSONDecoder().decode(
                [String: CityLocation.City.CityDetails].self, from: Data(contentsOf: url)
            )
            for campus in CityLocation.City.campusCases {
                XCTAssertNotNil(details[campus.rawValue], "\(language): \(campus.rawValue) is missing from CityDetails.json")
            }
        }
    }

    // The city list and city counts leave campuses out
    func testCityCasesExcludeCampuses() {
        XCTAssertFalse(CityLocation.City.cityCases.contains { $0.isCampus })
        XCTAssertEqual(
            CityLocation.City.cityCases.count + CityLocation.City.campusCases.count,
            CityLocation.City.allCases.count
        )
    }
}

// MARK: - Achievements

final class CampusAchievementTests: XCTestCase {

    private func achievement(_ id: String) throws -> Achievement {
        try XCTUnwrap(Achievement.allAchievements.first { $0.id == id })
    }

    // A campus stamp earns "Campus Tour" but not the city achievement "First Destination"
    @MainActor func testCampusStampCountsOnlyForCampusAchievements() throws {
        let manager = GlobalProgressManager.shared
        let saved = manager.visitedIDs
        defer { manager.visitedIDs = saved }

        let campus = try XCTUnwrap(CityLocation.City.campusCases.first)
        let building = try XCTUnwrap(campus.buildings.first)
        manager.visitedIDs = [building.id]

        let allCities = CityLocation.City.allCases
        XCTAssertTrue(try achievement("campus_tour").isEarned(manager: manager, cities: allCities))
        XCTAssertFalse(try achievement("first_destination").isEarned(manager: manager, cities: allCities))
        // Landmark achievements count every stamp, campus buildings included
        XCTAssertTrue(try achievement("first_stamp").isEarned(manager: manager, cities: allCities))
    }
}
