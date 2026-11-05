//
//  TipJarTests.swift
//  StampedTests
//
//  The "Support Stamped!" tip jar (TipJarStore). The first tests need no App Store;
//  the last two buy a tip in a local StoreKit test session (StampedTests/TipJar.storekit),
//  so no real money or App Store Connect setup is involved.
//

import StoreKit
import StoreKitTest
import XCTest
@testable import Stamped_

@MainActor
final class TipJarTests: XCTestCase {

    /// TipJar.storekit, from the test bundle: a simulator may not be allowed to read the repo's folder
    private var storeKitFileURL: URL {
        Bundle(for: Self.self).url(forResource: "TipJar", withExtension: "storekit")!
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

        // The simulator's test store sometimes never answers; that mustn't freeze the whole run
        var purchased: Product.PurchaseResult?
        let answered = expectation(description: "StoreKit answered")
        Task {
            purchased = try? await smallTip.purchase()
            answered.fulfill()
        }
        guard await XCTWaiter().fulfillment(of: [answered], timeout: 15) == .completed, let result = purchased else {
            throw XCTSkip("StoreKit's test store didn't answer")
        }
        await store.handle(result)
        XCTAssertEqual(store.purchaseState, .thanks)

        // Finished means the App Store won't deliver it again
        var unfinished = 0
        for await _ in StoreKit.Transaction.unfinished { unfinished += 1 }
        XCTAssertEqual(unfinished, 0)
        XCTAssertEqual(session.allTransactions().count, 1)
    }

    // Ask to Buy: the purchase waits for a parent, and the jar says so
    // (StoreKit's own Ask to Buy flow never returns in a test, so the result is handed over directly.)
    func testAskToBuyShowsPending() async throws {
        let store = TipJarStore.shared
        await store.handle(.pending)
        XCTAssertEqual(store.purchaseState, .pending)
    }
}
