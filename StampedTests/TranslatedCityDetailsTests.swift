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
    private let translatedLanguages = ["es", "de", "fr", "it", "pt", "ja", "ko", "zh-Hans"]

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

    // No two places share the same English description. 9 Brazilian and 5 Indonesian cities
    // once shared one copied country-level entry, so a Recife user read about São Paulo's airport.
    func testNoTwoPlacesShareADescription() throws {
        let english = try englishDetails()
        for field in longFields {
            var placesByText: [String: [String]] = [:]
            for (place, fields) in english {
                if let text = fields[field], !text.isEmpty {
                    placesByText[text, default: []].append(place)
                }
            }
            let shared = placesByText.values.filter { $0.count > 1 }.map { $0.sorted() }
            XCTAssertTrue(shared.isEmpty, "\(field) is the same for: \(shared)")
        }
    }

    // In each language, a currency reads the same in every city and keeps the English symbol.
    // The same currency used to be translated in one city and left in English in the next,
    // and one Chinese entry had a broken symbol: "(Î.Í)" instead of "(د.إ)".
    func testCurrencyNamesAreConsistent() throws {
        let english = try englishDetails()
        for language in translatedLanguages {
            let translated = try details(for: language)
            var namesByEnglish: [String: Set<String>] = [:]
            for (place, englishFields) in english {
                guard let englishName = englishFields["currencyInfo"],
                      let name = translated[place]?["currencyInfo"] else { continue }
                namesByEnglish[englishName, default: []].insert(name)
                // The symbol in brackets, for example "(€)", must match the English exactly
                if let symbol = englishName.range(of: #"\(.*\)$"#, options: .regularExpression) {
                    XCTAssertTrue(name.hasSuffix(String(englishName[symbol])),
                                  "\(language) \(place): '\(name)' should end with \(englishName[symbol])")
                }
            }
            let mixed = namesByEnglish.filter { $0.value.count > 1 }
            XCTAssertTrue(mixed.isEmpty, "\(language): one currency written several ways: \(mixed)")
        }
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
