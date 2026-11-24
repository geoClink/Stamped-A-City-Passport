//
//  TranslatedCityDetailsTests.swift
//  StampedTests
//
//  Checks that the long city descriptions (fun fact, airport, language, transportation)
//  are really translated. New cities used to get the English text copied into every
//  language's CityDetails.json, so a Spanish user read English on those cities.
//  A field counts as untranslated when it's exactly the same as the English text.
//

import XCTest
@testable import Stamped_

final class TranslatedCityDetailsTests: XCTestCase {

    /// Languages whose long descriptions are fully translated. Add a language here
    /// once its CityDetails.json has been translated, so it can't slip back.
    private let translatedLanguages = ["es", "de", "fr", "it", "pt"]

    /// The long fields. Short ones (airport name, nickname, transit name) are often
    /// proper names that stay the same in every language, so they aren't checked.
    private let longFields = ["funFact", "airportInfo", "languageInfo", "transportationFact"]

    /// The English details, which sit at the top of the app bundle (not in an .lproj folder)
    private func englishDetails() throws -> [String: [String: String]] {
        let url = Bundle.main.bundleURL.appendingPathComponent("CityDetails.json")
        return try JSONDecoder().decode([String: [String: String]].self, from: Data(contentsOf: url))
    }

    /// One language's details. The path is built by hand on purpose:
    /// Bundle.url(forResource:withExtension:subdirectory:localization:) returns the top-level
    /// English file whenever one exists, so it would compare English with English.
    private func details(for language: String) throws -> [String: [String: String]] {
        let url = Bundle.main.bundleURL.appendingPathComponent("\(language).lproj/CityDetails.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "\(language).lproj/CityDetails.json isn't in the app")
        return try JSONDecoder().decode([String: [String: String]].self, from: Data(contentsOf: url))
    }

    // Every long description in a translated language differs from the English one
    func testLongDescriptionsAreTranslated() throws {
        let english = try englishDetails()
        XCTAssertFalse(english.isEmpty, "English CityDetails.json is empty")

        for language in translatedLanguages {
            let translated = try details(for: language)
            var stillEnglish: [String] = []
            for (city, englishFields) in english {
                for field in longFields {
                    guard let englishText = englishFields[field], !englishText.isEmpty else { continue }
                    if translated[city]?[field] == englishText {
                        stillEnglish.append("\(city).\(field)")
                    }
                }
            }
            XCTAssertTrue(stillEnglish.isEmpty,
                          "\(language): \(stillEnglish.count) fields are still in English: \(stillEnglish.sorted())")
        }
    }
}
