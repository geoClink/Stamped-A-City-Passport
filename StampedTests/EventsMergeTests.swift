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
                       category: TicketmasterEvent.EventCategory = .sports,
                       seller: String = "Ticketmaster") -> TicketmasterEvent {
        TicketmasterEvent(id: UUID().uuidString, name: name, date: date, time: time, venueName: venue,
                          category: category, priceRange: nil, ticketURL: URL(string: "https://example.com/tickets"),
                          imageURL: nil, sellerName: seller)
    }

    // An exhibit dated the day it opened, weeks ago, is left out; today's and undated events stay
    func testPastDatedEventsAreLeftOut() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func dated(_ start: Date?) -> TicketmasterEvent {
            TicketmasterEvent(id: UUID().uuidString, name: "Exhibit", date: "", time: "", venueName: "Museum",
                              category: .miscellaneous, priceRange: nil, ticketURL: nil, imageURL: nil, startDate: start)
        }
        XCTAssertFalse(TicketmasterService.isUpcoming(dated(now.addingTimeInterval(-30 * 86_400)), now: now))
        XCTAssertTrue(TicketmasterService.isUpcoming(dated(now), now: now))
        XCTAssertTrue(TicketmasterService.isUpcoming(dated(nil), now: now))
    }

    // MARK: - The short row (highlights)

    // A weekend of games can't fill the row: sports stop at the cap and the show still gets in
    func testRowCapsEachKindOfEvent() {
        let games = (1...10).map { event("Game \($0)", venue: "Stadium", time: "\($0):00 PM") }
        let show = event("Hamilton", venue: "Wharton Center", date: "Sat, Nov 14", category: .arts)
        let row = TicketmasterService.highlights(from: games + [show], limit: 6, perCategory: 4)
        XCTAssertEqual(row.filter { $0.category == .sports }.count, 4 + 1) // 4 by the cap, 1 filling the last spot
        XCTAssertTrue(row.contains { $0.name == "Hamilton" })
    }

    // When there's only one kind of event, the row still fills up, soonest first
    func testRowFillsUpWhenOnlyOneKind() {
        let games = (1...10).map { event("Game \($0)", venue: "Stadium", time: "\($0):00 PM") }
        let row = TicketmasterService.highlights(from: games, limit: 6, perCategory: 4)
        XCTAssertEqual(row.map(\.name), (1...6).map { "Game \($0)" })
    }

    // The row keeps date order even though capped events were skipped over
    func testRowStaysInDateOrder() {
        let events = [
            event("Game 1", venue: "Stadium"), event("Game 2", venue: "Stadium"),
            event("Game 3", venue: "Stadium"), event("Concert", venue: "Arena", category: .music),
        ]
        let row = TicketmasterService.highlights(from: events, limit: 3, perCategory: 1)
        XCTAssertEqual(row.map(\.name), ["Game 1", "Game 2", "Concert"])
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
