//
//  FeedbackMailTests.swift
//  StampedTests
//
//  Report and suggestion emails arrive whole and carry the tag the mail filter looks for.
//

import XCTest
@testable import Stamped_

final class FeedbackMailTests: XCTestCase {

    private func parts(_ url: URL?) throws -> (subject: String, body: String) {
        let url = try XCTUnwrap(url)
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        return (items.first { $0.name == "subject" }?.value ?? "", items.first { $0.name == "body" }?.value ?? "")
    }

    // "&" in a name used to end the subject early and drop the body
    func testAmpersandInNameKeepsTheWholeEmail() throws {
        let campus = try XCTUnwrap(CityLocation.City.campusCases.first { $0.name.contains("&") })
        let mail = try parts(FeedbackMail.tradition(for: campus))
        XCTAssertTrue(mail.subject.hasSuffix(campus.name), mail.subject)
        XCTAssertTrue(mail.body.contains("Place: \(campus.name)"), mail.body)
        XCTAssertTrue(mail.body.contains("App: Stamped!"), mail.body)
    }

    func testBuildingReportNamesTheBuildingRecord() throws {
        let building = try XCTUnwrap(CityLocation.City.michiganState.buildings.first)
        let mail = try parts(FeedbackMail.building(building, in: .michiganState))
        XCTAssertTrue(mail.subject.hasPrefix(FeedbackMail.tag))
        XCTAssertTrue(mail.body.contains("Building id: \(building.id)"), mail.body)
    }

    func testEveryKindIsTagged() throws {
        for url in [FeedbackMail.place(.chicago), FeedbackMail.general(subject: "Content Issue Report", body: "")] {
            XCTAssertTrue(try parts(url).subject.hasPrefix(FeedbackMail.tag))
        }
    }
}
