//
//  MapCategory.swift
//  Stamped! A City Passport
//
//  The chips across the top of the city map: Landmarks · Food · Coffee · Culture.
//  Each chip decides which of Apple Maps' own places (restaurants, cafés, museums…)
//  are drawn on the map. Stamped's landmark pins always show.
//

import SwiftUI
import MapKit

enum MapCategory: String, CaseIterable, Identifiable {
    case landmarks, food, coffee, culture
    var id: Self { self }

    var title: String {
        switch self {
        case .landmarks: "Landmarks"
        case .food:      "Food"
        case .coffee:    "Coffee"
        case .culture:   "Culture"
        }
    }

    var icon: String {
        switch self {
        case .landmarks: "building.columns.fill"
        case .food:      "fork.knife"
        case .coffee:    "cup.and.saucer.fill"
        case .culture:   "theatermasks.fill"
        }
    }

    /// Which Apple Maps places to draw. Landmarks hides them all so Stamped's pins stand out.
    var pointsOfInterest: PointOfInterestCategories {
        switch self {
        case .landmarks:
            .excludingAll
        case .food:
            .including([.restaurant, .bakery, .foodMarket, .brewery, .winery, .distillery])
        case .coffee:
            .including([.cafe, .bakery])
        case .culture:
            .including([.museum, .theater, .library, .musicVenue, .planetarium,
                        .castle, .nationalMonument, .landmark])
        }
    }

    /// The map style for this category, in satellite or regular map mode.
    func mapStyle(satellite: Bool) -> MapStyle {
        if satellite {
            // Plain satellite (.imagery) can't show place icons, so the other
            // categories switch to .hybrid: the same photos plus labels and icons.
            return self == .landmarks
                ? .imagery(elevation: .realistic)
                : .hybrid(elevation: .realistic, pointsOfInterest: pointsOfInterest)
        }
        return .standard(elevation: .realistic, pointsOfInterest: pointsOfInterest)
    }
}

// MARK: - Chips

/// A row of capsule buttons, like the category chips under the Apple Maps search bar.
struct MapCategoryChips: View {
    @Binding var selection: MapCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MapCategory.allCases) { category in
                    let isSelected = category == selection
                    Button {
                        withAnimation(.snappy) { selection = category }
                    } label: {
                        Label(category.title, systemImage: category.icon)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .background {
                                if isSelected {
                                    Capsule().fill(Color.adventureOrange)
                                } else {
                                    Capsule().fill(.regularMaterial)
                                }
                            }
                            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}
