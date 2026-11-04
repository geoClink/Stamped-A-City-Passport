//
//  TourStopsTests.swift
//  StampedTests
//
//  Checks that every city and campus has a guided tour that works. The tour isn't
//  stored anywhere: CityMapView (iPhone, iPad, Mac) and CityMapVisionView (Vision Pro)
//  build it from the place's landmarks that have coordinates. So a tour breaks
//  silently when a landmark has no coordinates (it drops out) or when two landmarks
//  share one spot (the camera flies to the same place twice).
//

import XCTest
import CoreLocation
@testable import Stamped_

final class TourStopsTests: XCTestCase {

    /// Two stops closer than this count as "the same spot"
    private let sameSpotMeters: CLLocationDistance = 5

    /// Pairs allowed to share a spot, with the reason. Sorted ids joined by "+".
    private let allowedSharedSpots: [String: String] = [
        // The Apple store is inside the tower
        "tlv_apple_sarona+tlv_sarona_tower": "same building",
        // Sharma Springs is a house on the Green School campus
        "bali-green-school+bali-sharma-springs": "same campus",
        // Not checked yet: OpenStreetMap had no match for these, so they still need real coordinates
        "cup_le_petit_trianon+cup_vpac_de_anza": "needs checking",
        "tng-al-adzhom+tng-boen-tek-bio": "needs checking",
        "pohang-03+pohang-09": "needs checking",
    ]

    /// Every city and campus, with its landmarks, from the JSON the app ships
    private func registry() throws -> [String: [Building]] {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "BuildingRegistry", withExtension: "json"),
                                "BuildingRegistry.json isn't in the app bundle")
        return try JSONDecoder().decode([String: [Building]].self, from: Data(contentsOf: url))
    }

    // Every landmark has a real latitude and longitude, so none drops out of its tour
    func testEveryLandmarkHasCoordinates() throws {
        var problems: [String] = []
        for (place, buildings) in try registry() {
            for building in buildings {
                guard let latitude = building.latitude, let longitude = building.longitude else {
                    problems.append("\(place): \(building.name) has no coordinates")
                    continue
                }
                if !CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                    || (latitude == 0 && longitude == 0) {
                    problems.append("\(place): \(building.name) has invalid coordinates \(latitude), \(longitude)")
                }
            }
        }
        XCTAssertTrue(problems.isEmpty, problems.sorted().joined(separator: "\n"))
    }

    // Every city and campus has at least 3 stops, so its tour has somewhere to go
    func testEveryPlaceHasEnoughStops() throws {
        let tooShort = try registry()
            .map { place, buildings in (place, buildings.filter { $0.latitude != nil && $0.longitude != nil }.count) }
            .filter { $0.1 < 3 }
            .map { "\($0.0) has only \($0.1) stops" }
        XCTAssertTrue(tooShort.isEmpty, tooShort.sorted().joined(separator: "\n"))
    }

    // No two stops in a place sit on the same spot, unless they're listed in allowedSharedSpots
    func testNoTwoStopsShareASpot() throws {
        var problems: [String] = []
        var allowedPairsSeen: Set<String> = []

        for (place, buildings) in try registry() {
            let stops = buildings.compactMap { building -> (Building, CLLocation)? in
                guard let latitude = building.latitude, let longitude = building.longitude else { return nil }
                return (building, CLLocation(latitude: latitude, longitude: longitude))
            }
            // Compare each pair of stops once
            for firstIndex in stops.indices {
                for secondIndex in stops.indices where secondIndex > firstIndex {
                    let (first, firstSpot) = stops[firstIndex]
                    let (second, secondSpot) = stops[secondIndex]
                    guard firstSpot.distance(from: secondSpot) < sameSpotMeters else { continue }

                    let pairKey = [first.id, second.id].sorted().joined(separator: "+")
                    if allowedSharedSpots[pairKey] != nil {
                        allowedPairsSeen.insert(pairKey)
                    } else {
                        problems.append("\(place): \(first.name) and \(second.name) share one spot")
                    }
                }
            }
        }
        XCTAssertTrue(problems.isEmpty, problems.sorted().joined(separator: "\n"))

        // Once a "needs checking" pair is fixed, take it off the list so the list stays honest
        let fixedButStillListed = Set(allowedSharedSpots.keys).subtracting(allowedPairsSeen)
        XCTAssertTrue(fixedButStillListed.isEmpty,
                      "No longer share a spot, remove from allowedSharedSpots: \(fixedButStillListed.sorted())")
    }
}
