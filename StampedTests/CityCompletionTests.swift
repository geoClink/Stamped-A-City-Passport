//
//  CityCompletionTests.swift
//  StampedTests
//
//  Checks the "City Explored!" celebration in CityDetailViewModel. Opening a city
//  you finished long ago must not replay the celebration or overwrite the saved
//  completion date with today; stamping the last landmark while the city is open must.
//

import XCTest
@testable import Stamped_

@MainActor
final class CityCompletionTests: XCTestCase {

    private let manager = GlobalProgressManager.shared
    private var savedVisited: Set<String> = []
    private var savedDate: String?
    private var city: CityLocation.City!

    private var dateKey: String { "date_completed_\(city.name)" }

    override func setUp() async throws {
        city = try XCTUnwrap(CityLocation.City.allCases.first { $0.buildings.count >= 2 })
        // Remember the real values so the test leaves the app's data as it found it
        savedVisited = manager.visitedIDs
        savedDate = UserDefaults.standard.string(forKey: "date_completed_\(city.name)")
    }

    override func tearDown() async throws {
        manager.visitedIDs = savedVisited
        letSubscriptionsRun()  // let any view model still alive react before the date is put back
        UserDefaults.standard.set(savedDate, forKey: dateKey)
    }

    /// The view model hears about progress on the next run loop pass, so give it one.
    /// A view model from an earlier test can still be alive (its currency fetch Task
    /// holds it), so each test changes progress and runs this BEFORE writing the date.
    private func letSubscriptionsRun() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    }

    // An already-finished city: no celebration, and the old date stays
    func testOpeningFinishedCityKeepsDateAndDoesNotCelebrate() {
        let oldDate = "Jan 1, 2020"
        manager.visitedIDs.formUnion(city.buildings.map(\.id))
        letSubscriptionsRun()
        UserDefaults.standard.set(oldDate, forKey: dateKey)

        let viewModel = CityDetailViewModel(city: city)
        letSubscriptionsRun()

        XCTAssertFalse(viewModel.didJustComplete)
        XCTAssertEqual(viewModel.completionDate, oldDate)
        XCTAssertEqual(UserDefaults.standard.string(forKey: dateKey), oldDate)
    }

    // A finished city with no saved date (older data) gets one, still with no celebration
    func testFinishedCityWithoutDateIsBackfilledQuietly() {
        manager.visitedIDs.formUnion(city.buildings.map(\.id))
        letSubscriptionsRun()
        UserDefaults.standard.removeObject(forKey: dateKey)

        let viewModel = CityDetailViewModel(city: city)
        letSubscriptionsRun()

        XCTAssertFalse(viewModel.didJustComplete)
        XCTAssertFalse(viewModel.completionDate.isEmpty)
        XCTAssertEqual(UserDefaults.standard.string(forKey: dateKey), viewModel.completionDate)
    }

    // Stamping the last landmark while the city is open: celebrate and save a date
    func testStampingLastLandmarkWhileOpenCelebrates() throws {
        let ids = city.buildings.map(\.id)
        let last = try XCTUnwrap(ids.last)
        manager.visitedIDs.subtract(ids)
        manager.visitedIDs.formUnion(ids.dropLast())
        letSubscriptionsRun()
        UserDefaults.standard.removeObject(forKey: dateKey)

        let viewModel = CityDetailViewModel(city: city)
        letSubscriptionsRun()
        XCTAssertFalse(viewModel.didJustComplete, "Not finished yet, so nothing to celebrate")

        manager.visitedIDs.insert(last)
        letSubscriptionsRun()

        XCTAssertTrue(viewModel.didJustComplete)
        XCTAssertFalse(viewModel.completionDate.isEmpty)
        XCTAssertEqual(UserDefaults.standard.string(forKey: dateKey), viewModel.completionDate)
    }
}
