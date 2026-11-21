//
//  ThenNowFilterTests.swift
//  StampedTests
//
//  The map's "Then & Now Photos" filter relies on a cheap check for bundled historic photos.
//

import XCTest
@testable import Stamped_

final class ThenNowFilterTests: XCTestCase {
    func testLandmarkWithBundledPhotoIsFound() {
        XCTAssertTrue(CampusArchivePhotos.hasPhotos(forBuildingID: "detroit_guardian"))
    }

    func testBuildingWithoutPhotoIsNot() {
        XCTAssertFalse(CampusArchivePhotos.hasPhotos(forBuildingID: "apple_store_nonexistent"))
        XCTAssertFalse(CampusArchivePhotos.hasPhotos(forBuildingID: ""))
    }
}
