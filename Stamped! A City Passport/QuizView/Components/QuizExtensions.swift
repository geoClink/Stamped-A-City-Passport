//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI

// MARK: - Custom Star Shape

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerR = min(rect.width, rect.height) / 2
        let innerR = outerR * 0.42
        var path = Path()
        for i in 0..<10 {
            let angle = (Double(i) * .pi / 5) - .pi / 2
            let r = i.isMultiple(of: 2) ? outerR : innerR
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * CGFloat(r),
                y: center.y + CGFloat(sin(angle)) * CGFloat(r)
            )
            i == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

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

