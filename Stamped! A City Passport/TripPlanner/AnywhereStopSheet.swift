//
//  AnywhereStopSheet.swift
//  Stamped! A City Passport
//
//  The "Add Stop" picker for an anywhere trip. There are no built-in
//  landmarks here, so stops come from Apple Maps search. Adding one also
//  saves it as a place (CustomPlace) under the trip's `cityName`, because
//  a stop stores `.place(placeID:)`, the same as Apple Maps stops in 2.4.
//

import SwiftUI
import MapKit

struct AnywhereStopSheet: View {
    let trip: Trip
    let dayID: String

    @ObservedObject private var store = TripStore.shared
    @ObservedObject private var progress = GlobalProgressManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Keeps the icons in one column, scaled with the text
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 28

    @AppStorage("high_contrast_mode") private var isHighContrast = false
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false

    private var areaName: String { trip.area?.name ?? trip.cityName }

    /// What's already on this day, read live from the store so checkmarks update as you tap.
    private var kindsOnDay: Set<TripStop.Kind> {
        let day = store.trip(withID: trip.id)?.days.first { $0.id == dayID }
        return Set(day?.stops.map(\.kind) ?? [])
    }

    /// Places already saved for this trip's area (from this or another day).
    private var savedHere: [CustomPlace] {
        progress.customPlaces(in: trip.cityName).filter { place in
            query.isEmpty || place.name.localizedCaseInsensitiveContains(query)
        }
    }

    /// Search results, minus places already listed under "Saved in …" above.
    private var newResults: [MKMapItem] {
        let savedIDs = Set(savedHere.map(\.id))
        return results.filter { item in
            guard let saved = savedPlace(for: item) else { return true }
            return !savedIDs.contains(saved.id)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !savedHere.isEmpty {
                    Section {
                        ForEach(savedHere) { place in
                            pickerRow(
                                name: place.name,
                                detail: place.address,
                                systemImage: CustomPlace.icon(forCategory: place.category),
                                isAdded: kindsOnDay.contains(.place(placeID: place.id))
                            ) {
                                store.addStop(.place(placeID: place.id), toDay: dayID, in: trip.id)
                            }
                        }
                    } header: {
                        DSSectionHeader("Saved in \(areaName)", systemImage: "mappin.and.ellipse", isHighContrast: isHighContrast)
                    }
                }

                if !newResults.isEmpty {
                    Section {
                        ForEach(newResults, id: \.self) { item in
                            pickerRow(
                                name: item.name ?? "Unnamed place",
                                detail: item.displayAddress,
                                systemImage: CustomPlace.icon(forCategory: item.pointOfInterestCategory?.rawValue),
                                isAdded: savedPlace(for: item).map { kindsOnDay.contains(.place(placeID: $0.id)) } ?? false
                            ) {
                                add(item)
                            }
                        }
                    } header: {
                        DSSectionHeader("Apple Maps", systemImage: "map", isHighContrast: isHighContrast)
                    }
                }
            }
            .overlay {
                if query.trimmingCharacters(in: .whitespaces).isEmpty && savedHere.isEmpty {
                    ContentUnavailableView(
                        "Add a Place in \(areaName)",
                        systemImage: "mappin.and.ellipse",
                        description: Text("Search for a restaurant, museum, park or anything else you want to visit.")
                    )
                } else if isSearching && results.isEmpty && savedHere.isEmpty {
                    ProgressView()
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search \(areaName)")
            .navigationTitle("Add Stops")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                await search()
            }
        }
        .tint(DS.Palette.accent)
    }

    // MARK: - Row

    private func pickerRow(name: String, detail: String?, systemImage: String, isAdded: Bool, add: @escaping () -> Void) -> some View {
        Button {
            add()
            HapticManager.shared.trigger(.selection)
        } label: {
            HStack(spacing: DS.Space.m) {
                Image(systemName: systemImage)
                    // Pink like saved places' pins on the city map: every stop here becomes one
                    .foregroundStyle(DS.Palette.wishlist)
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
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        // Already on this day: show the checkmark but don't add it twice
        .disabled(isAdded)
        .accessibilityLabel(isAdded ? "\(name), added" : "Add \(name)")
    }

    // MARK: - Actions

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { results = []; return }
        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.resultTypes = [.pointOfInterest, .address]
        // About 25 km around the area, like AddPlaceSheet does for a city
        if let center = trip.area?.coordinate {
            request.region = MKCoordinateRegion(center: center, latitudinalMeters: 25_000, longitudinalMeters: 25_000)
        }
        let response = try? await MKLocalSearch(request: request).start()
        results = response?.mapItems ?? []
    }

    /// The saved place for a search result, if the user already saved that spot.
    private func savedPlace(for item: MKMapItem) -> CustomPlace? {
        let coordinate = item.displayCoordinate
        return progress.customPlaces.first {
            $0.isSamePlace(name: item.name ?? "Unnamed place", latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }

    /// Saves the result as a place (unless it's saved already), then adds it to the day.
    private func add(_ item: MKMapItem) {
        if let existing = savedPlace(for: item) {
            store.addStop(.place(placeID: existing.id), toDay: dayID, in: trip.id)
            return
        }
        let coordinate = item.displayCoordinate
        let place = CustomPlace(
            id: UUID().uuidString,
            name: item.name ?? "Unnamed place",
            address: item.displayAddress,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            cityName: trip.cityName,
            websiteURL: item.url,
            phoneNumber: item.phoneNumber,
            category: item.pointOfInterestCategory?.rawValue
        )
        progress.addCustomPlace(place)
        store.addStop(.place(placeID: place.id), toDay: dayID, in: trip.id)
    }
}
