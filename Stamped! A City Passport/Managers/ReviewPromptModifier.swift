//
//  ReviewPromptModifier.swift
//  Stamped! A City Passport
//
//  Asks for an App Store rating right after a stamp completes a whole city or campus
//  (GlobalProgressManager.reviewMoment), the moment someone is happiest with the app.
//  `requestReview` only asks: Apple decides whether to show the prompt and limits it to
//  3 times a year, and the app asks at most once per version.
//

import StoreKit
import SwiftUI

struct ReviewPromptModifier: ViewModifier {
    @ObservedObject private var progress = GlobalProgressManager.shared
    @Environment(\.requestReview) private var requestReview

    func body(content: Content) -> some View {
        content
            .onChange(of: progress.reviewMoment) { _, moment in
                guard moment != nil else { return }
                Task {
                    // Let the stamp animation and the "city complete" moment play first
                    try? await Task.sleep(for: .seconds(2))
                    requestReview()
                }
            }
    }
}

/// Shows the tip jar once, after someone has collected a good number of stamps.
struct TipPromptModifier: ViewModifier {
    @ObservedObject private var progress = GlobalProgressManager.shared
    @State private var showsTipJar = false

    func body(content: Content) -> some View {
        content
            .onChange(of: progress.tipMoment) { _, moment in
                guard moment != nil else { return }
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    showsTipJar = true
                }
            }
            .sheet(isPresented: $showsTipJar) {
                NavigationStack {
                    TipJarView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Not Now") { showsTipJar = false }
                            }
                        }
                }
            }
    }
}

extension View {
    /// Offer the tip jar once, after a good number of stamps.
    func tipPromptAfterStamps() -> some View {
        modifier(TipPromptModifier())
    }

    /// Ask for an App Store rating when a stamp completes a city or campus.
    func reviewPromptAfterCompletingCity() -> some View {
        modifier(ReviewPromptModifier())
    }
}
