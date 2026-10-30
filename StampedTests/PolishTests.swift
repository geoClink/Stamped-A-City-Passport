//
//  PolishTests.swift
//  StampedTests
//
//  Fixes found while capturing the 2.8 screenshots: repeat event time slots, Game Day titles
//  and venue names, and phone-sized Wikipedia photos.
//

import XCTest
@testable import Stamped_

@MainActor
final class PolishTests: XCTestCase {

    private func event(_ name: String, venue: String, time: String = "6:00 PM") -> TicketmasterEvent {
        TicketmasterEvent(id: UUID().uuidString, name: name, date: "Fri, Oct 30", time: time, venueName: venue,
                          category: .miscellaneous, priceRange: nil, ticketURL: nil, imageURL: nil)
    }

    // MARK: - Events

    // An exhibit's time slots and exact duplicates show once (the soonest); other events stay
    func testRepeatTimeSlotsShowOnce() {
        let events = [
            event("Balloon Museum | EmotionAir", venue: "The Fields Studios", time: "10:00 AM"),
            event("Balloon Museum | EmotionAir", venue: "The Fields Studios", time: "10:30 AM"),
            event("Balloon Museum | EmotionAir", venue: "The Fields Studios", time: "10:30 AM"),
            event("Taylor Tomlinson", venue: "The Den Theatre"),
        ]
        let kept = TicketmasterService.withoutRepeats(events)
        XCTAssertEqual(kept.map(\.time), ["10:00 AM", "6:00 PM"])
    }

    // The same show at two different venues is two events
    func testSameNameAtTwoVenuesStays() {
        let events = [event("Hamilton", venue: "CIBC Theatre"), event("Hamilton", venue: "Wharton Center")]
        XCTAssertEqual(TicketmasterService.withoutRepeats(events).count, 2)
    }

    // MARK: - Game Day titles

    func testSportPulledOutOfTitle() {
        let display = GameDayService.displayTitle("Michigan State Spartans Football vs. Washington Huskies Football")
        XCTAssertEqual(display.title, "Michigan State Spartans vs. Washington Huskies")
        XCTAssertEqual(display.sport, "Football")
    }

    // The fuller sport name wins, and "Mens Ice" isn't left on the team
    func testQualifiedSportName() {
        let display = GameDayService.displayTitle("Michigan State Spartans Hockey vs. Boston University Terriers Mens Ice Hockey")
        XCTAssertEqual(display.title, "Michigan State Spartans vs. Boston University Terriers")
        XCTAssertEqual(display.sport, "Mens Ice Hockey")
    }

    func testTwoWordSport() {
        let display = GameDayService.displayTitle("Michigan State Spartans Womens Volleyball vs. Indiana Hoosiers Womens Volleyball")
        XCTAssertEqual(display.title, "Michigan State Spartans vs. Indiana Hoosiers")
        XCTAssertEqual(display.sport, "Womens Volleyball")
    }

    // A title that doesn't repeat the sport is left alone
    func testTitleWithoutRepeatedSportUnchanged() {
        let name = "Indiana Hoosiers at Michigan State Spartans Womens Volleyball"
        XCTAssertEqual(GameDayService.displayTitle(name).title, name)
        XCTAssertNil(GameDayService.displayTitle(name).sport)
    }

    // Home games show our venue name, not the seller's
    func testHomeGameUsesOurVenueName() {
        let game = TicketmasterEvent(id: "1", name: "Michigan State Spartans Football vs. Iowa Hawkeyes Football",
                                     date: "Sat, Nov 14", time: "", venueName: "Spartan Stadium-MI", category: .sports,
                                     priceRange: nil, ticketURL: nil, imageURL: nil)
        let games = GameDayService.homeGames(from: [game], venueNames: ["Spartan Stadium"], teamNames: ["Michigan State"])
        XCTAssertEqual(games.first?.venueName, "Spartan Stadium")
    }

    // MARK: - Photos

    // A huge original is swapped for the 1,280 px thumbnail
    func testHugeOriginalUsesSizedThumbnail() {
        let url = WikimediaService.sizedPhotoURL(
            original: WikiImage(source: "https://upload.wikimedia.org/wikipedia/commons/a/a5/Chicago_River_ferry_b.jpg", width: 3736),
            thumbnail: WikiImage(source: "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Chicago_River_ferry_b.jpg/330px-Chicago_River_ferry_b.jpg", width: 330))
        XCTAssertEqual(url?.absoluteString, "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Chicago_River_ferry_b.jpg/1280px-Chicago_River_ferry_b.jpg")
    }

    // An original that's already small is used as it is
    func testSmallOriginalKept() {
        let original = "https://upload.wikimedia.org/wikipedia/commons/1/12/Small.jpg"
        let url = WikimediaService.sizedPhotoURL(
            original: WikiImage(source: original, width: 900),
            thumbnail: WikiImage(source: "https://upload.wikimedia.org/wikipedia/commons/thumb/1/12/Small.jpg/330px-Small.jpg", width: 330))
        XCTAssertEqual(url?.absoluteString, original)
    }
}
