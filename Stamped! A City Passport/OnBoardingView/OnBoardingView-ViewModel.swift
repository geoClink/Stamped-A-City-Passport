//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI
import Combine

@MainActor
public class OnboardingViewModel: ObservableObject {
    // MARK: - Published State
    @Published public var currentPage = 0
    @Published public var hasSeenOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenOnboarding, forKey: "hasSeenOnboarding")
        }
    }

    // MARK: - Properties
    public let steps: [OnboardingStepData] = [
        OnboardingStepData(
            image: "globe.americas.fill",
            title: "Explore the World",
            description: "Journey through architectural capitals to uncover hidden history."
        ),
        OnboardingStepData(
            image: "mappin.and.ellipse",
            title: "Track Your Progress",
            description: "Build your travel profile by documenting every landmark you visit."
        ),
        OnboardingStepData(
            image: "checkmark.seal.fill",
            title: "Claim Your Reward",
            description: "Unlock exclusive digital stamps for your personal Passport."
        ),
        OnboardingStepData(
            image: "brain.fill",
            title: "Prove Your Mastery",
            description: "Become an architectural expert by completing city-specific challenges."
        ),
        OnboardingStepData(
            image: "sparkles",
            title: "Curate with Intelligence",
            description: "Let Apple Intelligence design the perfect route for your next adventure."
        )
    ]
    
    public init() {
        self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    }

    // MARK: - Logic Helpers
    public var isLastPage: Bool {
        currentPage == steps.count - 1
    }

    // MARK: - Logic
    
    public func nextPage(reduceMotion: Bool) {
        if !isLastPage {
            let animation: Animation? = reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8)
            
            withAnimation(animation) {
                currentPage += 1
            }
            
            HapticManager.shared.trigger(.selection)
            
        } else {
            completeOnboarding()
        }
    }
    
    public func skip() {
        completeOnboarding()
    }
    
    private func completeOnboarding() {
        HapticManager.shared.trigger(.success)
        hasSeenOnboarding = true
    }
}

// MARK: - Model
public struct OnboardingStepData: Identifiable {
    public let id = UUID()
    public let image: String
    public let title: String
    public let description: String
    
    public init(image: String, title: String, description: String) {
        self.image = image
        self.title = title
        self.description = description
    }
}
