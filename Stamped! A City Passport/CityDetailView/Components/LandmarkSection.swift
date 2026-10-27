//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/28/26.
//

import SwiftUI
import MapKit

struct LandmarkSection: View {
    @ObservedObject var viewModel: CityDetailViewModel
    var isHighContrast: Bool
    
    @ObservedObject private var progressManager = GlobalProgressManager.shared
    @State private var showingAddPlace = false
    @State private var browserLink: BrowserLink?
    @Environment(\.openURL) private var openURL

    /// Lines up row dividers with the row text, past the icon
    private let dividerInset: CGFloat = 60
    /// In high contrast every row has its own border, so the card gets padding around them
    private var listPadding: CGFloat { isHighContrast ? DS.Space.m : 0 }
    @ScaledMetric(relativeTo: .headline) private var placeIconSize: CGFloat = 34
    
    private var wishlistBuildings: [Building] {
        viewModel.city.buildings.filter { progressManager.isWishlisted($0.id) }
    }

    private var customPlaces: [CustomPlace] {
        progressManager.customPlaces(in: viewModel.city.name)
    }

    /// Middle of the city's landmarks, used to search Apple Maps near this city.
    private var cityCenter: CLLocationCoordinate2D? {
        let located = viewModel.city.buildings.filter { $0.latitude != nil && $0.longitude != nil }
        guard !located.isEmpty else { return nil }
        let lats = located.map { $0.latitude! }.sorted()
        let lons = located.map { $0.longitude! }.sorted()
        return CLLocationCoordinate2D(latitude: lats[lats.count / 2], longitude: lons[lons.count / 2])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.section) {
            wishlistSection

            VStack(alignment: .leading, spacing: DS.Space.m) {
                DSSectionHeader("Landmarks", systemImage: "building.columns.fill", isHighContrast: isHighContrast)
                    .dsPageMargin()
            
                VStack(spacing: isHighContrast ? DS.Space.m : 0) {
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
                            Divider().padding(.leading, dividerInset)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .dsCard(padding: listPadding, isHighContrast: isHighContrast)
                .dsPageMargin()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Landmarks in \(viewModel.city.name)")
        .inAppBrowser(item: $browserLink)
        .sheet(isPresented: $showingAddPlace) {
            if let center = cityCenter {
                AddPlaceSheet(cityName: viewModel.city.name, cityCenter: center)
            }
        }
    }

    // MARK: - Want to Visit

    /// A place saved from Apple Maps. Tap opens it in Maps; long-press for more.
    private func customPlaceRow(_ place: CustomPlace) -> some View {
        Button {
            let name = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "maps://?ll=\(place.latitude),\(place.longitude)&q=\(name)") {
                openURL(url)
            }
        } label: {
            HStack(spacing: DS.Space.m) {
                Image(systemName: CustomPlace.icon(forCategory: place.category))
                    .font(.headline)
                    .foregroundStyle(isHighContrast ? Color(UIColor.systemBackground) : .white)
                    .frame(width: placeIconSize, height: placeIconSize)
                    .background(isHighContrast ? Color.primary : DS.Palette.wishlist, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name).font(.headline).foregroundStyle(.primary)
                    if let address = place.address {
                        Text(address).font(.caption).foregroundStyle(isHighContrast ? .primary : .secondary).lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(isHighContrast ? .primary : .secondary)
            }
            .padding(DS.Space.l)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let website = place.websiteURL {
                Button { browserLink = BrowserLink(url: website) } label: { Label("Website", systemImage: "safari") }
            }
            Button(role: .destructive) {
                withAnimation { progressManager.removeCustomPlace(place.id) }
            } label: {
                Label("Remove from Want to Visit", systemImage: "heart.slash")
            }
        }
        .accessibilityHint("Opens in Maps. Long-press for more options.")
    }

    /// Landmarks saved for a future trip, shown above the full list.
    private var wishlistSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            // DSSectionHeader tints its icon orange; Want to Visit is the one pink section,
            // so the heart sits beside the header in the same font and spacing instead
            HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
                Image(systemName: "heart.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(isHighContrast ? Color.primary : DS.Palette.wishlist)
                    .accessibilityHidden(true)
                DSSectionHeader("Want to Visit", isHighContrast: isHighContrast)
            }
            .dsPageMargin()

            VStack(spacing: isHighContrast ? DS.Space.m : 0) {
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

                    if !isHighContrast {
                        Divider().padding(.leading, dividerInset)
                            .accessibilityHidden(true)
                    }
                }

                ForEach(customPlaces) { place in
                    customPlaceRow(place)
                    if !isHighContrast {
                        Divider().padding(.leading, dividerInset)
                            .accessibilityHidden(true)
                    }
                }

                Button {
                    showingAddPlace = true
                } label: {
                    Label("Add a Place", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(isHighContrast ? .primary : DS.Palette.wishlist)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Space.l)
                }
                .buttonStyle(.plain)
                .disabled(cityCenter == nil)
                .accessibilityHint("Search Apple Maps for a restaurant, shop or anything else to visit")
            }
            .dsCard(padding: listPadding, isHighContrast: isHighContrast)
            .dsPageMargin()
        }
    }
}
