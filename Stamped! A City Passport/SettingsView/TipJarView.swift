//
//  TipJarView.swift
//  Stamped! A City Passport
//
//  "Support Stamped!": a note from George and three tip buttons (in-app purchases).
//  Opened from Settings on iPhone, iPad and Mac, and from the city list on Vision Pro.
//

import StoreKit
import SwiftUI

struct TipJarView: View {
    /// @Observable store: SwiftUI redraws when the properties read below change
    private let store = TipJarStore.shared
    /// Shows Apple's payment sheet for a product (see TipJarStore.buy)
    @Environment(\.purchase) private var purchase

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                statusMessage
                tipSection
                Text("Payments go through your Apple Account. Tips are one-time and don't renew.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Support Stamped!")
        .task {
            store.resetMessage()
            await store.loadTips()
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Hi, I'm George! I make Stamped! on my own as an indie developer. The app is free, and tips help me keep adding new cities and landmarks.")
                .multilineTextAlignment(.center)
            Text("Tips are just a thank-you. They don't unlock anything, and everything in the app stays free.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    /// Thank-you, Ask to Buy, cancelled or failed: one short card after a purchase
    @ViewBuilder
    private var statusMessage: some View {
        switch store.purchaseState {
        case .thanks:
            StatusCard(icon: "heart.fill", title: "Thank you!",
                       message: "Your tip means a lot. It helps bring the next city to Stamped!")
        case .pending:
            StatusCard(icon: "hourglass", title: "Waiting for approval",
                       message: "Your tip will go through once a family organizer approves it.")
        case .cancelled:
            StatusCard(icon: "xmark.circle", title: nil,
                       message: "No worries, the tip was cancelled. You weren't charged.")
        case .failed:
            StatusCard(icon: "exclamationmark.triangle", title: nil,
                       message: "That tip didn't go through. Please try again.")
        case .idle, .purchasing:
            EmptyView()
        }
    }

    @ViewBuilder
    private var tipSection: some View {
        switch store.loadState {
        case .loading:
            ProgressView("Loading tips…")
                .padding()
        case .unavailable:
            VStack(spacing: 12) {
                Text("Tips aren't available right now")
                    .font(.headline)
                Text("Please check your connection and try again later.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Task { await store.loadTips() }
                }
                .buttonStyle(.bordered)
            }
            .padding()
        case .ready:
            VStack(spacing: 12) {
                ForEach(store.tips) { product in
                    tipButton(for: product)
                }
            }
        }
    }

    private func tipButton(for product: Product) -> some View {
        let isBuyingThis = store.purchaseState == .purchasing(product.id)
        let isBuyingAny: Bool = {
            if case .purchasing = store.purchaseState { return true }
            return false
        }()

        return Button {
            Task { await store.buy(product, using: purchase) }
        } label: {
            HStack {
                Text(tipName(for: product))
                    .fontWeight(.semibold)
                Spacer()
                if isBuyingThis {
                    ProgressView()
                } else {
                    // Localized price from the App Store (never hard-coded)
                    Text(product.displayPrice)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(isBuyingAny)
    }

    /// The app's own translated name for each tip, so it doesn't depend on App Store Connect
    private func tipName(for product: Product) -> LocalizedStringKey {
        switch product.id {
        case TipJarStore.TipID.small: return "Small Tip"
        case TipJarStore.TipID.medium: return "Medium Tip"
        case TipJarStore.TipID.large: return "Large Tip"
        default: return LocalizedStringKey(product.displayName)
        }
    }
}

// MARK: - Status card

private struct StatusCard: View {
    let icon: String
    let title: LocalizedStringKey?
    let message: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                if let title {
                    Text(title).font(.headline)
                }
                Text(message)
                    .font(.subheadline)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { TipJarView() }
}
