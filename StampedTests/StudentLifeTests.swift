//
//  StudentLifeTests.swift
//  StampedTests
//
//  Tests for the "Student Life" section on campus pages (CampusStudentLife.json):
//  the data decodes, ids are unique, every spot is on its campus, and every
//  language has every spot. Lives in StampedTests/ (a synchronized folder).
//

import CoreLocation
import XCTest
@testable import Stamped_

final class StudentLifeTests: XCTestCase {

    /// Decodes one copy of CampusStudentLife.json: English (nil) or a language like "de".
    private func spots(language: String? = nil) throws -> [String: [StudentLifeSpot]] {
        // English lives in Resources/ (not en.lproj), so it's the plain lookup
        let found = if let language {
            Bundle.main.url(forResource: "CampusStudentLife", withExtension: "json", subdirectory: nil, localization: language)
        } else {
            Bundle.main.url(forResource: "CampusStudentLife", withExtension: "json")
        }
        let url = try XCTUnwrap(found, "CampusStudentLife.json is missing for \(language ?? "English")")
        return try JSONDecoder().decode([String: [StudentLifeSpot]].self, from: Data(contentsOf: url))
    }

    // The English file decodes (a typo in a category would fail here) and every key is a real campus
    func testEverySpotDecodesForACampus() throws {
        let all = try spots()
        XCTAssertFalse(all.isEmpty, "No student-life data found")
        for (name, campusSpots) in all {
            let campus = try XCTUnwrap(CityLocation.City(rawValue: name), "'\(name)' isn't a CityLocation.City")
            XCTAssertTrue(campus.isCampus, "\(name) is a city, not a campus")
            XCTAssertFalse(campusSpots.isEmpty, "\(name) has an empty list")
            for spot in campusSpots {
                XCTAssertFalse(spot.name.isEmpty, "\(spot.id) has no name")
                XCTAssertFalse(spot.description.isEmpty, "\(spot.id) has no description")
            }
        }
        // The pilot school has data, so the section shows on its page
        XCTAssertFalse(CityLocation.City.michiganState.studentLife.isEmpty)
    }

    // No id is used twice, and all start with "life_" so they never clash with buildings or traditions
    func testSpotIDsAreUniqueAndPrefixed() throws {
        let ids = try spots().values.flatMap { $0.map(\.id) }
        XCTAssertEqual(Set(ids).count, ids.count, "Duplicate student-life ids")
        for id in ids {
            XCTAssertTrue(id.hasPrefix("life_"), "\(id) should start with life_")
        }
    }

    // Every spot is within 2 km of its campus's map centre, the same limit as campus buildings
    func testSpotsAreNearTheirCampus() throws {
        for (name, campusSpots) in try spots() {
            let campus = try XCTUnwrap(CityLocation.City(rawValue: name))
            let centre = CLLocation(latitude: campus.coordinate.lat, longitude: campus.coordinate.lon)
            for spot in campusSpots {
                let km = CLLocation(latitude: spot.latitude, longitude: spot.longitude).distance(from: centre) / 1000
                XCTAssertLessThanOrEqual(km, 2.0, "\(name) / \(spot.name) is \(km) km from the campus")
            }
        }
    }

    // Every language's own CampusStudentLife.json has the same spots as English, with the
    // same category and coordinates (only the text is translated)
    func testEveryLanguageHasEverySpot() throws {
        let english = try spots()
        let languages = Bundle.main.localizations.filter { $0 != "Base" && $0 != "en" }
        XCTAssertFalse(languages.isEmpty, "No app languages found")
        for language in languages {
            let translated = try spots(language: language)
            for (name, englishSpots) in english {
                let byID = Dictionary(uniqueKeysWithValues: (translated[name] ?? []).map { ($0.id, $0) })
                for spot in englishSpots {
                    guard let match = byID[spot.id] else {
                        XCTFail("\(language): \(name) is missing \(spot.id)")
                        continue
                    }
                    XCTAssertEqual(match.category, spot.category, "\(language): \(spot.id) category differs")
                    XCTAssertEqual(match.latitude, spot.latitude, "\(language): \(spot.id) latitude differs")
                    XCTAssertEqual(match.longitude, spot.longitude, "\(language): \(spot.id) longitude differs")
                    XCTAssertFalse(match.description.isEmpty, "\(language): \(spot.id) has no description")
                }
            }
        }
    }
}
