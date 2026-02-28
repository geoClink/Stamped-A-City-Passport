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
                
                VStack {
                    tabContent
                    
                    NavigationButton(
                        viewModel: viewModel,
                        isHighContrast: isHighContrast,
                        shouldReduceMotion: shouldReduceMotion
                    )
                }
            }
            .toolbar {
                SkipButtonToolbar(viewModel: viewModel, isHighContrast: isHighContrast)
            }
        }
    }
}

extension OnboardingView {
    var tabContent: some View {
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
    }
}

