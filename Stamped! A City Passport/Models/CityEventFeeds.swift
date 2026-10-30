//
//  CityEventFeeds.swift
//  Stamped! A City Passport
//
//  Which cities have an official public events calendar the app can read: the "Local Calendar"
//  section on a city page, next to the Ticketmaster/SeatGeek events. Library talks, museum
//  programs and civic festivals that ticket sellers never list. Same feed kinds and service as
//  campus calendars (CampusEventFeeds.swift, CampusEventsService).
//
//  Each feed was checked on 2026-10-29: https, no key, from the organisation itself, with
//  upcoming events in it. To add a city, the same rules as campuses apply (no HTML scraping).
//
//  LibCal library feeds: the plain feed starts about 30 days back and stops at 500 events, so for
//  a big library it can end before today. Adding `&cam=<location id>` (one branch, from the
//  location menu on the library's /calendar page) keeps it to upcoming events.
//

import Foundation

extension CityLocation.City {
    /// City → official public events calendar. Every feed is https and needs no API key.
    static let cityEventFeeds: [CityLocation.City: CampusEventFeed] = [
        // Public libraries (LibCal), each limited to its central branch with `cam`
        .denver: CampusEventFeed(
            source: .ical(url: URL(string: "https://denverlibrary.libcal.com/ical_subscribe.php?src=p&cid=20634&cam=8762")!),
            calendarName: "Denver Public Library"
        ),
        .houston: CampusEventFeed(
            source: .ical(url: URL(string: "https://calendar.houstonlibrary.org/ical_subscribe.php?src=p&cid=15272&cam=3618")!),
            calendarName: "Houston Public Library"
        ),
        .cleveland: CampusEventFeed(
            source: .ical(url: URL(string: "https://cpl.libcal.com/ical_subscribe.php?src=p&cid=8758&cam=4604")!),
            calendarName: "Cleveland Public Library"
        ),
        .buffalo: CampusEventFeed(
            source: .ical(url: URL(string: "https://buffalolib.libcal.com/ical_subscribe.php?src=p&cid=12898&cam=5195")!),
            calendarName: "Buffalo & Erie County Public Library"
        ),
        // Trumba calendars published by the organisations themselves
        .seattle: CampusEventFeed(
            source: .ical(url: URL(string: "https://www.trumba.com/calendars/kalendaro.ics")!),
            calendarName: "Seattle Public Library"
        ),
        // About 1,000 events across the Smithsonian museums; a handful are at its New York venues
        .washingtonDC: CampusEventFeed(
            source: .ical(url: URL(string: "https://www.trumba.com/calendars/smithsonian-events.ics")!),
            calendarName: "Smithsonian"
        ),
        .newYork: CampusEventFeed(
            source: .ical(url: URL(string: "https://www.trumba.com/calendars/frick2.ics")!),
            calendarName: "Frick Collection"
        ),
        .boston: CampusEventFeed(
            source: .ical(url: URL(string: "https://www.trumba.com/calendars/freedom_trail_foundation_events.ics")!),
            calendarName: "Freedom Trail Foundation"
        ),
        .vancouver: CampusEventFeed(
            source: .ical(url: URL(string: "https://www.trumba.com/calendars/city-of-vancouver-events.ics")!),
            calendarName: "City of Vancouver"
        ),
    ]
}
