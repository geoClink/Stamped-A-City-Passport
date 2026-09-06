//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/28/26.
//
import SwiftUI

struct ContinentHeader: View {
    let continent: CityLocation.Continent
    let isHighContrast: Bool
    let isExpanded: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: continent.iconName)
                .symbolRenderingMode(.hierarchical)
                .font(.title3)
                .foregroundStyle(style)
                .rotationEffect(.degrees(isExpanded ? 360 : 0))
                .animation(.interpolatingSpring(stiffness: 100, damping: 10), value: isExpanded)
                .accessibilityHidden(true) // The text says it all
            
            Text(continent.rawValue.uppercased())
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .tracking(2.0)
                .foregroundColor(isHighContrast ? .primary : .adventureOrange)
        }
        .padding(.vertical, 8)
        .accessibilityAddTraits(.isHeader) 
    }

    private var style: AnyShapeStyle {
        if isHighContrast {
            return AnyShapeStyle(Color.primary)
        } else {
            return AnyShapeStyle(continent.iconGradient)
        }
    }
}
