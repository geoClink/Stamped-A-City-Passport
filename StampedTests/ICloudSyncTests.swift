//
//  ICloudSyncTests.swift
//  StampedTests
//
//  Tests for 2.10's item-by-item iCloud merge (ICloudListMerge) and for
//  what TripStore and CollegeListStore do with iCloud's data: trips and
//  schools saved before 2.10 are kept and shared, items made on two devices
//  are both kept, a removal sticks, and the newer edit of a trip wins.
//  iCloud's data is passed in directly, so no real iCloud account is needed.
//

import XCTest
@testable import Stamped_

// MARK: - ICloudListMerge

final class ICloudListMergeTests: XCTestCase {
    private let earlier = Date(timeIntervalSince1970: 1_000)
    private let later = Date(timeIntervalSince1970: 2_000)

    private func merge(
        local: [String], localLog: ListChangeLog = [:],
        cloud: [String], cloudLog: ListChangeLog = [:]
    ) -> (items: [String], log: ListChangeLog) {
        ICloudListMerge.merge(local: local, localLog: localLog, cloud: cloud, cloudLog: cloudLog, id: { $0 })
    }

    // Checks items only one device has are all kept (no logs = data from before 2.10)
    func testKeepsItemsFromBothSides() {
        let result = merge(local: ["A", "B"], cloud: ["B", "C"])
        XCTAssertEqual(Set(result.items), ["A", "B", "C"])
    }

    // Checks an item removed on another device is removed here too
    func testRemovalOnOtherDeviceSticks() {
        let result = merge(
            local: ["A", "B"],
            cloud: ["A"], cloudLog: ["B": ListChange(date: later, isRemoved: true)]
        )
        XCTAssertEqual(result.items, ["A"])
    }

    // Checks adding an item back after removing it wins over the older removal
    func testReAddAfterRemovalWins() {
        let result = merge(
            local: ["A"], localLog: ["A": ListChange(date: later, isRemoved: false)],
            cloud: [], cloudLog: ["A": ListChange(date: earlier, isRemoved: true)]
        )
        XCTAssertEqual(result.items, ["A"])
        XCTAssertEqual(result.log["A"]?.isRemoved, false)
    }

    // Checks the newer edit of an item both devices have wins, whichever side it's on
    func testNewerCopyWins() {
        struct Item: Equatable { let id: String; let name: String }
        let local = [Item(id: "1", name: "Local edit")]
        let cloud = [Item(id: "1", name: "Cloud edit")]

        let localNewer = ICloudListMerge.merge(
            local: local, localLog: ["1": ListChange(date: later, isRemoved: false)],
            cloud: cloud, cloudLog: ["1": ListChange(date: earlier, isRemoved: false)],
            id: \.id
        )
        XCTAssertEqual(localNewer.items.first?.name, "Local edit")

        let cloudNewer = ICloudListMerge.merge(
            local: local, localLog: ["1": ListChange(date: earlier, isRemoved: false)],
            cloud: cloud, cloudLog: ["1": ListChange(date: later, isRemoved: false)],
            id: \.id
        )
        XCTAssertEqual(cloudNewer.items.first?.name, "Cloud edit")
    }

    // Checks the order from the latest reorder wins, with the other side's extras at the end
    func testNewerOrderWins() {
        let result = merge(
            local: ["B", "A"], localLog: [ICloudListMerge.orderID: ListChange(date: later, isRemoved: false)],
            cloud: ["A", "B", "C"], cloudLog: [ICloudListMerge.orderID: ListChange(date: earlier, isRemoved: false)]
        )
        XCTAssertEqual(result.items, ["B", "A", "C"])
    }

    // Checks old removals are forgotten so the log doesn't grow forever
    func testOldRemovalsArePruned() {
        let now = Date()
        let old = now.addingTimeInterval(-ICloudListMerge.removalMemory - 60)
        let log = ICloudListMerge.recording("new", removed: false, in: ["gone": ListChange(date: old, isRemoved: true)], now: now)
        XCTAssertNil(log["gone"])
        XCTAssertNotNil(log["new"])
    }
}

