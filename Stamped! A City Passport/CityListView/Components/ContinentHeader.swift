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
            
            Text(continent.localizedName.localizedUppercase)
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
            return AnyShapeStyle(LinearGradient.sectionIcon)
        }
    }
}

/// Header for the "Campus Architecture" section, styled like a continent header.
struct CampusSectionHeader: View {
    let isHighContrast: Bool
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "graduationcap.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.title3)
                .foregroundStyle(isHighContrast ? AnyShapeStyle(Color.primary) : AnyShapeStyle(LinearGradient.sectionIcon))
                .rotationEffect(.degrees(isExpanded ? 360 : 0))
                .animation(.interpolatingSpring(stiffness: 100, damping: 10), value: isExpanded)
                .accessibilityHidden(true)

            Text("CAMPUS ARCHITECTURE")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .tracking(2.0)
                .foregroundColor(isHighContrast ? .primary : .adventureOrange)
        }
        .padding(.vertical, 8)
        .accessibilityAddTraits(.isHeader)
    }
}

extension LinearGradient {
    /// One brand gradient for every section icon in the city list (continents and campuses),
    /// instead of a different color per continent; the style guide keeps one accent color.
    static let sectionIcon = LinearGradient(
        colors: [Color(red: 0xFF / 255, green: 0x8A / 255, blue: 0x57 / 255), .adventureOrange],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}
