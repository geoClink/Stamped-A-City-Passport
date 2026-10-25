//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI

// MARK: - Passport Stamp View
struct PassportStampView: View {
    let cityName: String
    let dateCompleted: String
    let funFact: String
    var isHighContrast: Bool = false
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.colorSchemeContrast) var systemContrast
    @Environment(\.colorScheme) var colorScheme


    @ScaledMetric(relativeTo: .body) var iconSize: CGFloat = 60
    @State var internalScale: CGFloat = 1.0
    @State var internalOpacity: Double = 0.0

    /// Campus stamps are inked in the school's color; city stamps in the app's orange.
    var stampColor: Color {
        if isHighContrast { return Color.primary }
        let campus = CityLocation.City(rawValue: cityName)
        return campus?.stampColor(darkMode: colorScheme == .dark) ?? DS.Palette.accent
    }
    
    var body: some View {
        VStack(spacing: DS.Space.l) {
            sealHeader
            cityInfoSection
            
            Divider()
                .background(stampColor.opacity(isHighContrast ? 1.0 : 0.3))
                .padding(.horizontal, DS.Space.l)
            
            funFactSection
        }
        .padding(DS.Space.xl)
        .frame(maxWidth: 350)
        .frame(minHeight: 250)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .strokeBorder(stampColor, style: StrokeStyle(lineWidth: isHighContrast ? 3 : 2, dash: [6]))
        )
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(Color(.systemBackground))
        )
        // Subtle tilt for a "hand-stamped" look, disabled in reduce motion
        .rotationEffect(.degrees(reduceMotion ? 0 : -3))
        .scaleEffect(internalScale)
        .opacity(internalOpacity)
        // Kept on purpose: the stamp is a sheet of paper lifted off the page, not an ordinary card
        .shadow(color: .black.opacity(isHighContrast ? 0 : 0.1), radius: 10, x: 0, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Official Passport Stamp for \(cityName)")
        .accessibilityValue("Completed on \(dateCompleted). Did you know? \(funFact)")
        .onAppear(perform: handleAppearance)
    }
}
