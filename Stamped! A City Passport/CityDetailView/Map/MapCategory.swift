//
//  MapCategory.swift
//  Stamped! A City Passport
//
//  The chips across the top of the city map: Landmarks · Food · Coffee · Culture · Stay.
//  Each chip decides which of Apple Maps' own places (restaurants, cafés, museums, hotels…)
//  are drawn on the map. Stamped's landmark pins always show.
//

import SwiftUI
import MapKit

enum MapCategory: String, CaseIterable, Identifiable {
    case landmarks, food, coffee, culture, stay
    var id: Self { self }

    var title: String {
        switch self {
        case .landmarks: NSLocalizedString("Landmarks", comment: "City map: category chip that shows only Stamped's landmarks")
        case .food:      NSLocalizedString("Food", comment: "City map: category chip that shows restaurants, bakeries and markets")
        case .coffee:    NSLocalizedString("Coffee", comment: "City map: category chip that shows cafés")
        case .culture:   NSLocalizedString("Culture", comment: "City map: category chip that shows museums, theaters and monuments")
        case .stay:      NSLocalizedString("Stay", comment: "City map: category chip that shows hotels")
        }
    }

    var icon: String {
        switch self {
        case .landmarks: "building.columns.fill"
        case .food:      "fork.knife"
        case .coffee:    "cup.and.saucer.fill"
        case .culture:   "theatermasks.fill"
        case .stay:      "bed.double.fill"
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
        case .stay:
            // Hotels only. Tapping one opens Apple's place card with a Check Prices button.
            .including([.hotel])
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
        ScrollViewReader { proxy in
            chipRow
                // Keep the chosen chip fully on screen instead of cut off at the edge
                .onChange(of: selection) { _, chip in
                    withAnimation(.snappy) { proxy.scrollTo(chip, anchor: .center) }
                }
        }
        // The chips sit on the map, so very large text would cover it; they stop growing at XXL
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    private var chipRow: some View {
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
                    .id(category)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        // A soft fade at the edges says "there's more", instead of a hard cut through a chip
        .mask {
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: 12)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: 12)
            }
        }
    }
}
