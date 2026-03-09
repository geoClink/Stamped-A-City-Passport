//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI

struct LandmarkRow: View {
    let building: Building
    let isVisited: Bool
    var isHighContrast: Bool = false
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    @State private var isPulsing = false

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ?
                     AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) :
                     AnyLayout(HStackLayout(spacing: 16))

        layout {
            Image(systemName: isVisited ? "checkmark.seal.fill" : "mappin.circle.fill")
                .font(.title)
                .foregroundColor(
                    isHighContrast ? .primary : (isVisited ? .adventureOrange : .blue)
                )
                .shadow(color: !isVisited ? .blue.opacity(isPulsing ? 0.8 : 0.3) : .clear, radius: isPulsing ? 15 : 5)
                .scaleEffect(!isVisited && isPulsing ? 1.3 : 1.0)
                .hueRotation(.degrees(isPulsing ? 10 : 0))
                .onAppear {
                    if !isVisited {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            isPulsing = true
                        }
                    }
                }
                .accessibilityHidden(true)
                .accessibilityLabel(isVisited ? "Visited, \(building.name)" : "Next goal: \(building.name)")
            
            VStack(alignment: .leading, spacing: 4) {
                Text(building.name)
                    .font(isHighContrast ? .headline.bold() : .headline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(building.architect)
                    .font(.caption)
                    .foregroundColor(isHighContrast ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(isHighContrast ? .primary : .secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHighContrast ? Color(.systemBackground) : Color.clear)
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isVisited ? "Visited, \(building.name)" : "Not visited, \(building.name)")
        .accessibilityValue("Architect: \(building.architect)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to view building details and history.")
    }
}
