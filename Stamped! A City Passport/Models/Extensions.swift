//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI
import Foundation

// MARK: - View Style Extensions
extension View {
    @ViewBuilder
    func landmarkSymbolEffect(active: Bool, reduceMotion: Bool) -> some View {
        if #available(iOS 17.0, *), !reduceMotion {
            self.contentTransition(.symbolEffect(.replace))
        } else {
            self.animation(reduceMotion ? nil : .easeInOut, value: active)
        }
    }
    
    func visitedStyle(isHighContrast: Bool) -> some View {
        self.modifier(HighContrastVisitedStyle(isHighContrast: isHighContrast))
    }
    
    func asAdaptiveCard(isHighContrast: Bool) -> some View {
        self.modifier(AdaptiveContrastCard(isHighContrast: isHighContrast))
    }
}

// MARK: - Accessibility Modifiers
struct HighContrastVisitedStyle: ViewModifier {
    let isHighContrast: Bool
    
    func body(content: Content) -> some View {
        if isHighContrast {
            content
                .foregroundColor(.white)
                .padding(2)
                .background(Circle().fill(Color.black))
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
        } else {
            content
                .foregroundColor(Color.adventureOrange)
        }
    }
}

struct AdaptiveContrastCard: ViewModifier {
    let isHighContrast: Bool
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(isHighContrast ? Color(.systemBackground) : Color.primary.opacity(0.05))
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
            )
    }
}

// MARK: - Data Extensions
extension CityLocation.City {
    var buildings: [Building] {
        let unorderedBuildings = BuildingRegistry.data[self] ?? []
        return unorderedBuildings.sorted { $0.name < $1.name }
    }
}

// MARK: - Typography Extensions
extension Font {
    static var serifFootnote: Font {
        return Font.system(.footnote, design: .serif)
    }
}

extension View {
    @ViewBuilder
    func adaptiveListStyle(isIPad: Bool) -> some View {
        if isIPad {
            self.listStyle(.sidebar)
        } else {
            self.listStyle(.insetGrouped)
        }
    }
}

extension View {
    @ViewBuilder
    func bounceOnUpdate<T: Equatable>(value: T) -> some View {
        if #available(iOS 17.0, *) {
            self.symbolEffect(.bounce, value: value)
        } else {
            self
        }
    }
}

