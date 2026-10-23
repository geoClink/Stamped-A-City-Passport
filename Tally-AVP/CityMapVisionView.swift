//
//  CityMapVisionView.swift
//  Tally-AVP
//
//  Photoreal 3D map of one city with a pin for every landmark — the same Apple
//  3D city data as the iPhone app's map. Tap a pin to fly to it and see its story.
//

import SwiftUI
import MapKit

struct CityMapVisionView: View {

    let cityName: String

    @Environment(\.openWindow) private var openWindow
    private let store = VisionStore.shared
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedBuilding: Building?

    private var mappableBuildings: [Building] {
        store.buildings(for: cityName).filter { $0.latitude != nil && $0.longitude != nil }
    }

    /// Only cities run through tools/city-generator have a bundled 3D model.
    private var hasCityModel: Bool {
        Bundle.main.url(forResource: cityName.lowercased(), withExtension: "usdz") != nil
    }

    var body: some View {
        Map(position: $position) {
            ForEach(mappableBuildings) { building in
                let coordinate = CLLocationCoordinate2D(latitude: building.latitude!, longitude: building.longitude!)
                Annotation(building.name, coordinate: coordinate, anchor: .bottom) {
                    LandmarkPin(isVisited: store.visitedIDs.contains(building.id),
                                isSelected: selectedBuilding?.id == building.id)
                        .onTapGesture { flyTo(building, at: coordinate) }
                        .hoverEffect()
                        .accessibilityLabel(building.name)
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
        // Satellite photos draped over Apple's 3D city scans. Cities without
        // 3D coverage fall back to flat satellite imagery automatically.
        .mapStyle(.imagery(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapPitchToggle()
        }
        .navigationTitle(cityName)
        .toolbar {
            if hasCityModel {
                ToolbarItem {
                    Button {
                        openWindow(id: "city-volume", value: cityName)
                    } label: {
                        Label("Open 3D Model", systemImage: "cube.transparent")
                    }
                }
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let building = selectedBuilding {
                LandmarkCard(building: building,
                             isVisited: store.visitedIDs.contains(building.id)) {
                    selectedBuilding = nil
                }
                .padding(24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: selectedBuilding?.id)
        .onAppear { fitCamera() }
    }

    // MARK: - Camera

    /// Frames the city's landmarks with a tilted camera so the buildings stand up in 3D.
    /// Uses the median landmark as the centre, so one far-away landmark (an airport,
    /// say) doesn't drag the whole view off the city centre.
    private func fitCamera() {
        guard !mappableBuildings.isEmpty else { return }
        let lats = mappableBuildings.map { $0.latitude! }.sorted()
        let lons = mappableBuildings.map { $0.longitude! }.sorted()
        let center = CLLocationCoordinate2D(latitude: lats[lats.count / 2], longitude: lons[lons.count / 2])

        // Distance from the centre to each landmark, in metres
        let metresPerDegreeLon = 111_000 * cos(center.latitude * .pi / 180)
        let distances = mappableBuildings.map { building -> Double in
            let dx = (building.longitude! - center.longitude) * metresPerDegreeLon
            let dy = (building.latitude! - center.latitude) * 111_000
            return (dx * dx + dy * dy).squareRoot()
        }.sorted()
        // Fit most landmarks (80%), ignoring the farthest outliers
        let typicalSpread = distances[min(distances.count - 1, Int(Double(distances.count) * 0.8))]
        let distance = min(max(typicalSpread * 4, 2_500), 25_000)

        position = .camera(MapCamera(centerCoordinate: center, distance: distance, heading: 0, pitch: 60))
    }

    /// Swoops the camera down to a landmark and shows its card.
    private func flyTo(_ building: Building, at coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 1.5)) {
            position = .camera(MapCamera(centerCoordinate: coordinate, distance: 700, heading: 0, pitch: 65))
        }
        selectedBuilding = building
    }
}

// MARK: - Pin

private struct LandmarkPin: View {
    let isVisited: Bool
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isVisited ? Color.orange : Color.gray)
                .frame(width: isSelected ? 44 : 34, height: isSelected ? 44 : 34)
                .shadow(radius: 4)
            Image(systemName: isVisited ? "checkmark" : "building.columns")
                .font(.system(size: isSelected ? 18 : 14, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Landmark card

private struct LandmarkCard: View {
    let building: Building
    let isVisited: Bool
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(building.name).font(.title2.bold())
                    Text("\(building.buildingStyle) · Built \(String(building.yearBuilt))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonBorderShape(.circle)
                .accessibilityLabel("Close")
            }

            if isVisited {
                Label("Stamped", systemImage: "checkmark.seal.fill")
                    .font(.callout.bold())
                    .foregroundStyle(.orange)
            }

            ScrollView {
                Text(building.description)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 160)

            if !building.architect.isEmpty {
                Label(building.architect, systemImage: "person.crop.square")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 420)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 28))
    }
}
