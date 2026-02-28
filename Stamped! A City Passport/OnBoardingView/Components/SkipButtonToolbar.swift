//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI

struct SkipButtonToolbar: ToolbarContent {
    @ObservedObject var viewModel: OnboardingViewModel
    let isHighContrast: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if viewModel.currentPage < viewModel.steps.count - 1 {
                Button("Skip") {
                    viewModel.skip()
                    
                }
                .accessibilityLabel("Skip introduction")
                .accessibilityHint("Goes directly to the main app screen")
                .foregroundColor(Color.adventureOrange.opacity(isHighContrast ? 1.0 : 0.8))
                .fontWeight(isHighContrast ? .bold : .regular)
            }
        }
    }
}

#Preview {
    NavigationStack {
        Color.gray.ignoresSafeArea()
            .toolbar {
                SkipButtonToolbar(
                    viewModel: OnboardingViewModel(),
                    isHighContrast: false
                )
        }
    }
}
