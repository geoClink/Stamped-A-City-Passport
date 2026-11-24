//
//  ReleaseReadinessTests.swift
//  StampedTests
//
//  Checks that would embarrass a release if they failed: the city and campus
//  data all loads, every language has every city's details, and the built app
//  carries what App Store Connect looks for (privacy manifest, a widget whose
//  version matches the app). They only read data, nothing in the app changes.
//

import XCTest
@testable import Stamped_

final class ReleaseReadinessTests: XCTestCase {

    // MARK: - Cities and campuses

    // The app has 166 cities and 122 campuses, the numbers the App Store text and website use
    func testCityAndCampusCounts() {
        XCTAssertEqual(CityLocation.City.cityCases.count, 166)
        XCTAssertEqual(CityLocation.City.campusCases.count, 122)
    }

    // The registry JSON decodes and has an entry for every city and campus
    // (one bad entry would make the whole file fail and empty the app)
    func testRegistryLoadsEveryCityAndCampus() {
        let registry = BuildingRegistry.data
        XCTAssertEqual(registry.count, CityLocation.City.allCases.count)
        for city in CityLocation.City.allCases {
            XCTAssertNotNil(registry[city], "\(city.rawValue) is missing from BuildingRegistry.json")
        }
    }

    // Every city and campus has at least 4 landmarks, because a quiz needs 4 answers to choose from
    func testEveryCityHasEnoughLandmarksForAQuiz() {
        for city in CityLocation.City.allCases {
            XCTAssertGreaterThanOrEqual(city.buildings.count, 4, "\(city.rawValue) has too few landmarks")
        }
    }

    // Every landmark has a map pin, a name and an id (the map, tours and stamps need them)
    func testEveryLandmarkHasCoordinatesAndName() {
        for city in CityLocation.City.allCases {
            for building in city.buildings {
                XCTAssertNotNil(building.latitude, "\(building.id) has no latitude")
                XCTAssertNotNil(building.longitude, "\(building.id) has no longitude")
                XCTAssertFalse(building.id.isEmpty, "A landmark in \(city.rawValue) has no id")
                XCTAssertFalse(building.name.trimmingCharacters(in: .whitespaces).isEmpty, "\(building.id) has no name")
            }
        }
    }

    // Every language's CityDetails.json has every city and campus, otherwise that
    // language shows placeholder details ("---" airport, empty facts) for the missing one
    func testEveryLanguageHasEveryCitysDetails() throws {
        let languages = Bundle.main.localizations.filter { $0 != "Base" }
        XCTAssertFalse(languages.isEmpty, "No app languages found")
        for language in languages {
            guard let url = Bundle.main.url(forResource: "CityDetails", withExtension: "json",
                                            subdirectory: nil, localization: language) else { continue }
            let details = try JSONDecoder().decode(
                [String: CityLocation.City.CityDetails].self, from: Data(contentsOf: url)
            )
            let missing = CityLocation.City.allCases.map(\.rawValue).filter { details[$0] == nil }
            XCTAssertTrue(missing.isEmpty, "\(language) CityDetails.json is missing: \(missing)")
        }
    }

    // MARK: - What the app bundle carries

    // The privacy manifest is in the app and declares the UserDefaults reason App Store Connect checks for
    func testPrivacyManifestIsBundled() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
                                "PrivacyInfo.xcprivacy isn't in the app bundle")
        let manifest = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any]
        )
        let apiTypes = manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []
        let categories = apiTypes.compactMap { $0["NSPrivacyAccessedAPIType"] as? String }
        XCTAssertTrue(categories.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
    }

    /// The Home Screen widget inside the app (only built into the iPhone/iPad app).
    private func widgetBundle() throws -> Bundle {
        let plugIns = try XCTUnwrap(Bundle.main.builtInPlugInsURL)
        let url = plugIns.appendingPathComponent("PassportWidgetExtension.appex")
        return try XCTUnwrap(Bundle(url: url), "PassportWidgetExtension.appex isn't in the app")
    }

    // The widget's version and build match the app's; App Store Connect refuses an upload where they differ
    func testWidgetVersionMatchesApp() throws {
        let widget = try widgetBundle()
        for key in ["CFBundleShortVersionString", "CFBundleVersion"] {
            let appValue = Bundle.main.object(forInfoDictionaryKey: key) as? String
            XCTAssertNotNil(appValue, "The app has no \(key)")
            XCTAssertEqual(widget.object(forInfoDictionaryKey: key) as? String, appValue, "Widget \(key) differs from the app")
        }
    }

    // The widget carries its own copy of the landmark registry, which it needs to turn stamps into city names
    func testWidgetBundlesTheRegistry() throws {
        XCTAssertNotNil(try widgetBundle().url(forResource: "BuildingRegistry", withExtension: "json"))
    }
}
