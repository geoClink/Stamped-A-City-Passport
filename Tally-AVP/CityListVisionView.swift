//
//  CityListVisionView.swift
//  Tally-AVP
//
//  Shows all cities that have a bundled USDZ model.
//  Tapping a city card opens the volumetric window.
//

import SwiftUI

struct CityListVisionView: View {

    @Environment(\.openWindow) private var openWindow

    // Cities that have a .usdz in the bundle — expand this as you generate more cities.
    private let availableCities: [String] = {
        ["Detroit", "Chicago", "Boston", "New York"].filter {
            Bundle.main.url(forResource: $0.lowercased(), withExtension: "usdz") != nil
        }
    }()

    // Read visited building IDs from the same UserDefaults key the iOS app writes.
    private var visitedIDs: Set<String> {
        let saved = UserDefaults.standard.stringArray(forKey: "GlobalVisitedBuildingsKey") ?? []
        return Set(saved)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if availableCities.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 20)], spacing: 20) {
                        ForEach(availableCities, id: \.self) { city in
                            CityCard(cityName: city, visitedIDs: visitedIDs) {
                                openWindow(id: "city-volume", value: city)
                            }
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Stamped! City Passports")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No city models available yet.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Generate a city USDZ using the Python tool\nand add it to the Tally-AVP target.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(48)
    }
}

// MARK: - City card

private struct CityCard: View {
    let cityName: String
    let visitedIDs: Set<String>
    let onOpen: () -> Void

    private var buildings: [Building] { loadBuildings(for: cityName) }
    private var visitedCount: Int { buildings.filter { visitedIDs.contains($0.id) }.count }
    private var progress: Double {
        buildings.isEmpty ? 0 : Double(visitedCount) / Double(buildings.count)
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "building.2.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Spacer()
                    Image(systemName: "arrow.up.forward.app")
                        .foregroundStyle(.secondary)
                }

                Text(cityName)
                    .font(.title3.bold())

                Text("\(visitedCount) / \(buildings.count) landmarks")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ProgressView(value: progress)
                    .tint(.orange)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16))
        .hoverEffect()
    }
}

// MARK: - Helpers

/// Loads buildings for a city directly from BuildingRegistry.json.
/// The Building type must be added to the Tally-AVP target from the iOS Models folder.
func loadBuildings(for cityName: String) -> [Building] {
    guard let url  = Bundle.main.url(forResource: "BuildingRegistry", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let dict = try? JSONDecoder().decode([String: [Building]].self, from: data)
    else { return [] }
    return dict[cityName] ?? []
}
