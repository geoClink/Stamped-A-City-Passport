//
//  HotelLinksTests.swift
//  StampedTests
//
//  Hotel search links: dates, affiliate IDs, encoding and destinations.
//  The affiliate ID is passed straight to HotelLinkBuilder, so the real
//  configuration (HotelPartner) is never changed by a test.
//

import XCTest
import CoreLocation
@testable import Stamped_

@MainActor
final class HotelLinksTests: XCTestCase {

    /// A fixed calendar so the day numbers don't depend on the test machine's time zone.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func builder(_ provider: HotelProvider, affiliateID: String? = nil) -> HotelLinkBuilder {
        HotelLinkBuilder(provider: provider, affiliateID: affiliateID, calendar: calendar)
    }

    /// The URL's query as name → value (decoded).
    private func query(_ url: URL?) throws -> [String: String] {
        let url = try XCTUnwrap(url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        var result: [String: String] = [:]
        for item in components.queryItems ?? [] {
            result[item.name] = item.value
        }
        return result
    }

    // MARK: Booking.com

    func testBookingWithoutDates() throws {
        let url = builder(.booking).url(for: HotelSearch(destination: "Duke University"))
        XCTAssertEqual(url?.absoluteString, "https://www.booking.com/searchresults.html?ss=Duke%20University")
    }

    func testBookingWithDatesAndCoordinate() throws {
        let search = HotelSearch(destination: "Duke University", latitude: 36.0014, longitude: -78.9382,
                                 checkIn: date(2026, 11, 10), checkOut: date(2026, 11, 12))
        let url = builder(.booking).url(for: search)
        XCTAssertEqual(url?.absoluteString,
                       "https://www.booking.com/searchresults.html?ss=Duke%20University&latitude=36.00140&longitude=-78.93820&checkin=2026-11-10&checkout=2026-11-12")
    }

    func testBookingPublisherIDWrapsTheSearchInACJDeepLink() throws {
        let search = HotelSearch(destination: "Paris, France")
        // No ID: a plain Booking.com search, no tracking
        let plain = try XCTUnwrap(builder(.booking).url(for: search))
        XCTAssertEqual(plain.host, "www.booking.com")
        XCTAssertFalse(builder(.booking).earnsCommission)

        // With our CJ publisher ID: a CJ click link through the deep-linkable ad,
        // carrying the whole Booking.com search as "url"
        let withID = builder(.booking, affiliateID: " 101916315 ")
        let tracked = try XCTUnwrap(withID.url(for: search))
        XCTAssertEqual(tracked.host, "www.tkqlhce.com")
        XCTAssertEqual(tracked.path, "/click-101916315-\(HotelPartner.bookingCJAdID)")
        XCTAssertEqual(try query(tracked)["url"], plain.absoluteString)
        XCTAssertTrue(withID.earnsCommission)

        // An empty ID counts as no ID
        XCTAssertEqual(try XCTUnwrap(builder(.booking, affiliateID: "  ").url(for: search)).host, "www.booking.com")
        XCTAssertFalse(builder(.booking, affiliateID: "").earnsCommission)
    }

    func testPlainLinkHasNoTrackingParameters() throws {
        let items = try query(builder(.booking).url(for: HotelSearch(destination: "Rome, Italy")))
        XCTAssertEqual(Set(items.keys), ["ss"])
    }

    // MARK: Expedia / Hotels.com

    func testExpediaWithDates() throws {
        let search = HotelSearch(destination: "University of Georgia", latitude: 33.9575, longitude: -83.3831,
                                 checkIn: date(2026, 11, 10), checkOut: date(2026, 11, 11))
        let url = builder(.expedia).url(for: search)
        XCTAssertEqual(url?.absoluteString,
                       "https://www.expedia.com/Hotel-Search?destination=University%20of%20Georgia&latLong=33.95750%2C-83.38310&startDate=2026-11-10&endDate=2026-11-11")
    }

    func testHotelsComWithoutDates() throws {
        let url = builder(.hotelsCom).url(for: HotelSearch(destination: "Tokyo, Japan"))
        XCTAssertEqual(url?.absoluteString, "https://www.hotels.com/Hotel-Search?destination=Tokyo%2C%20Japan")
    }

    func testExpediaCamrefWrapsTheSearchInAPartnerizeLink() throws {
        let search = HotelSearch(destination: "Boston, United States",
                                 checkIn: date(2026, 12, 4), checkOut: date(2026, 12, 6))
        let plain = try XCTUnwrap(builder(.expedia).url(for: search))
        XCTAssertFalse(builder(.expedia).earnsCommission)

        let tracked = builder(.expedia, affiliateID: " \(HotelPartner.expediaCamref) ")
        let url = try XCTUnwrap(tracked.url(for: search))
        XCTAssertTrue(tracked.earnsCommission)
        XCTAssertEqual(url.absoluteString,
                       "https://prf.hn/click/camref:1110lStp6/destination:" + HotelLinkBuilder.encode(plain.absoluteString))
        // The whole search link sits in one path segment, so its "?" and "&" are escaped
        XCTAssertNil(url.query)
    }

    func testHotelsComIgnoresAffiliateID() throws {
        // The Expedia camref doesn't cover Hotels.com, so an ID must not change the link
        let search = HotelSearch(destination: "Boston, United States")
        XCTAssertEqual(builder(.hotelsCom).url(for: search), builder(.hotelsCom, affiliateID: "abc").url(for: search))
        XCTAssertFalse(builder(.hotelsCom, affiliateID: "abc").earnsCommission)
    }

    // MARK: Click labels (Vision Pro)

    /// The Vision Pro app labels its Expedia clicks "vision" with Partnerize's pubref,
    /// placed before the destination so the search link itself is unchanged.
    func testClickLabelAddsPartnerizePubref() throws {
        let search = HotelSearch(destination: "Colosseum, Rome", latitude: 41.8902, longitude: 12.4922)
        let plain = try XCTUnwrap(builder(.expedia).url(for: search))
        let labelled = HotelLinkBuilder(provider: .expedia, affiliateID: "1110lStp6", calendar: calendar, clickLabel: "vision")
        XCTAssertEqual(try XCTUnwrap(labelled.url(for: search)).absoluteString,
                       "https://prf.hn/click/camref:1110lStp6/pubref:vision/destination:" + HotelLinkBuilder.encode(plain.absoluteString))
    }

    /// The Booking.com (CJ) link carries the label as "sid", and still the whole search as "url".
    func testClickLabelAddsCJSid() throws {
        let search = HotelSearch(destination: "Colosseum, Rome")
        let plain = try XCTUnwrap(builder(.booking).url(for: search))
        let labelled = HotelLinkBuilder(provider: .booking, affiliateID: "101916315", calendar: calendar, clickLabel: "vision")
        let url = try XCTUnwrap(labelled.url(for: search))
        XCTAssertEqual(url.path, "/click-101916315-\(HotelPartner.bookingCJAdID)")
        XCTAssertEqual(try query(url)["sid"], "vision")
        XCTAssertEqual(try query(url)["url"], plain.absoluteString)
    }

    /// Vrbo's Partnerize link gets the same pubref.
    func testVrboClickLabelAddsPubref() throws {
        let search = HotelSearch(destination: "Colosseum, Rome")
        let plain = try XCTUnwrap(VrboLinkBuilder(camref: "1100l6yuA7").url(for: search)).absoluteString
        let labelled = try XCTUnwrap(VrboLinkBuilder(camref: "1100l6yuA7", clickLabel: "vision").url(for: search)).absoluteString
        XCTAssertTrue(plain.hasPrefix("https://prf.hn/click/camref:1100l6yuA7/destination:"))
        XCTAssertEqual(labelled, plain.replacingOccurrences(of: "/destination:", with: "/pubref:vision/destination:"))
    }

    /// No label (the iPhone, iPad and Mac app) or a blank one leaves every link exactly as before.
    func testNoClickLabelLeavesLinksUnchanged() throws {
        let search = HotelSearch(destination: "Paris, France")
        for provider in [HotelProvider.expedia, .booking] {
            let id = provider == .expedia ? "1110lStp6" : "101916315"
            let unlabelled = HotelLinkBuilder(provider: provider, affiliateID: id, calendar: calendar)
            let blank = HotelLinkBuilder(provider: provider, affiliateID: id, calendar: calendar, clickLabel: "  ")
            let url = try XCTUnwrap(unlabelled.url(for: search)).absoluteString
            XCTAssertFalse(url.contains("pubref"))
            XCTAssertFalse(url.contains("sid="))
            XCTAssertEqual(blank.url(for: search)?.absoluteString, url)
        }
    }

    // MARK: Encoding

    func testDestinationIsPercentEncoded() throws {
        let search = HotelSearch(destination: "King's College London & Café+Bar = São Paulo/Zürich?")
        let url = try XCTUnwrap(builder(.booking).url(for: search))
        let raw = url.absoluteString
        XCTAssertFalse(raw.contains(" "))
        // "&", "=", "+", "?" and "/" inside the value must be escaped, or they'd split it up
        XCTAssertTrue(raw.hasPrefix("https://www.booking.com/searchresults.html?ss="))
        let value = String(raw.dropFirst("https://www.booking.com/searchresults.html?ss=".count))
        for reserved in ["&", "=", "+", "?", "/", "'"] {
            XCTAssertFalse(value.contains(reserved), "\(reserved) was not encoded")
        }
        // …and it decodes back to the same text
        XCTAssertEqual(value.removingPercentEncoding, search.destination)
        XCTAssertEqual(try query(url)["ss"], search.destination)
    }

    func testNonLatinDestination() throws {
        let search = HotelSearch(destination: "東京大学")
        XCTAssertEqual(try query(builder(.hotelsCom).url(for: search))["destination"], "東京大学")
    }

    // MARK: Dates

    func testCheckOutDefaultsToNextDay() throws {
        let search = HotelSearch(destination: "Athens, Greece", checkIn: date(2026, 12, 31, hour: 15))
        let dates = try XCTUnwrap(builder(.booking).stayDates(for: search))
        XCTAssertEqual(dates.checkIn, "2026-12-31")
        XCTAssertEqual(dates.checkOut, "2027-01-01")
    }

    func testCheckOutNotAfterCheckInBecomesNextDay() throws {
        let sameDay = HotelSearch(destination: "x", checkIn: date(2026, 3, 1), checkOut: date(2026, 3, 1, hour: 18))
        XCTAssertEqual(builder(.booking).stayDates(for: sameDay)?.checkOut, "2026-03-02")

        let before = HotelSearch(destination: "x", checkIn: date(2026, 3, 5), checkOut: date(2026, 3, 2))
        XCTAssertEqual(builder(.booking).stayDates(for: before)?.checkOut, "2026-03-06")
    }

    func testCheckOutIsAlwaysAfterCheckIn() throws {
        for offset in -3...5 {
            let checkIn = date(2026, 2, 27)
            let checkOut = calendar.date(byAdding: .day, value: offset, to: checkIn)!
            let dates = try XCTUnwrap(builder(.booking).stayDates(for: HotelSearch(destination: "x", checkIn: checkIn, checkOut: checkOut)))
            // yyyy-MM-dd strings sort in date order
            XCTAssertLessThan(dates.checkIn, dates.checkOut, "offset \(offset)")
        }
    }

    func testCheckOutWithoutCheckInMeansNoDates() throws {
        let search = HotelSearch(destination: "Lisbon, Portugal", checkOut: date(2026, 5, 2))
        XCTAssertNil(builder(.booking).stayDates(for: search))
        let items = try query(builder(.booking).url(for: search))
        XCTAssertNil(items["checkin"])
        XCTAssertNil(items["checkout"])
    }

    func testDatesUseGregorianDigits() throws {
        // A Japanese-calendar or Buddhist-calendar phone must still send 2026, not 8 or 2569
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = calendar.timeZone
        let search = HotelSearch(destination: "Bangkok, Thailand", checkIn: date(2026, 7, 4))
        let gregorian = HotelLinkBuilder.defaultCalendar
        XCTAssertEqual(gregorian.identifier, .gregorian)
        XCTAssertNotEqual(buddhist.component(.year, from: date(2026, 7, 4)), 2026)
        XCTAssertEqual(builder(.booking).stayDates(for: search)?.checkIn, "2026-07-04")
    }

    // MARK: Destinations

    func testCityAndCampusSearchNames() {
        XCTAssertEqual(CityLocation.City.paris.hotelSearchName, "Paris, France")
        XCTAssertEqual(CityLocation.City.minnesota.hotelSearchName, "Minneapolis, United States")
        XCTAssertEqual(CityLocation.City.hongKong.hotelSearchName, "Hong Kong")
        XCTAssertEqual(CityLocation.City.singapore.hotelSearchName, "Singapore")
        XCTAssertEqual(CityLocation.City.duke.hotelSearchName, "Duke University")
    }

    func testCitySearchCarriesCoordinate() throws {
        let search = HotelSearch(city: .uGeorgia)
        XCTAssertEqual(search.destination, "University of Georgia")
        XCTAssertEqual(try XCTUnwrap(search.latitude), CityLocation.City.uGeorgia.coordinate.lat, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(search.longitude), CityLocation.City.uGeorgia.coordinate.lon, accuracy: 0.0001)
    }

    func testStayMapCategoryShowsHotels() {
        XCTAssertTrue(MapCategory.allCases.contains(.stay))
        XCTAssertEqual(MapCategory.stay.icon, "bed.double.fill")
    }
}
