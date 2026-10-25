//
//  AddTripStopSheet.swift
//  Stamped! A City Passport
//
//  Picker for adding stops to one day: the user's saved places, their
//  "Want to Visit" landmarks, then every landmark in the city.
//  Tapping a row adds it; the sheet stays open so several can be added.
//

import SwiftUI

struct AddTripStopSheet: View {
    let city: CityLocation.City
    let tripID: String
    let dayID: String

    @ObservedObject private var store = TripStore.shared
    @ObservedObject private var progress = GlobalProgressManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Keeps the icons in one column, scaled with the text
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 28
    @AppStorage("high_contrast_mode") private var isHighContrast = false
    @State private var searchText = ""

    /// What's already on this day, read live from the store so checkmarks update as you tap.
    private var kindsOnDay: Set<TripStop.Kind> {
        let day = store.trip(withID: tripID)?.days.first { $0.id == dayID }
        return Set(day?.stops.map(\.kind) ?? [])
    }

    private var savedPlaces: [CustomPlace] {
        progress.customPlaces(in: city.name).filter { matchesSearch($0.name) }
    }

    private var wishlistLandmarks: [Building] {
        city.buildings.filter { progress.isWishlisted($0.id) && matchesSearch($0.name) }
    }

    private var allLandmarks: [Building] {
        city.buildings.filter { matchesSearch($0.name) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !savedPlaces.isEmpty {
                    Section {
                        ForEach(savedPlaces) { place in
                            pickerRow(
                                name: place.name,
                                detail: place.address,
                                systemImage: CustomPlace.icon(forCategory: place.category),
                                kind: .place(placeID: place.id)
                            )
                        }
                    } header: {
                        DSSectionHeader("Saved Places", systemImage: "mappin.and.ellipse", isHighContrast: isHighContrast)
                    }
                }

                if !wishlistLandmarks.isEmpty {
                    Section {
                        ForEach(wishlistLandmarks) { building in
                            landmarkRow(building)
                        }
                    } header: {
                        DSSectionHeader("Want to Visit", systemImage: "heart", isHighContrast: isHighContrast)
                    }
                }

                Section {
                    ForEach(allLandmarks) { building in
                        landmarkRow(building)
                    }
                } header: {
                    DSSectionHeader("All Landmarks", systemImage: "building.columns", isHighContrast: isHighContrast)
                }
            }
            .searchable(text: $searchText, prompt: "Search \(city.name)")
            .navigationTitle("Add Stops")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(DS.Palette.accent)
    }

    private func landmarkRow(_ building: Building) -> some View {
        pickerRow(
            name: building.name,
            detail: building.knownStyle ?? "",
            systemImage: "building.columns.fill",
            kind: .landmark(buildingID: building.id)
        )
    }

    private func pickerRow(name: String, detail: String?, systemImage: String, kind: TripStop.Kind) -> some View {
        let isAdded = kindsOnDay.contains(kind)
        return Button {
            store.addStop(kind, toDay: dayID, in: tripID)
            HapticManager.shared.trigger(.selection)
        } label: {
            HStack(spacing: DS.Space.m) {
                Image(systemName: systemImage)
                    .foregroundStyle(DS.Palette.accent)
                    .frame(width: iconWidth)
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text(name)
                        .foregroundStyle(.primary)
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                    }
                }
                Spacer()
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(isAdded ? Color.green : DS.Palette.accent)
                    .font(.title3)
            }
        }
        // Plain style keeps names in the normal text colour instead of the tint
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        // Already on this day: show the checkmark but don't add it twice
        .disabled(isAdded)
        .accessibilityLabel(isAdded ? "\(name), added" : "Add \(name)")
    }

    private func matchesSearch(_ name: String) -> Bool {
        searchText.isEmpty || name.localizedCaseInsensitiveContains(searchText)
    }
}
