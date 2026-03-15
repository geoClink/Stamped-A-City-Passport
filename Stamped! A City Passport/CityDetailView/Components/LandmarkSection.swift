//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/28/26.
//

import SwiftUI

struct LandmarkSection: View {
    @ObservedObject var viewModel: CityDetailViewModel
    var isHighContrast: Bool
    
    @ObservedObject private var progressManager = GlobalProgressManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LANDMARKS")
                .font(.caption.bold())
                .foregroundColor(isHighContrast ? .primary : .secondary)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)
            
            VStack(spacing: isHighContrast ? 12 : 1) {
                ForEach(viewModel.city.buildings) { building in
                    NavigationLink(destination: BuildingDetailView(building: building, viewModel: viewModel)) {
                        LandmarkRow(
                            building: building,
                            isVisited: progressManager.visitedIDs.contains(building.id),
                            isHighContrast: isHighContrast
                        )
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        HapticManager.shared.trigger(.selection)
                    })
                    .accessibilityIdentifier("LandmarkLink_\(building.name)")
                    
                    if !isHighContrast && building.id != viewModel.city.buildings.last?.id {
                        Divider().padding(.leading, 60)
                            .accessibilityHidden(true)
                    }
                }
            }
            .background(isHighContrast ? Color.clear : Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 3)
            )
            .padding(.horizontal)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Landmarks in \(viewModel.city.name)")
    }
}
