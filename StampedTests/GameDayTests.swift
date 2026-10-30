//
//  GameDayTests.swift
//  StampedTests
//
//  Tests for the campus Game Day section: picking home games out of the events feed,
//  matching a seller's venue name to ours, and the CampusAthletics.json data.
//  No network: the events below are made up in the shape the sellers send.
//

import XCTest
@testable import Stamped_

@MainActor
final class GameDayTests: XCTestCase {

    private let msuVenues = ["Spartan Stadium", "Breslin Student Events Center", "Munn Ice Arena"]
    private let msuTeams = ["MSU", "Michigan State", "Spartans"]

    /// An event as Ticketmaster or SeatGeek would give it
    private func event(_ name: String, venue: String, category: TicketmasterEvent.EventCategory = .sports,
                       date: String = "Sat, Nov 8", start: Date? = nil, seller: String = "Ticketmaster") -> TicketmasterEvent {
        TicketmasterEvent(id: UUID().uuidString, name: name, date: date, time: "12:00 PM", venueName: venue,
                          category: category, priceRange: nil, ticketURL: URL(string: "https://example.com/tickets"),
                          imageURL: nil, sellerName: seller, startDate: start)
    }

    // MARK: - Home-game filter

    // A sports event at the stadium naming the school is a home game; a concert there,
    // or a game somewhere else, is not
    func testKeepsOnlySportsEventsAtHomeVenues() {
        let events = [
            event("Michigan State Spartans Football vs. Iowa Hawkeyes", venue: "Spartan Stadium"),
            event("Taylor Swift | The Eras Tour", venue: "Spartan Stadium", category: .music),
            event("Michigan State Spartans at Michigan Wolverines", venue: "Michigan Stadium"),
        ]
        let games = GameDayService.homeGames(from: events, venueNames: msuVenues, teamNames: msuTeams)
        XCTAssertEqual(games.map(\.name), ["Michigan State Spartans Football vs. Iowa Hawkeyes"])
    }

    // A sports event at our arena that isn't the school's game (a high-school final) is left out
    func testLeavesOutEventsThatDontNameTheSchool() {
        let events = [event("MHSAA Boys Basketball State Finals", venue: "Breslin Center")]
        XCTAssertTrue(GameDayService.homeGames(from: events, venueNames: msuVenues, teamNames: msuTeams).isEmpty)
    }

    // The same game from both sellers (or two venue searches) shows once
    func testDuplicatesShowOnce() {
        let events = [
            event("Michigan State Spartans Hockey vs. Notre Dame", venue: "Munn Ice Arena"),
            event("Michigan State Spartans Hockey vs. Notre Dame", venue: "Munn Ice Arena", seller: "SeatGeek"),
        ]
        XCTAssertEqual(GameDayService.homeGames(from: events, venueNames: msuVenues, teamNames: msuTeams).count, 1)
    }

    // Games come soonest first, whatever order the searches returned them in
    func testSortedSoonestFirst() {
        let later = event("Michigan State Basketball vs. Purdue", venue: "Breslin Center", date: "Sat, Jan 10", start: Date(timeIntervalSince1970: 2_000_000))
        let sooner = event("Michigan State Football vs. Indiana", venue: "Spartan Stadium", date: "Sat, Nov 1", start: Date(timeIntervalSince1970: 1_000_000))
        let games = GameDayService.homeGames(from: [later, sooner], venueNames: msuVenues, teamNames: msuTeams)
        XCTAssertEqual(games.map(\.name), [sooner.name, later.name])
    }

    // Each venue gets its next games first, so a week of volleyball at the arena
    // can't push the next football game off the list
    func testEveryVenueGetsItsNextGames() {
        let day: TimeInterval = 86_400
        let volleyball = (1...5).map { index in
            event("Michigan State Spartans Womens Volleyball vs. Team \(index)", venue: "Jack Breslin Arena",
                  date: "Day \(index)", start: Date(timeIntervalSince1970: Double(index) * day))
        }
        let football = event("Michigan State Spartans Football vs. Washington Huskies Football", venue: "Spartan Stadium-MI",
                             date: "Day 10", start: Date(timeIntervalSince1970: 10 * day))
        let games = GameDayService.homeGames(from: volleyball + [football], venueNames: msuVenues, teamNames: msuTeams)
        XCTAssertEqual(games.count, 3)
        XCTAssertEqual(games.last?.name, football.name)
    }

