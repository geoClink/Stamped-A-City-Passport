//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//
import SwiftUI

public struct BackgroundLayer: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let isHighContrast: Bool
    let shouldReduceMotion: Bool

    public init(viewModel: OnboardingViewModel, isHighContrast: Bool, shouldReduceMotion: Bool) {
        self.viewModel = viewModel
        self.isHighContrast = isHighContrast
        self.shouldReduceMotion = shouldReduceMotion
    }

    public var body: some View {
        ZStack {
            if isHighContrast {
                Color.black
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [Color("adventureOrange").opacity(0.6), .black]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
        .animation(shouldReduceMotion ? .none : .easeInOut(duration: 0.8), value: viewModel.currentPage)
    }
}

