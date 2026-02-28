//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI

// MARK: - Animation Effects
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
                y: 0
            )
        )
    }
}

// MARK: - View Modifiers
extension View {
    
    @ViewBuilder
    func safeSymbolPulse(isActive: Bool) -> some View {
        if #available(iOS 17.0, *) {
            self.symbolEffect(.pulse, isActive: isActive)
        } else {
            // Fallback for older iOS versions: simple opacity pulse
            self.opacity(isActive ? 0.8 : 1.0)
                .animation(isActive ? .easeInOut(duration: 1).repeatForever() : .default, value: isActive)
        }
    }
    
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

