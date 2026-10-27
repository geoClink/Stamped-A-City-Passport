//
//  WebLinkRouterTests.swift
//  StampedTests
//
//  Website links open the right city or campus. The expected slugs are the real page names on
//  georgeclinkscalesdev.com, so a change here means the site's links would stop matching.
//

import XCTest
@testable import Stamped_

final class WebLinkRouterTests: XCTestCase {

    func testSlugsMatchTheWebsitePageNames() {
        let expected = [
            "Michigan State University": "michigan-state-university",
            "Rutgers University–New Brunswick": "rutgers-universitynew-brunswick",
            "University of Nebraska–Lincoln": "university-of-nebraskalincoln",
            "Texas A&M University": "texas-a-m-university",
            "King's College London": "kings-college-london",
            "University of Paris (Sorbonne)": "university-of-paris-sorbonne",
            "Washington D.C.": "washington-d-c",
            "São Paulo": "sao-paulo",
            "Xi'an": "xian",
        ]
        for (name, slug) in expected {
            XCTAssertEqual(WebLinkRouter.slug(name), slug, name)
        }
    }

    // Two cities or two campuses with the same slug would share one web page
    func testSlugsAreUnique() {
        for group in [CityLocation.City.campusCases, CityLocation.City.cityCases] {
            let slugs = group.map { WebLinkRouter.slug($0.rawValue) }
            XCTAssertEqual(Set(slugs).count, slugs.count)
        }
    }

    func testCampusAndCityLinksOpenTheirPage() {
        let campus = URL(string: "https://georgeclinkscalesdev.com/stamped-colleges/michigan-state-university.html")!
        XCTAssertEqual(WebLinkRouter.city(from: campus), .michiganState)
        let city = URL(string: "https://georgeclinkscalesdev.com/stamped-cities/chicago.html#chi-01")!
        XCTAssertEqual(WebLinkRouter.city(from: city), .chicago)
    }

    func testOtherPagesOpenNothing() {
        for link in [
            "https://georgeclinkscalesdev.com/stamped-colleges.html",
            "https://georgeclinkscalesdev.com/stamped-cities/index.html",
            "https://georgeclinkscalesdev.com/stamped-cities/europe.html",
            "https://georgeclinkscalesdev.com/stamped-colleges/chicago.html",   // a city, not a campus
            "https://example.com/stamped-cities/chicago.html",
        ] {
            XCTAssertNil(WebLinkRouter.city(from: URL(string: link)!), link)
        }
    }
}
