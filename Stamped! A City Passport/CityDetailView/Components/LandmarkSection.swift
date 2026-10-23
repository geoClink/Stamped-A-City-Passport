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
    
    private var wishlistBuildings: [Building] {
        viewModel.city.buildings.filter { progressManager.isWishlisted($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !wishlistBuildings.isEmpty {
                wishlistSection
            }

            Text("LANDMARKS")
                .font(.caption.bold())
                .foregroundColor(isHighContrast ? .primary : .secondary)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)
            
            VStack(spacing: isHighContrast ? 12 : 1) {
                ForEach(viewModel.city.buildings) { building in
                    let isVisited = progressManager.visitedIDs.contains(building.id)
                    NavigationLink(destination: BuildingDetailView(building: building, viewModel: viewModel)) {
                        LandmarkRow(
                            building: building,
                            isVisited: isVisited,
                            isHighContrast: isHighContrast
                        )
                        // contextMenu on the inner content keeps NavigationLink's tap gesture
                        // unambiguous — the system no longer waits for a long-press threshold.
                        .contextMenu {
                            Button {
                                withAnimation(.spring()) {
                                    viewModel.toggleVisited(for: building)
                                }
                                HapticManager.shared.trigger(.success)
                            } label: {
                                Label(
                                    isVisited ? "Remove Stamp" : "Mark as Visited",
                                    systemImage: isVisited ? "checkmark.seal" : "checkmark.seal.fill"
                                )
                            }
                            Button {
                                withAnimation(.spring()) { progressManager.toggleWishlist(building.id) }
                                HapticManager.shared.trigger(.selection)
                            } label: {
                                let isSaved = progressManager.isWishlisted(building.id)
                                Label(isSaved ? "Remove from Want to Visit" : "Want to Visit",
                                      systemImage: isSaved ? "heart.slash" : "heart")
                            }
                            if let lat = building.latitude, let lon = building.longitude {
                                let encoded = building.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                if let url = URL(string: "maps://?ll=\(lat),\(lon)&q=\(encoded)") {
                                    Button {
                                        UIApplication.shared.open(url)
                                        HapticManager.shared.trigger(.selection)
                                    } label: {
                                        Label("Open in Maps", systemImage: "map")
                                    }
                                }
                            }
                        } preview: {
                            WikiBuildingPhoto(building: building, height: 220)
                                .frame(width: 300)
                                .clipped()
                        }
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.highlight)
                    .contentShape(Rectangle())
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

    // MARK: - Want to Visit

    /// Landmarks saved for a future trip, shown above the full list.
    private var wishlistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("WANT TO VISIT", systemImage: "heart.fill")
                .font(.caption.bold())
                .foregroundColor(isHighContrast ? .primary : .pink)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: isHighContrast ? 12 : 1) {
                ForEach(wishlistBuildings) { building in
                    NavigationLink(destination: BuildingDetailView(building: building, viewModel: viewModel)) {
                        LandmarkRow(
                            building: building,
                            isVisited: progressManager.isVisited(building.id),
                            isHighContrast: isHighContrast
                        )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())

                    if !isHighContrast && building.id != wishlistBuildings.last?.id {
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
            .padding(.bottom, 12)
        }
    }
}
