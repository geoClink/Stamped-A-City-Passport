//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

/*
 🏛️ WELCOME TO STAMPED! — DEVELOPER NOTE
 --------------------------------------
 My app solves "architectural blindness" through gamified discovery.
 
 HOW TO REVIEW:
 1. After you complete the onboarding flow.
 2. You will be immediately transported to San Francisco.
 3. I have pre-filled your progress so there is only ONE landmark
    left to unlock (the only place that does not have the orange checkmark.seal).
 
 4. Mark that landmark as "visited" to earn your first stamp
    and witness the custom "Stamp Success" animation!
*/

import SwiftUI

struct OnboardingView: View {
    @StateObject var viewModel = OnboardingViewModel()
    
    @EnvironmentObject var navManager: NavigationManager
    
    @Environment(\.accessibilityReduceMotion) var systemReduceMotion
    @Environment(\.colorSchemeContrast) var systemContrast
    @AppStorage("high_contrast_mode") var manualHighContrast = false
    @AppStorage("reduce_motion") var manualReduceMotion = false
    @AppStorage("haptics_enabled") var hapticsEnabled = true
    
    var isHighContrast: Bool { manualHighContrast || systemContrast == .increased }
    var shouldReduceMotion: Bool { manualReduceMotion || systemReduceMotion }

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundLayer(
                    viewModel: viewModel,
                    isHighContrast: isHighContrast,
                    shouldReduceMotion: shouldReduceMotion
                )
                
                VStack(spacing: 0) {
                    // Skip lives in the page itself rather than an empty, transparent
                    // navigation bar, so nothing sits on top of it and eats its taps
                    SkipButton(viewModel: viewModel, isHighContrast: isHighContrast)

                    tabContent

                    NavigationButton(
                        viewModel: viewModel,
                        isHighContrast: isHighContrast,
                        shouldReduceMotion: shouldReduceMotion
                    )
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

extension OnboardingView {
    var tabContent: some View {
        #if os(macOS)
        // No swipeable page style on the Mac: show the current step; the buttons move between steps.
        OnboardingStep(
            data: viewModel.steps[viewModel.currentPage],
            isHighContrast: isHighContrast
        )
        .id(viewModel.currentPage)
        .transition(.opacity)
        #else
        TabView(selection: $viewModel.currentPage) {
            ForEach(0..<viewModel.steps.count, id: \.self) { index in
                OnboardingStep(
                    data: viewModel.steps[index],
                    isHighContrast: isHighContrast
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        #endif
    }
}

