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
    
    
    @ScaledMetric(relativeTo: .body) var iconSize: CGFloat = 60
    @State var internalScale: CGFloat = 1.0
    @State var internalOpacity: Double = 0.0
    
    var stampColor: Color {
        isHighContrast ? Color.primary : Color.adventureOrange
    }
    
    var body: some View {
        VStack(spacing: 16) {
            sealHeader
            cityInfoSection
            
            Divider()
                .background(stampColor.opacity(isHighContrast ? 1.0 : 0.3))
                .padding(.horizontal)
            
            funFactSection
        }
        .padding(24)
        .frame(maxWidth: 350)
        .frame(minHeight: 250)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(stampColor, style: StrokeStyle(lineWidth: isHighContrast ? 3 : 2, dash: [6]))
        )
        .background(Color(.systemBackground).cornerRadius(15))
        // Subtle tilt for a "hand-stamped" look, disabled in reduce motion
        .rotationEffect(.degrees(reduceMotion ? 0 : -3))
        .scaleEffect(internalScale)
        .opacity(internalOpacity)
        .shadow(color: .black.opacity(isHighContrast ? 0 : 0.1), radius: 10, x: 0, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Official Passport Stamp for \(cityName)")
        .accessibilityValue("Completed on \(dateCompleted). Did you know? \(funFact)")
        .onAppear(perform: handleAppearance)
    }
}
