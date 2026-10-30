//
//  CampusHistoryTests.swift
//  StampedTests
//
//  Tests for the campus History card: which Wikipedia article each campus reads,
//  how the founding year is picked from Wikidata, and which sentences are shown.
//  No network: the samples below are trimmed copies of real replies (2026-10-29).
//

import XCTest
@testable import Stamped_

final class CampusHistoryTests: XCTestCase {

    // MARK: - Article titles

    // A campus whose name is already the article title uses its name: Michigan State
    // reads "Michigan State University", not the athletics article "Michigan State Spartans"
    func testCampusNameIsTheDefaultTitle() {
        XCTAssertEqual(CityLocation.City.michiganState.historyArticleTitle, "Michigan State University")
        XCTAssertEqual(CityLocation.City.harvard.historyArticleTitle, "Harvard University")
    }

    // The overrides send the few campuses whose name isn't the title to the right article
    func testTitleOverrides() {
        XCTAssertEqual(CityLocation.City.georgiaTech.historyArticleTitle, "Georgia Tech")
        XCTAssertEqual(CityLocation.City.uMinnesota.historyArticleTitle, "University of Minnesota")
        XCTAssertEqual(CityLocation.City.sorbonne.historyArticleTitle, "University of Paris")
    }

    // Real cities have no History card; every campus has a title
    func testOnlyCampusesHaveATitle() {
        XCTAssertNil(CityLocation.City.detroit.historyArticleTitle)
        for campus in CityLocation.City.campusCases {
            XCTAssertNotNil(campus.historyArticleTitle, "\(campus.rawValue) has no history article")
        }
    }

    // MARK: - Founding year

    /// Wikidata's reply for Michigan State's inception (P571): one value, 12 February 1855
    private let msuClaims = """
    {"claims":{"P571":[{"mainsnak":{"snaktype":"value","property":"P571","datavalue":{"value":
    {"time":"+1855-02-12T00:00:00Z","timezone":0,"before":0,"after":0,"precision":11,
    "calendarmodel":"http://www.wikidata.org/entity/Q1985727"},"type":"time"},"datatype":"time"},
    "type":"statement","rank":"normal"}]}}
    """

    // One founding date gives its year
    func testFoundedYearFromSingleValue() {
        XCTAssertEqual(CampusHistoryService.foundedYear(fromClaims: Data(msuClaims.utf8)), 1855)
    }

    /// Builds a P571 reply from (date, precision, rank) values
    private func claims(_ values: [(String, Int, String)]) -> Data {
        let statements = values.map { time, precision, rank in
            #"{"mainsnak":{"datavalue":{"value":{"time":"\#(time)","precision":\#(precision)}}},"rank":"\#(rank)"}"#
        }
        return Data(#"{"claims":{"P571":[\#(statements.joined(separator: ","))]}}"#.utf8)
    }

    // Two dates that disagree (University of Maryland: 1856 and 1858) give no year rather than a guess
    func testDisagreeingYearsGiveNil() {
        let data = claims([("+1856-00-00T00:00:00Z", 9, "normal"), ("+1858-03-06T00:00:00Z", 11, "normal")])
        XCTAssertNil(CampusHistoryService.foundedYear(fromClaims: data))
    }

    // When Wikidata marks one value "preferred", that one wins
    func testPreferredValueWins() {
        let data = claims([("+1856-00-00T00:00:00Z", 9, "preferred"), ("+1858-03-06T00:00:00Z", 11, "normal")])
        XCTAssertEqual(CampusHistoryService.foundedYear(fromClaims: data), 1856)
    }

    // A "12th century" value (precision 7) is too vague to show as a year; deprecated values are ignored
    func testVagueAndDeprecatedValuesAreIgnored() {
        XCTAssertNil(CampusHistoryService.foundedYear(fromClaims: claims([("+1150-00-00T00:00:00Z", 7, "normal")])))
        let data = claims([("+1817-08-26T00:00:00Z", 11, "normal"), ("+1837-00-00T00:00:00Z", 9, "deprecated")])
        XCTAssertEqual(CampusHistoryService.foundedYear(fromClaims: data), 1817)
    }

    // No inception at all, or a broken reply, gives no year
    func testMissingClaimGivesNil() {
        XCTAssertNil(CampusHistoryService.foundedYear(fromClaims: Data(#"{"claims":{}}"#.utf8)))
        XCTAssertNil(CampusHistoryService.foundedYear(fromClaims: Data("not json".utf8)))
    }

    // MARK: - Sentences

    /// Michigan State's Wikipedia summary extract
    private let msuExtract = "Michigan State University is a public land-grant research university in East Lansing, Michigan, United States. It was founded in 1855 as the Agricultural College of the State of Michigan, the first of its kind in the country. After the introduction of the Morrill Act in 1862, the state designated the college a land-grant institution in 1863, making it the first of the land-grant colleges in the United States. The college became coeducational in 1870. Michigan State has facilities across the state, and over 550,500 alumni."

    // The page header already shows the first two sentences, so History starts at the third
    func testHistorySkipsTheHeaderSentences() {
        let text = CampusHistoryService.historySentences(from: msuExtract)
        XCTAssertTrue(text.hasPrefix("After the introduction of the Morrill Act"))
        XCTAssertTrue(text.hasSuffix("over 550,500 alumni."))
        XCTAssertFalse(text.contains("public land-grant research university"))
    }

    // At most four sentences are shown
    func testHistoryShowsAtMostFourSentences() {
        let long = (1...9).map { "Sentence number \($0) is here." }.joined(separator: " ")
        let text = CampusHistoryService.historySentences(from: long)
        XCTAssertEqual(CampusHistoryService.splitSentences(text).count, 4)
        XCTAssertTrue(text.hasPrefix("Sentence number 3"))
    }

    // A short extract with nothing new after the header's two sentences shows its opening instead of nothing
    func testShortExtractShowsItsOpening() {
        let short = "Example University is a school. It was founded in 1900. It has a library."
        XCTAssertEqual(CampusHistoryService.historySentences(from: short), short)
    }

    // Abbreviations like "U.S." don't end a sentence
    func testAbbreviationsDontSplitSentences() {
        let text = "It is one of the oldest schools in the U.S. state of Georgia. It was chartered in 1785."
        XCTAssertEqual(CampusHistoryService.splitSentences(text).count, 2)
    }
}
