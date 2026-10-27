//
//  AreaSearchSheet.swift
//  Stamped! A City Passport
//
//  "New Trip Anywhere": search Apple Maps for a city or region and start a
//  trip there. If the area is a Stamped city, offer to plan it there instead,
//  so the user still gets landmarks, stamps and the quiz.
//

import SwiftUI
import MapKit

struct AreaSearchSheet: View {
    /// Called with the new trip, so the trip list can select it.
    let onCreate: (Trip) -> Void

    @ObservedObject private var store = TripStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false
    /// A picked area close to a Stamped city, waiting for the user to choose.
    @State private var nearbyChoice: NearbyChoice?

    private struct NearbyChoice: Identifiable {
        let item: MKMapItem
        let city: CityLocation.City
        var id: String { city.rawValue }
    }

    var body: some View {
        NavigationStack {
            List(results, id: \.self) { item in
                Button {
                    pick(item)
                } label: {
                    HStack(spacing: DS.Space.m) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundStyle(DS.Palette.accent)
                        VStack(alignment: .leading, spacing: DS.Space.xs) {
                            Text(item.name ?? "Unnamed place")
                                // Serif, the style guide's type for destinations
                                .font(.system(.headline, design: .serif))
                                .foregroundStyle(.primary)
                            if let address = item.displayAddress {
                                Text(address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        // Fills the row so the whole width is tappable
                        Spacer()
                    }
                }
                // Plain style keeps names in the normal text colour instead of the tint
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            .overlay {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    ContentUnavailableView(
                        "Plan a Trip Anywhere",
                        systemImage: "globe.europe.africa.fill",
                        description: Text("Search for a city or region. Your stops will be places from Apple Maps.")
                    )
                } else if isSearching && results.isEmpty {
                    ProgressView()
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, placement: .alwaysVisible,
                        prompt: "City or region")
            .navigationTitle("New Trip Anywhere")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // Same debounce as AddPlaceSheet: wait for a pause in typing before searching
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                await search()
            }
            .confirmationDialog(
                "\(nearbyChoice?.city.name ?? "This") is a Stamped city",
                isPresented: Binding(get: { nearbyChoice != nil }, set: { if !$0 { nearbyChoice = nil } }),
                titleVisibility: .visible,
                presenting: nearbyChoice
            ) { choice in
                Button("Plan in \(choice.city.name)") { createListedTrip(in: choice.city) }
                Button("Plan Anywhere Trip") { createAnywhereTrip(from: choice.item) }
            } message: { choice in
                Text("Planning in \(choice.city.name) adds its landmarks, stamps and quiz.")
            }
        }
        .tint(DS.Palette.accent)
    }

    // MARK: - Actions

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { results = []; return }
        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        // Addresses include cities and regions; points of interest would add shops and cafés
        request.resultTypes = .address
        let response = try? await MKLocalSearch(request: request).start()
        results = response?.mapItems ?? []
    }

    private func pick(_ item: MKMapItem) {
        if let city = CityLocation.City.listed(near: item.displayCoordinate) {
            nearbyChoice = NearbyChoice(item: item, city: city)
        } else {
            createAnywhereTrip(from: item)
        }
    }

    private func createAnywhereTrip(from item: MKMapItem) {
        let name = item.name ?? "New Place"
        let coordinate = item.displayCoordinate
        let trip = store.createTrip(
            name: "\(name) Trip",
            cityName: Trip.anywhereCityName(for: name, context: item.displayAddress),
            area: TripArea(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude)
        )
        finish(with: trip)
    }

    private func createListedTrip(in city: CityLocation.City) {
        finish(with: store.createTrip(name: "\(city.name) Trip", cityName: city.name))
    }

    private func finish(with trip: Trip) {
        HapticManager.shared.trigger(.success)
        onCreate(trip)
        dismiss()
    }
}
