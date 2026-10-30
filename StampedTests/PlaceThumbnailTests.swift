//
//  PlaceThumbnailTests.swift
//  StampedTests
//
//  The restaurant/hotel card thumbnail: which icon and color each kind of
//  place gets when Apple has no Look Around picture, and the cache key that
//  stops the same place's snapshot from being fetched twice.
//

import XCTest
import SwiftUI
import MapKit
@testable import Stamped_

@MainActor
final class PlaceThumbnailTests: XCTestCase {

    // MARK: - Icon per category

    /// Every Apple Maps category the cards show maps to its own symbol.
    func testEachCategoryGetsItsSymbol() {
        let expected: [(MKPointOfInterestCategory, String)] = [
            (.restaurant, "fork.knife"),
            (.cafe, "cup.and.saucer.fill"),
            (.bakery, "birthday.cake.fill"),
            (.nightlife, "wineglass.fill"),
            (.brewery, "mug.fill"),
            (.winery, "wineglass"),
            (.foodMarket, "basket.fill"),
            (.hotel, "bed.double.fill"),
        ]
        for (category, symbol) in expected {
            XCTAssertEqual(PlaceThumbnailKind(category: category).symbol, symbol, "\(category.rawValue)")
        }
    }

    /// No category, or one the cards don't have an icon for, falls back to a map pin.
    func testMissingOrUnknownCategoryUsesThePin() {
        XCTAssertEqual(PlaceThumbnailKind(category: nil), .other)
        XCTAssertEqual(PlaceThumbnailKind(category: nil).symbol, "mappin")
        XCTAssertEqual(PlaceThumbnailKind(category: .museum).symbol, "mappin")
    }

    /// Different kinds of place don't share a symbol, so they're easy to tell apart.
    func testSymbolsAreAllDifferent() {
        let kinds: [PlaceThumbnailKind] = [.restaurant, .cafe, .bakery, .bar, .brewery, .winery, .market, .hotel, .other]
        XCTAssertEqual(Set(kinds.map(\.symbol)).count, kinds.count)
    }

    /// High contrast drops the colors and uses the text color instead.
    func testHighContrastUsesPrimary() {
        XCTAssertEqual(PlaceThumbnailKind.hotel.tint(isHighContrast: true), .primary)
        XCTAssertEqual(PlaceThumbnailKind.hotel.tint(isHighContrast: false), .indigo)
        XCTAssertEqual(PlaceThumbnailKind.restaurant.tint(isHighContrast: false), .orange)
    }

    // MARK: - Cache key

    private let coffeeShop = CLLocationCoordinate2D(latitude: 42.331_43, longitude: -83.045_75)

    /// The same place asked for twice gives the same key, so the second card hits the cache.
    func testSamePlaceGivesSameKey() {
        let first = PlaceSnapshotCache.key(name: "Astro Coffee", coordinate: coffeeShop)
        let second = PlaceSnapshotCache.key(name: "Astro Coffee", coordinate: coffeeShop)
        XCTAssertEqual(first, second)
    }

    /// A difference far smaller than a meter (rounding noise between searches) still matches.
    func testTinyCoordinateNoiseGivesSameKey() {
        let nudged = CLLocationCoordinate2D(latitude: coffeeShop.latitude + 0.000_000_1,
                                            longitude: coffeeShop.longitude)
        XCTAssertEqual(PlaceSnapshotCache.key(name: "Astro Coffee", coordinate: coffeeShop),
                       PlaceSnapshotCache.key(name: "Astro Coffee", coordinate: nudged))
    }

    /// Two branches of a chain with the same name, a block apart, get different keys.
    func testDifferentCoordinatesGiveDifferentKeys() {
        let nextBlock = CLLocationCoordinate2D(latitude: coffeeShop.latitude + 0.001,
                                               longitude: coffeeShop.longitude)
        XCTAssertNotEqual(PlaceSnapshotCache.key(name: "Astro Coffee", coordinate: coffeeShop),
                          PlaceSnapshotCache.key(name: "Astro Coffee", coordinate: nextBlock))
    }

    /// The cache gives back what was stored, including "no imagery here".
    func testCacheRemembersNoImagery() {
        let cache = PlaceSnapshotCache()
        let key = PlaceSnapshotCache.key(name: "Nowhere", coordinate: coffeeShop)
        XCTAssertNil(cache.entry(for: key))
        cache.store(nil, for: key, size: .zero, scale: 2)
        let entry = cache.entry(for: key)
        XCTAssertNotNil(entry)
        XCTAssertNil(entry?.image)
    }
}