    // MARK: - Venue and team matching

    // Sellers use other venue names: Ticketmaster's "Jack Breslin Arena" is our "Breslin Student Events Center"
    func testSellerVenueNamesMatch() {
        XCTAssertTrue(GameDayService.isAtVenue("Jack Breslin Arena", venueNames: msuVenues))
        XCTAssertTrue(GameDayService.isAtVenue("Spartan Stadium-MI", venueNames: msuVenues))
        XCTAssertEqual(GameDayService.venueIndex("Munn Ice Arena", venueNames: msuVenues), 2)
        XCTAssertFalse(GameDayService.isAtVenue("Ford Field", venueNames: msuVenues))
        XCTAssertFalse(GameDayService.isAtVenue("", venueNames: msuVenues))
    }

    // A venue named only with generic words must match whole: "Memorial Stadium" isn't any stadium
    func testGenericVenueNameMustMatchWhole() {
        XCTAssertTrue(GameDayService.isAtVenue("Memorial Stadium", venueNames: ["Memorial Stadium"]))
        XCTAssertFalse(GameDayService.isAtVenue("Spartan Stadium", venueNames: ["Memorial Stadium"]))
    }

    // One search covers every venue: MSU's three venues sit within 1 km, so 2 km is enough
    func testSearchAreaReachesEveryVenue() {
        let venues = CityLocation.City.michiganState.gameDayVenues.map(\.coordinate)
        let (center, radiusKm) = GameDayService.searchArea(for: venues)
        XCTAssertEqual(radiusKm, 2)
        XCTAssertEqual(center.latitude, 42.728, accuracy: 0.01)
        XCTAssertEqual(center.longitude, -84.489, accuracy: 0.01)
    }

    // The school must be named as a whole word: "MSU" isn't found inside "MSUM"
    func testTeamNamesMatchWholeWords() {
        XCTAssertTrue(GameDayService.mentionsTeam("MSU Spartans vs. Iowa", teamNames: msuTeams))
        XCTAssertFalse(GameDayService.mentionsTeam("MSUM Dragons vs. Bemidji", teamNames: ["MSU"]))
    }

    // MARK: - Campus data

    // Michigan State's team names include its short name; real cities have no venues
    func testMichiganStateTeamNamesAndVenues() {
        XCTAssertTrue(CityLocation.City.michiganState.gameDayTeamNames.contains("Michigan State"))
        XCTAssertEqual(CityLocation.City.michiganState.gameDayVenues.map(\.name), msuVenues)
        XCTAssertTrue(CityLocation.City.detroit.gameDayVenues.isEmpty)
    }

    // Michigan State has the athletics site, three venue photos with credits, and 20 NCAA titles
    func testMichiganStateAthleticsData() throws {
        let athletics = try XCTUnwrap(CityLocation.City.michiganState.athletics)
        XCTAssertEqual(athletics.athleticsURL?.host, "msuspartans.com")
        let photos = (athletics.venues ?? []).compactMap(\.photo)
        XCTAssertEqual(photos.count, 3)
        for photo in photos {
            XCTAssertFalse(photo.author.isEmpty)
            XCTAssertFalse(photo.license.isEmpty)
        }
        let titles = try XCTUnwrap(athletics.championships?.titles)
        XCTAssertEqual(titles.reduce(0) { $0 + $1.years.count }, 20)
    }

    // Every entry in the data file is a real campus name, and every athletics link is https
    func testAthleticsFileMatchesCampuses() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "CampusAthletics", withExtension: "json"))
        let entries = CampusAthleticsStore.decode(try Data(contentsOf: url))
        XCTAssertFalse(entries.isEmpty, "CampusAthletics.json didn't decode")
        let campusNames = Set(CityLocation.City.campusCases.map(\.rawValue))
        for (name, athletics) in entries {
            XCTAssertTrue(campusNames.contains(name), "\(name) isn't a campus")
            if let link = athletics.athleticsURL {
                XCTAssertEqual(link.scheme, "https", "\(name)'s athletics link isn't https")
            }
        }
    }
}
