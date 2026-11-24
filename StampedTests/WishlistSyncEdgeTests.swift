//
//  WishlistSyncEdgeTests.swift
//  StampedTests
//
//  More Want to Visit sync cases, on top of WishlistSyncTests in ICloudSyncTests.swift:
//  what the Vision Pro app writes, damaged iCloud data, and ties. They call the
//  pure merge (GlobalProgressManager.mergedWishlist), so no iCloud is touched.
//

import XCTest
@testable import Stamped_

final class WishlistSyncEdgeTests: XCTestCase {
    private let earlier = Date(timeIntervalSince1970: 1_000)
    private let later = Date(timeIntervalSince1970: 2_000)

    private func merge(
        local: Set<String>, localLog: ListChangeLog = [:],
        cloud: Set<String>, cloudLog: ListChangeLog = [:]
    ) -> Set<String> {
        GlobalProgressManager.mergedWishlist(local: local, localLog: localLog, cloud: cloud, cloudLog: cloudLog).ids
    }

    // An un-heart made on Vision Pro (VisionStore logs it with ICloudListMerge.recording)
    // removes the landmark on iPhone too, instead of iPhone putting it back
    func testUnheartFromVisionProIsKept() {
        let visionLog = ICloudListMerge.recording("eiffel", removed: true, in: [:], now: later)
        let result = merge(
            local: ["eiffel", "colosseum"], localLog: ["eiffel": ListChange(date: earlier, isRemoved: false)],
            cloud: ["colosseum"], cloudLog: visionLog
        )
        XCTAssertEqual(result, ["colosseum"])
    }

    // A damaged change log in iCloud reads as "no log", so it never deletes hearts
    func testDamagedCloudLogKeepsEveryHeart() {
        let damaged = ICloudListMerge.decodeLog(Data("not json".utf8))
        XCTAssertTrue(damaged.isEmpty)
        XCTAssertEqual(merge(local: ["eiffel"], cloud: ["colosseum"], cloudLog: damaged), ["eiffel", "colosseum"])
    }

    // An empty iCloud list with no log (a new device) doesn't wipe this device's hearts
    func testEmptyCloudKeepsLocalHearts() {
        XCTAssertEqual(merge(local: ["eiffel", "pantheon"], cloud: []), ["eiffel", "pantheon"])
    }

    // Hearting on Vision Pro (logged, then the iPhone hasn't synced yet) adds it on iPhone at the next merge
    func testHeartFromVisionProIsAdded() {
        let visionLog = ICloudListMerge.recording("pantheon", removed: false, in: [:], now: later)
        XCTAssertEqual(merge(local: ["eiffel"], cloud: ["eiffel", "pantheon"], cloudLog: visionLog),
                       ["eiffel", "pantheon"])
    }
}
