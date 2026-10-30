//
//  CollegeScorecardTests.swift
//  StampedTests
//
//  Tests for the College Facts card: reading a College Scorecard API response,
//  formatting its numbers, and the campus → Scorecard ID list.
//  No network: the sample below is a real response for Michigan State, saved 2026-10-29.
//

import XCTest
@testable import Stamped_

final class CollegeScorecardTests: XCTestCase {

    /// A real Scorecard reply for Michigan State (id=171100), trimmed to the fields the app asks for
    private let msuSample = """
    {"metadata":{"page":0,"total":1,"per_page":20},"results":[{
      "latest.admissions.admission_rate.overall":0.848,
      "latest.student.size":40922,
      "latest.cost.tuition.in_state":17256,
      "latest.cost.tuition.out_of_state":44640,
      "latest.completion.completion_rate_4yr_150nt":0.803,
      "latest.earnings.10_yrs_after_entry.median":74168,
      "school.name":"Michigan State University",
      "id":171100}]}
    """

    // MARK: - Parsing

    // Every number on the card is read from its dotted Scorecard key
    func testParsesMichiganStateSample() throws {
        let facts = try XCTUnwrap(CollegeScorecardService.parse(Data(msuSample.utf8), unitID: 171100))
        XCTAssertEqual(facts.name, "Michigan State University")
        XCTAssertEqual(try XCTUnwrap(facts.admissionRate), 0.848, accuracy: 0.0001)
        XCTAssertEqual(facts.undergraduates, 40922)
        XCTAssertEqual(facts.inStateTuition, 17256)
        XCTAssertEqual(facts.outOfStateTuition, 44640)
        XCTAssertEqual(try XCTUnwrap(facts.graduationRate), 0.803, accuracy: 0.0001)
        XCTAssertEqual(facts.medianEarnings, 74168)
    }

    // A school the Scorecard has no figure for (null) keeps that fact empty instead of failing
    func testMissingNumbersStayNil() throws {
        let json = """
        {"results":[{"id":1,"school.name":"Test College","latest.student.size":1200,
          "latest.admissions.admission_rate.overall":null}]}
        """
        let facts = try XCTUnwrap(CollegeScorecardService.parse(Data(json.utf8), unitID: 1))
        XCTAssertEqual(facts.undergraduates, 1200)
        XCTAssertNil(facts.admissionRate)
        XCTAssertNil(facts.medianEarnings)
    }

    // No numbers at all means no card (nil), not a card of blanks
    func testSchoolWithNoNumbersGivesNil() {
        let json = #"{"results":[{"id":1,"school.name":"Test College"}]}"#
        XCTAssertNil(CollegeScorecardService.parse(Data(json.utf8), unitID: 1))
    }

    // A reply for a different school, an empty reply or an error page is never shown
    func testWrongOrBrokenResponseGivesNil() {
        XCTAssertNil(CollegeScorecardService.parse(Data(msuSample.utf8), unitID: 170976))
        XCTAssertNil(CollegeScorecardService.parse(Data(#"{"results":[]}"#.utf8), unitID: 171100))
        XCTAssertNil(CollegeScorecardService.parse(Data(#"{"error":{"code":"API_KEY_INVALID"}}"#.utf8), unitID: 171100))
    }

    // MARK: - Formatting

    // US English: whole percents, dollars without cents, thousands separators
    func testFormatsForUSEnglish() {
        let us = Locale(identifier: "en_US")
        XCTAssertEqual(CollegeFactsFormat.percent(0.848, locale: us), "85%")
        XCTAssertEqual(CollegeFactsFormat.dollars(17256, locale: us), "$17,256")
        XCTAssertEqual(CollegeFactsFormat.count(40922, locale: us), "40,922")
    }

    // German: the same numbers in German style (17.256 with a dot), still in US dollars
    func testFormatsForGerman() {
        let german = Locale(identifier: "de_DE")
        XCTAssertTrue(CollegeFactsFormat.dollars(17256, locale: german).contains("17.256"))
        XCTAssertTrue(CollegeFactsFormat.dollars(17256, locale: german).contains("$"))
        XCTAssertEqual(CollegeFactsFormat.count(40922, locale: german), "40.922")
    }

    // The source link opens the school's own page on collegescorecard.ed.gov
    func testScorecardPageURL() throws {
        let facts = try XCTUnwrap(CollegeScorecardService.parse(Data(msuSample.utf8), unitID: 171100))
        XCTAssertEqual(facts.scorecardPageURL?.absoluteString,
                       "https://collegescorecard.ed.gov/school/?171100-Michigan-State-University")
    }

    // MARK: - Campus IDs

    // Michigan State is 171100; campuses outside the US and real cities have no ID
    func testScorecardIDs() {
        XCTAssertEqual(CityLocation.City.michiganState.scorecardID, 171100)
        XCTAssertNil(CityLocation.City.oxford.scorecardID)
        XCTAssertNil(CityLocation.City.mcgill.scorecardID)
        XCTAssertNil(CityLocation.City.detroit.scorecardID)
    }

    // Every US campus has an ID, and no two campuses share one
    func testEveryUSCampusHasAUniqueID() {
        let usCampuses = CityLocation.City.campusCases.filter { $0.country == .unitedStates }
        for campus in usCampuses {
            XCTAssertNotNil(campus.scorecardID, "\(campus.rawValue) has no College Scorecard ID")
        }
        let ids = usCampuses.compactMap(\.scorecardID)
        XCTAssertEqual(Set(ids).count, ids.count, "Two campuses share a Scorecard ID")
    }
}
