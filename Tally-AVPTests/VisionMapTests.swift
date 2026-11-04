//
//  VisionMapTests.swift
//  Tally-AVPTests
//
//  Checks the city map's Play Tour order and the landmark data the Vision app loads.
//

import Testing
@testable import Tally_AVP

@MainActor
struct VisionMapTests {

    /// A landmark at a given spot; the other fields don't matter to these tests.
    private func landmark(_ id: String, latitude: Double?, longitude: Double?) -> Building {
        Building(id: id, name: id, assetName: "", description: "", architect: "",
                 yearBuilt: 0, address: "", oldUse: "", newUse: "", buildingStyle: "",
                 numberOfStories: 0, height: 0, foodSpots: [], currency: "",
                 latitude: latitude, longitude: longitude)
    }

    // MARK: Play Tour order

    /// No landmarks: an empty tour, not a crash.
    @Test func emptyCityHasEmptyTour() {
        #expect(CityMapVisionView.tourOrder([]).isEmpty)
    }

    /// Landmarks without coordinates can't be flown to, so they're left out.
    @Test func tourSkipsLandmarksWithoutCoordinates() {
        let tour = CityMapVisionView.tourOrder([
            landmark("pinned", latitude: 40, longitude: -74),
            landmark("no-pin", latitude: nil, longitude: nil),
        ])
        #expect(tour.map(\.id) == ["pinned"])
    }

    /// Four landmarks along a line (on the equator, so degrees compare evenly).
    /// The middle of the four is at 0.018, nearest to mid-east, so the tour starts
    /// there, then always walks to the nearest landmark it hasn't visited.
    @Test func tourWalksToTheNearestLandmarkEachTime() {
        let west = landmark("west", latitude: 0, longitude: 0)
        let midWest = landmark("mid-west", latitude: 0, longitude: 0.010)
        let midEast = landmark("mid-east", latitude: 0, longitude: 0.022)
        let east = landmark("east", latitude: 0, longitude: 0.040)

        let tour = CityMapVisionView.tourOrder([east, west, midEast, midWest]).map(\.id)

        // mid-east → mid-west (0.012 away, closer than east's 0.018) → west → east
        #expect(tour == ["mid-east", "mid-west", "west", "east"])
    }

    // MARK: Landmark data

    /// The bundled registry loads, and the city list is in alphabetical order.
    @Test func citiesLoadInAlphabeticalOrder() {
        let cities = VisionStore.shared.cityNames
        #expect(!cities.isEmpty)
        #expect(cities == cities.sorted())
    }

    /// The main window opens on New York, so it must have landmarks to show.
    @Test func newYorkHasLandmarks() {
        #expect(!VisionStore.shared.buildings(for: "New York").isEmpty)
    }

    /// An unknown city gives no landmarks instead of crashing.
    @Test func unknownCityHasNoLandmarks() {
        #expect(VisionStore.shared.buildings(for: "Atlantis").isEmpty)
        #expect(VisionStore.shared.visitedCount(for: "Atlantis") == 0)
    }
}