// MARK: - TripStore

@MainActor
final class TripStoreSyncTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "TripStoreSyncTests"

    override func setUp() async throws {
        // A throwaway UserDefaults suite and no iCloud, so tests never touch real trips
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func encode(_ trips: [Trip]) -> Data {
        try! JSONEncoder().encode(trips)
    }

    // Checks trips saved by 2.9 (no change log) still load after updating
    func testLoadsTripsSavedBeforeChangeLog() {
        let old = Trip(name: "Old Trip", cityName: "Chicago")
        defaults.set(encode([old]), forKey: "GlobalTripsKey")

        let store = TripStore(defaults: defaults, iCloud: nil)
        XCTAssertEqual(store.trips.map(\.name), ["Old Trip"])
    }

    // Checks the first merge after updating keeps this device's trips and
    // adds the other device's, instead of iCloud's list replacing them
    func testFirstMergeKeepsLocalAndCloudTrips() {
        let local = Trip(name: "Made on iPhone", cityName: "Chicago")
        defaults.set(encode([local]), forKey: "GlobalTripsKey")
        let store = TripStore(defaults: defaults, iCloud: nil)

        let fromMac = Trip(name: "Made on Mac", cityName: "Boston")
        store.mergeCloud(tripsData: encode([fromMac]), changesData: nil)

        XCTAssertEqual(Set(store.trips.map(\.name)), ["Made on iPhone", "Made on Mac"])
    }

    // Checks nothing in iCloud yet leaves this device's trips alone
    func testEmptyCloudKeepsLocalTrips() {
        let store = TripStore(defaults: defaults, iCloud: nil)
        store.createTrip(name: "Mine", cityName: "Chicago")
        store.mergeCloud(tripsData: nil, changesData: nil)
        XCTAssertEqual(store.trips.map(\.name), ["Mine"])
    }

    // Checks a trip deleted on another device is deleted here, and that a
    // trip renamed here later than iCloud's copy keeps the new name
    func testDeleteFromOtherDeviceAndNewerLocalRename() throws {
        let store = TripStore(defaults: defaults, iCloud: nil)
        let keep = store.createTrip(name: "Keep", cityName: "Chicago")
        let doomed = store.createTrip(name: "Doomed", cityName: "Boston")
        store.renameTrip(keep.id, to: "Renamed here")

        // iCloud: an older copy of "Keep", and "Doomed" removed after it was made
        let removedLater = Date().addingTimeInterval(60)
        let cloudLog: ListChangeLog = [
            keep.id: ListChange(date: Date(timeIntervalSince1970: 0), isRemoved: false),
            doomed.id: ListChange(date: removedLater, isRemoved: true)
        ]
        store.mergeCloud(tripsData: encode([keep]), changesData: ICloudListMerge.encodeLog(cloudLog))

        XCTAssertEqual(store.trips.map(\.name), ["Renamed here"])
    }

    // Checks the merged trips are saved on this device, so they survive a relaunch
    func testMergedTripsAreSavedLocally() {
        let store = TripStore(defaults: defaults, iCloud: nil)
        store.mergeCloud(tripsData: encode([Trip(name: "From iPad", cityName: "Chicago")]), changesData: nil)

        let relaunched = TripStore(defaults: defaults, iCloud: nil)
        XCTAssertEqual(relaunched.trips.map(\.name), ["From iPad"])
    }

    // Checks signing in to a different iCloud account shows that account's trips
    // instead of mixing two people's trips together
    func testAccountChangeReplacesTrips() {
        let store = TripStore(defaults: defaults, iCloud: nil)
        store.createTrip(name: "First account", cityName: "Chicago")
        store.mergeCloud(tripsData: encode([Trip(name: "Second account", cityName: "Boston")]), changesData: nil, accountChanged: true)
        XCTAssertEqual(store.trips.map(\.name), ["Second account"])
    }
}

