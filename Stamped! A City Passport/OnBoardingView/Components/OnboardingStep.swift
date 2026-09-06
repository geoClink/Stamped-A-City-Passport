//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//
//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//
import SwiftUI

struct OnboardingStep: View {
    let data: OnboardingStepData
    let isHighContrast: Bool

    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("reduce_motion") var manualReduceMotion = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: data.image)
                .font(.system(size: 100))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.white)
                .scaleEffect((isAnimating || manualReduceMotion || systemReduceMotion) ? 1.0 : 0.6)
                .opacity(isAnimating ? 1.0 : 0.0)

            VStack(spacing: 12) {
                Text(LocalizedStringKey(data.title))
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .foregroundColor(.white)

                Text(LocalizedStringKey(data.description))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .onAppear {
            if manualReduceMotion || systemReduceMotion {
                isAnimating = true
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                    isAnimating = true
                }
            }
        }
    }
}
