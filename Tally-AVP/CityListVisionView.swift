//
//  CityListVisionView.swift
//  Tally-AVP
//
//  Main window: every city in a searchable sidebar, with the selected city's
//  photoreal 3D map on the right.
//

import SwiftUI

struct CityListVisionView: View {

    private let store = VisionStore.shared
    @State private var selectedCity: String?
    @State private var searchText = ""

    private var filteredCities: [String] {
        guard !searchText.isEmpty else { return store.cityNames }
        return store.cityNames.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationSplitView {
            List(filteredCities, id: \.self, selection: $selectedCity) { city in
                CityRow(
                    cityName: city,
                    visitedCount: store.visitedCount(for: city),
                    total: store.buildings(for: city).count
                )
            }
            .navigationTitle("Stamped!")
            .searchable(text: $searchText, prompt: "Search cities")
        } detail: {
            if let city = selectedCity {
                CityMapVisionView(cityName: city)
                    .id(city)   // fresh map + camera for each city
            } else {
                ContentUnavailableView(
                    "Pick a City",
                    systemImage: "globe.americas.fill",
                    description: Text("Fly through \(store.cityNames.count) cities in 3D and explore their landmarks.")
                )
            }
        }
        .onAppear {
            if selectedCity == nil { selectedCity = store.cityNames.contains("New York") ? "New York" : store.cityNames.first }
        }
    }
}

// MARK: - City row

private struct CityRow: View {
    let cityName: String
    let visitedCount: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(cityName).font(.headline)
                Spacer()
                if total > 0 && visitedCount == total {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.orange)
                }
            }
            Text("\(visitedCount) / \(total) stamped")
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: total == 0 ? 0 : Double(visitedCount) / Double(total))
                .tint(.orange)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Helpers

/// Landmarks for a city. Used by the Detroit volume and immersive views.
@MainActor
func loadBuildings(for cityName: String) -> [Building] {
    VisionStore.shared.buildings(for: cityName)
}
