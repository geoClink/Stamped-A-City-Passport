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
    

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ?
                     AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.m)) :
                     AnyLayout(HStackLayout(spacing: DS.Space.l))

        layout {
            // Orange once stamped, gray until then: the same two colors as the map's pins.
            // (Unvisited pins used to be blue and all pulse at once.)
            Image(systemName: isVisited ? "checkmark.seal.fill" : "mappin.circle.fill")
                .font(.title)
                .foregroundColor(
                    isHighContrast ? .primary : (isVisited ? DS.Palette.accent : Color(UIColor.systemGray3))
                )
                .accessibilityHidden(true)
                .accessibilityLabel(isVisited ? "Visited, \(building.name)" : "Next goal: \(building.name)")
            
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text(building.name)
                    .font(isHighContrast ? .headline.bold() : .headline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let architect = building.knownArchitect {
                    Text(architect)
                        .font(.caption)
                        .foregroundColor(isHighContrast ? .primary : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(isHighContrast ? .primary : .secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(DS.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                .fill(isHighContrast ? Color(.systemBackground) : Color.clear)
        )
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isVisited ? "Visited, \(building.name)" : "Not visited, \(building.name)")
        .accessibilityValue(building.knownArchitect.map { "Architect: \($0)" } ?? "")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to view building details and history.")
    }
}
