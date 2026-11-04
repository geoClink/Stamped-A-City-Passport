//
//  TipJarStore.swift
//  Stamped! A City Passport
//
//  The "Support Stamped!" tip jar: three consumable in-app purchases (StoreKit 2).
//  Tips are a thank-you only. They unlock nothing, so there's nothing to save or restore.
//  Shared by the iPhone/iPad/Mac app and the Vision Pro app (same bundle ID, same products).
//

import Foundation
import Observation
import StoreKit
import SwiftUI   // for PurchaseAction, SwiftUI's way to show the payment sheet

@MainActor
@Observable
final class TipJarStore {
    static let shared = TipJarStore()

    /// Product IDs, exactly as they are set up in App Store Connect (and in TipJar.storekit)
    enum TipID {
        static let prefix = "name.GeorgeClinkscales.Stamped.tip."
        static let small = prefix + "small"
        static let medium = prefix + "medium"
        static let large = prefix + "large"
        static let all = [small, medium, large]
    }

    enum LoadState: Equatable {
        case loading
        case ready
        /// No products came back (not set up in App Store Connect yet, or no connection)
        case unavailable
    }

    enum PurchaseState: Equatable {
        case idle
        /// Waiting for the App Store sheet; holds the product ID that was tapped
        case purchasing(String)
        case thanks
        /// Ask to Buy: a family organizer has to approve it first
        case pending
        case cancelled
        case failed
    }

    /// The tips, cheapest first
    private(set) var tips: [Product] = []
    private(set) var loadState: LoadState = .loading
    private(set) var purchaseState: PurchaseState = .idle

    private var updatesTask: Task<Void, Never>?

    private init() {}

    // MARK: - Launch

    /// Call once at app launch. `Transaction.updates` delivers purchases that finished
    /// outside the buy button: an Ask to Buy approval, or a purchase interrupted by the
    /// app closing. Each one has to be finished, or the App Store keeps sending it.
    func listenForTransactions() {
        guard updatesTask == nil else { return }
        updatesTask = Task {
            for await result in StoreKit.Transaction.updates {
                await handleUpdate(result)
            }
        }
    }

    private func handleUpdate(_ result: VerificationResult<StoreKit.Transaction>) async {
        // Only trust transactions StoreKit could verify (signed by the App Store for this app)
        guard case .verified(let transaction) = result,
              TipID.all.contains(transaction.productID) else { return }
        await transaction.finish()
        purchaseState = .thanks
    }

    // MARK: - Products

    /// Ask the App Store for the three tips. Prices come back localized (`displayPrice`).
    func loadTips() async {
        loadState = .loading
        do {
            let products = try await Product.products(for: TipID.all)
            tips = Self.sortedByPrice(products) { $0.price }
            loadState = tips.isEmpty ? .unavailable : .ready
        } catch {
            loadState = .unavailable
        }
    }

    /// Cheapest first. Takes a closure for the price so tests can sort plain values
    /// without needing real App Store products.
    static func sortedByPrice<Item>(_ items: [Item], price: (Item) -> Decimal) -> [Item] {
        items.sorted { price($0) < price($1) }
    }

    // MARK: - Buying

    /// Buy a tip. `purchase` is SwiftUI's `@Environment(\.purchase)`: it calls
    /// `product.purchase()` and shows Apple's payment sheet in the right window
    /// (Vision Pro and Mac need to know which window to show it in).
    func buy(_ product: Product, using purchase: PurchaseAction) async {
        purchaseState = .purchasing(product.id)
        do {
            let result = try await purchase(product)
            await handle(result)
        } catch {
            purchaseState = .failed
        }
    }

    /// What happened after the payment sheet closed
    func handle(_ result: Product.PurchaseResult) async {
        switch result {
        case .success(let verification):
            // 1. Check that the App Store signed this transaction
            guard case .verified(let transaction) = verification else {
                purchaseState = .failed
                return
            }
            // 2. Nothing to unlock for a tip, so finish it right away.
            //    (A consumable that isn't finished is delivered again on every launch.)
            await transaction.finish()
            purchaseState = .thanks
        case .pending:
            purchaseState = .pending
        case .userCancelled:
            purchaseState = .cancelled
        @unknown default:
            purchaseState = .idle
        }
    }

    /// Clears the last message (thank-you, cancelled...) when the tip jar opens again
    func resetMessage() {
        if case .purchasing = purchaseState { return }
        purchaseState = .idle
    }
}
