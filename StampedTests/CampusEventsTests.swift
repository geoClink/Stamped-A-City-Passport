//
//  CampusEventsTests.swift
//  StampedTests
//
//  Campus events from a school's own calendar: reading a Localist API response and an
//  iCalendar feed, cleaning the text, and picking the upcoming events to show.
//  The fixtures are trimmed copies of real responses (Purdue's Localist, MSU Libraries' LibCal).
//

import XCTest
@testable import Stamped_

@MainActor
final class CampusEventsTests: XCTestCase {

    /// "Now" for every test: Oct 29 2026, 10:00 in New York (14:00 UTC)
    private let now = ISO8601DateFormatter().date(from: "2026-10-29T14:00:00Z")!

    // MARK: Localist

    private let localistJSON = """
    {"events":[
      {"event":{"id":101,"title":"Pride & Prejudice\\uFEFF","localist_url":"https://events.purdue.edu/event/pride-prejudice",
        "location_name":"Hansen Theatre","location":"Yue-Kong Pao Hall","experience":"inperson","status":"live",
        "description_text":"A witty adaptation of the Austen classic, staged by Purdue Theatre.","photo_url":"https://example.com/photo.jpg",
        "event_instances":[{"event_instance":{"start":"2026-10-30T19:30:00-04:00","all_day":false}}]}},
      {"event":{"id":102,"title":"Fall Research Expo - Virtual Presentations","localist_url":"https://events.purdue.edu/event/expo-virtual",
        "location_name":"","experience":"virtual","status":"live","description_text":"Online.",
        "event_instances":[{"event_instance":{"start":"2026-11-02T10:00:00-05:00","all_day":false}}]}},
      {"event":{"id":103,"title":"GIS Day","localist_url":"https://events.purdue.edu/event/gis-day",
        "location_name":"","location":"Stewart Center","experience":"hybrid","status":"live","description_text":"",
        "event_instances":[
          {"event_instance":{"start":"2026-10-20T00:00:00-04:00","all_day":true}},
          {"event_instance":{"start":"2026-11-10T00:00:00-05:00","all_day":true}}]}},
      {"event":{"id":104,"title":"Venmo Day","localist_url":"https://events.purdue.edu/event/venmo-day",
        "location_name":"Online","experience":"inperson","status":"live","description_text":"",
        "event_instances":[{"event_instance":{"start":"2026-11-02T08:00:00-05:00","all_day":false}}]}}
    ],"page":{"current":1}}
    """

    // Reads the fields we show, picks venue, keeps the event page link and never the photo
    func testLocalistEventFieldsAreRead() throws {
        let events = try CampusEventsService.parseLocalist(Data(localistJSON.utf8), now: now)
        let play = try XCTUnwrap(events.first { $0.id == "localist-101" })
        XCTAssertEqual(play.title, "Pride & Prejudice")   // invisible ﻿ removed
        XCTAssertEqual(play.venue, "Hansen Theatre")
        XCTAssertEqual(play.url.absoluteString, "https://events.purdue.edu/event/pride-prejudice")
        XCTAssertEqual(play.summary, "A witty adaptation of the Austen classic, staged by Purdue Theatre.")
        XCTAssertFalse(play.isAllDay)
        // 19:30 at UTC-4 is 23:30 UTC, and the time zone is kept so it shows as 7:30 PM local
        XCTAssertEqual(play.start, ISO8601DateFormatter().date(from: "2026-10-30T23:30:00Z"))
        XCTAssertEqual(play.timeZone.secondsFromGMT(for: play.start), -4 * 3600)
    }

    // Online-only events are left out (marked virtual, or with "Online" as the place):
    // the page is for people visiting the campus
    func testLocalistSkipsVirtualEvents() throws {
        let events = try CampusEventsService.parseLocalist(Data(localistJSON.utf8), now: now)
        XCTAssertNil(events.first { $0.id == "localist-102" })
        XCTAssertNil(events.first { $0.id == "localist-104" })
        XCTAssertEqual(events.count, 2)
    }

    // A recurring event uses its next date, not one that already passed; empty venue falls back
    func testLocalistRecurringEventUsesNextInstance() throws {
        let events = try CampusEventsService.parseLocalist(Data(localistJSON.utf8), now: now)
        let gisDay = try XCTUnwrap(events.first { $0.id == "localist-103" })
        XCTAssertEqual(gisDay.start, ISO8601DateFormatter().date(from: "2026-11-10T05:00:00Z"))
        XCTAssertTrue(gisDay.isAllDay)
        XCTAssertEqual(gisDay.venue, "Stewart Center")
    }

    // MARK: iCalendar

