//
//  EventsMergeTests.swift
//  StampedTests
//
//  Tests for joining Ticketmaster's and SeatGeek's events into one Upcoming Events list
//  (TicketmasterService.merged): the same event from both sellers shows once.
//  No network: the events below are made up in the shape the sellers send.
//

import XCTest
@testable import Stamped_

@MainActor
final class EventsMergeTests: XCTestCase {

    /// An event as Ticketmaster or SeatGeek would give it
    private func event(_ name: String, venue: String, date: String = "Fri, Oct 30", time: String = "6:00 PM",
                       seller: String = "Ticketmaster") -> TicketmasterEvent {
        TicketmasterEvent(id: UUID().uuidString, name: name, date: date, time: time, venueName: venue,
                          category: .sports, priceRange: nil, ticketURL: URL(string: "https://example.com/tickets"),
                          imageURL: nil, sellerName: seller)
    }

    // The same title on the same day is one event (what the merge already caught)
    func testSameTitleShowsOnce() {
        let ticketmaster = [event("Michigan State Spartans Hockey vs. Notre Dame", venue: "Munn Ice Arena")]
        let seatGeek = [event("Michigan State Spartans Hockey vs. Notre Dame", venue: "Munn Ice Arena", seller: "SeatGeek")]
        XCTAssertEqual(TicketmasterService.merged(ticketmaster, seatGeek, limit: 10).count, 1)
    }

    // The real MSU volleyball match: different titles and venue names, same arena, day and time.
    // Ticketmaster's listing is the one kept.
    func testSameEventWithDifferentTitlesShowsOnce() {
        let ticketmaster = [event("Michigan State Spartans Womens Volleyball vs. Indiana Hoosiers Womens Volleyball", venue: "Jack Breslin Arena")]
        let seatGeek = [event("Indiana Hoosiers at Michigan State Spartans Womens Volleyball", venue: "Jack Breslin Student Events Center", seller: "SeatGeek")]
        let merged = TicketmasterService.merged(ticketmaster, seatGeek, limit: 10)
        XCTAssertEqual(merged.map(\.sellerName), ["Ticketmaster"])
    }

    // Two different events at the same venue and day but different times both stay
    func testDifferentTimesAtSameVenueBothShow() {
        let ticketmaster = [event("Michigan State Spartans Womens Volleyball vs. Indiana", venue: "Jack Breslin Arena", time: "1:00 PM")]
        let seatGeek = [event("MSU Men's Basketball Exhibition", venue: "Breslin Center", time: "7:00 PM", seller: "SeatGeek")]
        XCTAssertEqual(TicketmasterService.merged(ticketmaster, seatGeek, limit: 10).count, 2)
    }

    // Same day and time at two different venues is two events
    func testSameTimeAtDifferentVenuesBothShow() {
        let ticketmaster = [event("Michigan State Spartans Hockey vs. Penn State", venue: "Munn Ice Arena")]
        let seatGeek = [event("Lansing Symphony Orchestra", venue: "Wharton Center", seller: "SeatGeek")]
        XCTAssertEqual(TicketmasterService.merged(ticketmaster, seatGeek, limit: 10).count, 2)
    }
}
