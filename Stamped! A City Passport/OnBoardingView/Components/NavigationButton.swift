//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI

struct NavigationButton: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    // MARK: - Settings
    let isHighContrast: Bool
    let shouldReduceMotion: Bool
    
    var body: some View {
        Button(viewModel.isLastPage ? "Get Started" : "Next") {
            viewModel.nextPage(reduceMotion: shouldReduceMotion)
        }
        .buttonStyle(.borderedProminent)
        .tint(isHighContrast ? .white : Color.adventureOrange)
        .foregroundColor(isHighContrast ? .black : .white)
        .fontWeight(isHighContrast ? .black : .bold)
        .controlSize(.large)
        .padding()
        .hoverEffect(.lift)
    }
}
