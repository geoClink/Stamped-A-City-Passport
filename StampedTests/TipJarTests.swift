//
//  TipJarTests.swift
//  StampedTests
//
//  The "Support Stamped!" tip jar (TipJarStore). The first tests need no App Store;
//  the last two buy a tip in a local StoreKit test session (StoreKit/TipJar.storekit),
//  so no real money or App Store Connect setup is involved.
//

import StoreKit
import StoreKitTest
import XCTest
@testable import Stamped_

@MainActor
final class TipJarTests: XCTestCase {

    /// StoreKit/TipJar.storekit, found from this file's location in the repo
    private var storeKitFileURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()        // StampedTests/
            .deletingLastPathComponent()        // repo root
            .appendingPathComponent("StoreKit/TipJar.storekit")
    }

    // MARK: - No App Store needed

    // Three tips, no duplicates, and only characters App Store Connect accepts in a product ID
    // (letters, numbers, underscores and periods). The bundle ID can't be the prefix: it has hyphens.
    func testProductIDsAreValidForTheAppStore() {
        let ids = TipJarStore.TipID.all
        XCTAssertEqual(ids.count, 3)
        XCTAssertEqual(Set(ids).count, 3)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_."))
        for id in ids {
            XCTAssertTrue(id.unicodeScalars.allSatisfy { allowed.contains($0) }, id)
            XCTAssertTrue(id.hasPrefix(TipJarStore.TipID.prefix), id)
        }
    }

    // Tips are shown cheapest first, whatever order the App Store returns them in
    func testSortsCheapestFirst() {
        let prices: [Decimal] = [4.99, 0.99, 2.99]
        let sorted = TipJarStore.sortedByPrice(prices) { $0 }
        XCTAssertEqual(sorted, [0.99, 2.99, 4.99])
    }

    // The local StoreKit file has the same three IDs as the code (a typo would mean
    // "Tips aren't available" in local testing)
    func testStoreKitFileMatchesProductIDs() throws {
        let data = try Data(contentsOf: storeKitFileURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let products = try XCTUnwrap(json["products"] as? [[String: Any]])
        let ids = products.compactMap { $0["productID"] as? String }
        XCTAssertEqual(Set(ids), Set(TipJarStore.TipID.all))
        XCTAssertTrue(products.allSatisfy { $0["type"] as? String == "Consumable" })
    }

    // MARK: - Local StoreKit test session

    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(contentsOf: storeKitFileURL)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true   // auto-confirm the payment sheet
        return session
    }

    // Loads the tips, buys the small one, finishes it and shows the thank-you
    func testBuyingATipFinishesItAndSaysThanks() async throws {
        let session = try makeSession()
        let store = TipJarStore.shared

        await store.loadTips()
        XCTAssertEqual(store.loadState, .ready)
        XCTAssertEqual(store.tips.map(\.id), TipJarStore.TipID.all)   // cheapest first
        // XCTUnwrap instead of tips[0]: an empty list fails this test instead of crashing the run
        let smallTip = try XCTUnwrap(store.tips.first)
        XCTAssertFalse(smallTip.displayPrice.isEmpty)

        let result = try await smallTip.purchase()
        await store.handle(result)
        XCTAssertEqual(store.purchaseState, .thanks)

        // Finished means the App Store won't deliver it again
        var unfinished = 0
        for await _ in StoreKit.Transaction.unfinished { unfinished += 1 }
        XCTAssertEqual(unfinished, 0)
        XCTAssertEqual(session.allTransactions().count, 1)
    }

    // Ask to Buy: the purchase waits for a parent, and the jar says so
    func testAskToBuyShowsPending() async throws {
        let session = try makeSession()
        session.askToBuyEnabled = true
        let store = TipJarStore.shared

        await store.loadTips()
        let product = try XCTUnwrap(store.tips.first)
        let result = try await product.purchase()
        await store.handle(result)
        XCTAssertEqual(store.purchaseState, .pending)
    }
}
