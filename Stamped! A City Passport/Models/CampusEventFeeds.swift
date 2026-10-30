//
//  CampusEventFeeds.swift
//  Stamped! A City Passport
//
//  Which campuses have a public events calendar the app can read, and where it is.
//  CampusEventsService fetches from here; campuses not listed show no Campus Events section.
//
//  To add a school: check it publishes a public feed (no key, no HTML scraping), then add
//  one line below. Most US schools run Localist: try https://<host>/api/2/events?pp=5 in a browser.
//

import Foundation

/// Where a campus publishes its events.
enum CampusEventSource: Equatable {
    /// A Localist calendar's public read API, e.g. host "events.purdue.edu".
    case localist(host: String)
    /// An iCalendar (.ics) subscription feed.
    case ical(url: URL)
}

/// One campus's events calendar.
struct CampusEventFeed: Equatable {
    let source: CampusEventSource
    /// The calendar's name in the credit line "From the <name> calendar", e.g. "Purdue events".
    let calendarName: String
}

extension CityLocation.City {
    /// The campus's public events calendar, or nil when it has none the app can read.
    var campusEventFeed: CampusEventFeed? { Self.campusEventFeeds[self] }

    /// Campus → events calendar. Every feed is https and needs no API key.
    static let campusEventFeeds: [CityLocation.City: CampusEventFeed] = [
        // Michigan State's central calendar is mid-migration; the Libraries' LibCal feed is public.
        .michiganState: CampusEventFeed(
            source: .ical(url: URL(string: "https://bookings.lib.msu.edu/ical_subscribe.php?src=p&cid=3079")!),
            calendarName: "MSU Libraries"
        ),
        .purdue:              CampusEventFeed(source: .localist(host: "events.purdue.edu"), calendarName: "Purdue events"),
        .uSouthernCalifornia: CampusEventFeed(source: .localist(host: "calendar.usc.edu"), calendarName: "USC events"),
        .uOregon:             CampusEventFeed(source: .localist(host: "calendar.uoregon.edu"), calendarName: "University of Oregon events"),
        .stanford:            CampusEventFeed(source: .localist(host: "events.stanford.edu"), calendarName: "Stanford events"),
        .yale:                CampusEventFeed(source: .localist(host: "events.yale.edu"), calendarName: "Yale events"),
        .cornell:             CampusEventFeed(source: .localist(host: "events.cornell.edu"), calendarName: "Cornell events"),
        .utAustin:            CampusEventFeed(source: .localist(host: "calendar.utexas.edu"), calendarName: "UT Austin events"),
        .uAlabama:            CampusEventFeed(source: .localist(host: "calendar.ua.edu"), calendarName: "University of Alabama events"),
        .uGeorgia:            CampusEventFeed(source: .localist(host: "calendar.uga.edu"), calendarName: "UGA events"),
        .uncChapelHill:       CampusEventFeed(source: .localist(host: "calendar.unc.edu"), calendarName: "UNC events"),
    ]
}
