//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI

struct CityHeroHeader: View {
    let city: CityLocation.City
    let progress: Double
    let isHighContrast: Bool
    let masteryTier: String

    @State private var cityBlurb: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            Text(city.details.nickname.uppercased())
                .font(Font.caption2.bold())
                .tracking(2)
                .foregroundColor(isHighContrast ? .primary : .adventureOrange)
                .accessibilityHidden(true)

            Text(city.name)
                .font(.system(.largeTitle, design: .serif).bold())
                .foregroundColor(.primary)

            if let blurb = cityBlurb {
                Text(blurb)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 24)
                    .padding(.top, 2)
                    .transition(.opacity)
            }

            VStack(spacing: 4) {
                ProgressView(value: progress)
                    .tint(isHighContrast ? .primary : .adventureOrange)
                    .frame(width: 140)
                    .scaleEffect(x: 1, y: isHighContrast ? 1.5 : 1, anchor: .center)
                
                Text("\(Int(progress * 100))% Explored")
                    .font(.caption2.monospacedDigit())
                    .fontWeight(isHighContrast ? .bold : .regular)
                    .foregroundColor(isHighContrast ? .primary : .secondary)
                
                Text(masteryTier.uppercased())
                    .font(.caption.bold())
                    .foregroundColor(isHighContrast ? .primary : .adventureOrange)
                    .padding(.top, 4)
            }
            .padding(.top, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Exploration Progress")
            .accessibilityValue("\(Int(progress * 100)) percent complete. Mastery level: \(masteryTier)")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: isHighContrast ? 0 : 24)
                .fill(isHighContrast ? Color(UIColor.systemBackground) : Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: isHighContrast ? 0 : 24)
                .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 3)
        )
        .shadow(color: isHighContrast ? .clear : .black.opacity(0.03), radius: 10, y: 5)
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(city.name) Overview")
        .task(id: city.id) {
            let summary = await WikimediaService.shared.summary(for: city.name)
            if let extract = summary.extract, !extract.isEmpty {
                // Keep only the first two sentences for a tight blurb
                let sentences = extract.components(separatedBy: ". ")
                let blurb = sentences.prefix(2).joined(separator: ". ")
                withAnimation(.easeIn(duration: 0.3)) {
                    cityBlurb = blurb.hasSuffix(".") ? blurb : blurb + "."
                }
            }
        }
    }
}
