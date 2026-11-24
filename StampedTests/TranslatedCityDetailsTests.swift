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

    // A nickname shared by several places reads the same in each language
    // ('The White City' was 'La Ciudad Blanca' in one city and 'La ciudad blanca' in another)
    func testSharedNicknamesReadTheSame() throws {
        let english = try englishDetails()
        for language in translatedLanguages {
            let translated = try details(for: language)
            var namesByEnglish: [String: Set<String>] = [:]
            for (place, englishFields) in english {
                guard let englishName = englishFields["nickname"],
                      let name = translated[place]?["nickname"] else { continue }
                namesByEnglish[englishName, default: []].insert(name)
            }
            let mixed = namesByEnglish.filter { $0.value.count > 1 }
            XCTAssertTrue(mixed.isEmpty, "\(language): one nickname written several ways: \(mixed)")
        }
    }

    // Transit brand names stay as they are. Word-by-word translation once turned Dallas's
    // DART into 'PFEIL' (arrow), Denver's RTD into '热电阻' (a thermometer part), Toronto's
    // TTC into '电讯委员会' (telecoms commission) and the First Bus company into 'first bus'.
    func testTransitBrandNamesAreNotTranslated() throws {
        let english = try englishDetails()
        let brands = ["DART", "RTD", "ART", "TTC", "First Bus"]
        for language in translatedLanguages {
            let translated = try details(for: language)
            for (place, englishFields) in english {
                guard let englishLabel = englishFields["transportation"],
                      let label = translated[place]?["transportation"] else { continue }
                for brand in brands where englishLabel.range(of: "\\b\(brand)\\b", options: .regularExpression) != nil {
                    XCTAssertTrue(label.contains(brand), "\(language) \(place): '\(label)' lost the name \(brand)")
                }
            }
        }
    }

    // No hidden zero-width characters in any language's city text (they had crept into
    // about 30 entries, splitting words like 'Park & Ride' in a way you can't see)
    func testNoInvisibleCharacters() throws {
        let invisible = CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{FEFF}")
        let all = try [("en", englishDetails())] + translatedLanguages.map { ($0, try details(for: $0)) }
        for (language, places) in all {
            for (place, fields) in places {
                for (field, text) in fields where text.rangeOfCharacter(from: invisible) != nil {
                    XCTFail("\(language) \(place).\(field) has an invisible character")
                }
            }
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

    // Goes through the app's real loader, the code the city screens use.
    // The checks above read each .lproj file by path, so they kept passing while the app
    // itself showed English in every language: the loader asked Bundle for "CityDetails.json",
    // and Bundle hands back the English copy at the top of the bundle before any .lproj copy.
    func testLoaderReturnsTheUsersLanguage() {
        let recifeNickname: [String: String] = [
            "es": "Venecia Brasileña",
            "de": "Brasilianisches Venedig",
            "ja": "ブラジルのベネチア",
            "pt": "Veneza Brasileira",
            "zh-Hans": "巴西威尼斯",
            "en": "Brazilian Venice",
        ]
        for (language, nickname) in recifeNickname {
            let details = CityDetailsStore.loadDetails(for: [language])
            XCTAssertEqual(details["Recife"]?.nickname, nickname, "\(language) shows the wrong Recife nickname")
        }
    }

    // A language with a region ("pt-BR") uses its base folder, and a language the app
    // doesn't have (Swedish) gets English instead of an empty screen.
    func testLoaderFallsBack() {
        XCTAssertEqual(CityDetailsStore.loadDetails(for: ["pt-BR"])["Recife"]?.nickname, "Veneza Brasileira")
        XCTAssertEqual(CityDetailsStore.loadDetails(for: ["sv"])["Recife"]?.nickname, "Brazilian Venice")
        XCTAssertEqual(CityDetailsStore.loadDetails(for: [])["Recife"]?.nickname, "Brazilian Venice")
    }
}
