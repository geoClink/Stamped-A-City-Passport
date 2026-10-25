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
        // The page's one filled primary action: orange, or white on black in high contrast
        Button {
            viewModel.nextPage(reduceMotion: shouldReduceMotion)
        } label: {
            Text(viewModel.isLastPage ? L.Onboarding.getStarted : L.Onboarding.next)
                .font(.headline.weight(isHighContrast ? .black : .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.vertical, DS.Space.m)
                .foregroundStyle(isHighContrast ? Color.black : Color.white)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .fill(isHighContrast ? Color.white : DS.Palette.accent)
                )
                .contentShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .dsPageMargin()
        .padding(.top, DS.Space.s)
        .padding(.bottom, DS.Space.l)
    }
}