    // Folded lines (leading space), escaped commas, a quoted parameter with a colon, and one past event
    private let icalText = """
    BEGIN:VCALENDAR\r
    VERSION:2.0\r
    X-WR-TIMEZONE:America/Detroit\r
    BEGIN:VEVENT\r
    DTSTART:20261104T220000Z\r
    SUMMARY:"Making Dances\\, Making Places"\r
    DESCRIPTION:Richard Cruz Davila\\nJulian Samora Research Institute\\n\\nFrom \r
     the 1940s through the 1970s\\, Texas Mexicans migrated to Michigan.\r
    LOCATION:Green Room (Main Library\\, 4 West)\r
    ORGANIZER;CN="Library: Events":MAILTO:events@example.edu\r
    UID:LibCal-3079-1\r
    URL:https://bookings.lib.msu.edu/event/1\r
    END:VEVENT\r
    BEGIN:VEVENT\r
    DTSTART;VALUE=DATE:20261106\r
    SUMMARY:Open Day\r
    UID:LibCal-3079-2\r
    URL:https://bookings.lib.msu.edu/event/2\r
    END:VEVENT\r
    BEGIN:VEVENT\r
    DTSTART:20260929T160000Z\r
    SUMMARY:Already happened\r
    UID:LibCal-3079-3\r
    URL:https://bookings.lib.msu.edu/event/3\r
    END:VEVENT\r
    END:VCALENDAR\r
    """

    // Unfolds lines, unescapes text, reads the UTC start and shows it in the calendar's time zone
    func testICalEventFieldsAreRead() throws {
        let events = CampusEventsService.parseICal(icalText, now: now)
        XCTAssertEqual(events.count, 3)
        let talk = try XCTUnwrap(events.first { $0.id == "ical-LibCal-3079-1" })
        XCTAssertEqual(talk.title, "\"Making Dances, Making Places\"")
        XCTAssertEqual(talk.venue, "Green Room (Main Library, 4 West)")
        XCTAssertEqual(talk.summary, "Richard Cruz Davila Julian Samora Research Institute From the 1940s through the 1970s, Texas Mexicans migrated to Michigan.")
        XCTAssertEqual(talk.url.absoluteString, "https://bookings.lib.msu.edu/event/1")
        XCTAssertEqual(talk.start, ISO8601DateFormatter().date(from: "2026-11-04T22:00:00Z"))
        XCTAssertEqual(talk.timeZone.identifier, "America/Detroit")
    }

    // A date-only start is an all-day event on that day in the campus's time zone
    func testICalAllDayEvent() throws {
        let events = CampusEventsService.parseICal(icalText, now: now)
        let openDay = try XCTUnwrap(events.first { $0.title == "Open Day" })
        XCTAssertTrue(openDay.isAllDay)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Detroit"))
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day, .hour], from: openDay.start),
                       DateComponents(year: 2026, month: 11, day: 6, hour: 0))
    }

    // MARK: Picking what to show

    // Past events are dropped and the rest come soonest first
    func testUpcomingDropsPastAndSortsByDate() {
        let events = CampusEventsService.upcoming(CampusEventsService.parseICal(icalText, now: now), now: now)
        XCTAssertEqual(events.map(\.title), ["\"Making Dances, Making Places\"", "Open Day"])
    }

    // Never more than the maximum, and nothing beyond the 30-day window
    func testUpcomingLimitsCountAndWindow() throws {
        let url = try XCTUnwrap(URL(string: "https://events.example.edu/event/x"))
        let daily = (1...40).map { day in
            CampusEvent(id: "e\(day)", title: "Day \(day)", start: now.addingTimeInterval(Double(day) * 86_400 - 3600),
                        isAllDay: false, timeZone: .current, venue: "", summary: "", url: url)
        }
        let shown = CampusEventsService.upcoming(daily, now: now)
        XCTAssertEqual(shown.count, CampusEventsService.maxEvents)
        XCTAssertEqual(shown.first?.title, "Day 1")
        let late = CampusEventsService.upcoming(Array(daily.suffix(5)), now: now)
        XCTAssertTrue(late.isEmpty)   // days 36 to 40 are past the window
    }

    // MARK: Text

    // HTML is stripped and long text is cut at a word with "…", within the length limit
    func testSummaryIsPlainAndShort() {
        XCTAssertEqual(CampusEventsService.shortSummary("<p>Jazz &amp; blues<br/>night</p>"), "Jazz & blues night")
        let long = String(repeating: "lecture ", count: 40)
        let summary = CampusEventsService.shortSummary(long)
        XCTAssertTrue(summary.hasSuffix("lecture…"))
        XCTAssertLessThanOrEqual(summary.count, CampusEventsService.summaryLength + 1)
    }

    // City calendars are for real cities only, are https, and each city's page finds its own
    func testCityFeedsAreHTTPSCities() {
        for (city, feed) in CityLocation.City.cityEventFeeds {
            XCTAssertFalse(city.isCampus, city.name)
            XCTAssertNil(CityLocation.City.campusEventFeeds[city], "\(city.name) is in both lists")
            XCTAssertEqual(city.eventFeed, feed, city.name)
            if case .ical(let url) = feed.source { XCTAssertEqual(url.scheme, "https", city.name) }
        }
    }

    // Every feed is https, so App Transport Security needs no exceptions
    func testAllFeedsAreHTTPSCampuses() {
        for (campus, feed) in CityLocation.City.campusEventFeeds {
            XCTAssertTrue(campus.isCampus, campus.name)
            switch feed.source {
            case .localist(let host): XCTAssertFalse(host.contains("/"), campus.name)
            case .ical(let url):      XCTAssertEqual(url.scheme, "https", campus.name)
            }
        }
    }
}
