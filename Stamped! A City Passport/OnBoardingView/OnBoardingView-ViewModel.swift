//
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
    @Published public var currentPage = 0
    @Published public var hasSeenOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenOnboarding, forKey: "hasSeenOnboarding")
        }
    }
 
    // Keys passed directly — OnboardingStep uses LocalizedStringKey to resolve them
    public let steps: [OnboardingStepData] = [
        OnboardingStepData(image: "globe.americas.fill",    title: "onboarding.step1.title", description: "onboarding.step1.description"),
        OnboardingStepData(image: "mappin.and.ellipse",     title: "onboarding.step2.title", description: "onboarding.step2.description"),
        OnboardingStepData(image: "checkmark.seal.fill",    title: "onboarding.step3.title", description: "onboarding.step3.description"),
        OnboardingStepData(image: "brain.fill",             title: "onboarding.step4.title", description: "onboarding.step4.description"),
        OnboardingStepData(image: "sparkles",               title: "onboarding.step5.title", description: "onboarding.step5.description")
    ]
 
    public init() {
        self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    }
 
    public var isLastPage: Bool { currentPage == steps.count - 1 }
 
    public func nextPage(reduceMotion: Bool) {
        if !isLastPage {
            let animation: Animation? = reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8)
            withAnimation(animation) { currentPage += 1 }
            HapticManager.shared.trigger(.selection)
        } else {
            completeOnboarding()
        }
    }
 
    public func skip() { completeOnboarding() }
 
    private func completeOnboarding() {
        HapticManager.shared.trigger(.success)
        hasSeenOnboarding = true
    }
}
 
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
