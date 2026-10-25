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
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 100

    var body: some View {
        // Centered when it fits; scrolls when large text makes the page too tall
        ViewThatFits(in: .vertical) {
            content
            ScrollView {
                content
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

    private var content: some View {
        VStack(spacing: DS.Space.xl) {
            Image(systemName: data.image)
                .font(.system(size: iconSize))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.white)
                .scaleEffect((isAnimating || manualReduceMotion || systemReduceMotion) ? 1.0 : 0.6)
                .opacity(isAnimating ? 1.0 : 0.0)
                .accessibilityHidden(true)

            VStack(spacing: DS.Space.m) {
                Text(LocalizedStringKey(data.title))
                    .font(.system(.largeTitle, design: .serif).bold())
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .accessibilityAddTraits(.isHeader)

                Text(LocalizedStringKey(data.description))
                    .multilineTextAlignment(.center)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Space.xl)
        .dsPageMargin()
        // Clears the page dots at the bottom of the pager
        .padding(.bottom, DS.Space.section + DS.Space.l)
    }
}