// MARK: - CollegeListStore

@MainActor
final class CollegeListSyncTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "CollegeListSyncTests"

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // Checks schools added on two devices are both kept, and one removed
    // on the other device after it was added here is removed
    func testMergesAddsAndRemovals() throws {
        let campuses = CityLocation.City.allCases.filter(\.isCampus)
        guard campuses.count >= 3 else { throw XCTSkip("Needs three campuses") }
        let (mine, theirs, removed) = (campuses[0], campuses[1], campuses[2])

        let store = CollegeListStore(defaults: defaults, iCloud: nil)
        store.add(mine)
        store.add(removed)

        let cloudLog: ListChangeLog = [removed.rawValue: ListChange(date: Date().addingTimeInterval(60), isRemoved: true)]
        store.mergeCloud(names: [theirs.rawValue], changesData: ICloudListMerge.encodeLog(cloudLog))

        XCTAssertEqual(Set(store.campuses), [mine, theirs])
    }
}

// MARK: - Want to Visit

/// Want to Visit hearts, merged landmark by landmark (GlobalProgressManager.mergedWishlist).
final class WishlistSyncTests: XCTestCase {
    private let earlier = Date(timeIntervalSince1970: 1_000)
    private let later = Date(timeIntervalSince1970: 2_000)

    private func merge(
        local: Set<String>, localLog: ListChangeLog = [:],
        cloud: Set<String>, cloudLog: ListChangeLog = [:]
    ) -> (ids: Set<String>, log: ListChangeLog) {
        GlobalProgressManager.mergedWishlist(local: local, localLog: localLog, cloud: cloud, cloudLog: cloudLog)
    }

    // The bug this fixes: a heart on the iPhone and a different heart on the iPad, before
    // either synced. The old "iCloud's list wins" lost one; now both are kept.
    func testHeartsOnTwoDevicesAreBothKept() {
        let result = merge(
            local: ["eiffel"], localLog: ["eiffel": ListChange(date: earlier, isRemoved: false)],
            cloud: ["colosseum"], cloudLog: ["colosseum": ListChange(date: later, isRemoved: false)]
        )
        XCTAssertEqual(result.ids, ["eiffel", "colosseum"])
    }

    // Un-hearting on another device removes the landmark here too
    func testUnheartOnOtherDeviceSticks() {
        let result = merge(
            local: ["eiffel", "colosseum"],
            cloud: ["eiffel"], cloudLog: ["colosseum": ListChange(date: later, isRemoved: true)]
        )
        XCTAssertEqual(result.ids, ["eiffel"])
    }

    // Hearting a landmark again here after another device un-hearted it wins, because it's newer
    func testHeartAgainAfterUnheartWins() {
        let result = merge(
            local: ["eiffel"], localLog: ["eiffel": ListChange(date: later, isRemoved: false)],
            cloud: [], cloudLog: ["eiffel": ListChange(date: earlier, isRemoved: true)]
        )
        XCTAssertEqual(result.ids, ["eiffel"])
        XCTAssertEqual(result.log["eiffel"]?.isRemoved, false)
    }

    // Lists saved by 2.9 have no change log: the first merge keeps every heart from both sides
    func testListsFromBeforeTheLogAreCombined() {
        let result = merge(local: ["eiffel", "pantheon"], cloud: ["pantheon", "colosseum"])
        XCTAssertEqual(result.ids, ["eiffel", "pantheon", "colosseum"])
    }

    // Both devices' logs end up in the merged log, so the next merge on any device agrees
    func testLogsFromBothDevicesAreCombined() {
        let result = merge(
            local: ["eiffel"], localLog: ["eiffel": ListChange(date: earlier, isRemoved: false)],
            cloud: [], cloudLog: ["colosseum": ListChange(date: later, isRemoved: true)]
        )
        XCTAssertEqual(Set(result.log.keys), ["eiffel", "colosseum"])
    }
}
