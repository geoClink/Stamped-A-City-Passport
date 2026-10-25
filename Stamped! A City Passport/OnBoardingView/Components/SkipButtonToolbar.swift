//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI

/// The plain secondary "Skip" link above the onboarding pages. Hidden on the last
/// page, where Get Started does the same job; the row keeps its height either way.
struct SkipButton: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let isHighContrast: Bool

    var body: some View {
        HStack {
            Spacer()
            if viewModel.currentPage < viewModel.steps.count - 1 {
                Button {
                    viewModel.skip()
                } label: {
                    Text(L.Onboarding.skip)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        // A full 44pt target, not just the glyphs
                        .frame(minWidth: 44, minHeight: 44)
                        .padding(.horizontal, DS.Space.s)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(.body.weight(isHighContrast ? .bold : .regular))
                .foregroundStyle(isHighContrast ? Color.white : Color.white.opacity(0.75))
                .accessibilityLabel(L.Onboarding.skipAccessibilityLabel)
                .accessibilityHint(L.Onboarding.skipAccessibilityHint)
            }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, DS.Space.page - DS.Space.s)
    }
}

#Preview {
    ZStack(alignment: .top) {
        Color.black.ignoresSafeArea()
        SkipButton(viewModel: OnboardingViewModel(), isHighContrast: false)
    }
}
