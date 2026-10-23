//
//  CityMapView.swift
//  Stamped! A City Passport
//

import SwiftUI
import MapKit

struct CityMapView: View {
    let buildings: [Building]
    let visitedIDs: Set<String>
    let cityName: String

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedBuilding: Building? = nil

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var mappableBuildings: [Building] {
        buildings.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var body: some View {
        Map(position: $position) {
            ForEach(mappableBuildings) { building in
                let isVisited = visitedIDs.contains(building.id)
                let coord = CLLocationCoordinate2D(
                    latitude: building.latitude!,
                    longitude: building.longitude!
                )
                Annotation(building.name, coordinate: coord, anchor: .bottom) {
                    PinView(isVisited: isVisited)
                        .onTapGesture { flyTo(building, at: coord) }
                        .accessibilityLabel(isVisited ? "\(building.name), stamped" : "\(building.name), not yet visited")
                        .accessibilityHint("Tap to see building details")
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
        // Satellite photos draped over Apple's 3D city scans (the same data as Flyover).
        // Cities without 3D coverage fall back to flat satellite imagery automatically.
        .mapStyle(.imagery(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapPitchToggle()
        }
        .navigationTitle("\(cityName) Map")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { fitCamera() }
        .sheet(item: $selectedBuilding) { building in
            BuildingMapCallout(building: building, isVisited: visitedIDs.contains(building.id))
        }
        .overlay(alignment: .bottomTrailing) {
            legend
                .padding()
        }
    }

    // MARK: - Legend

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            LegendRow(color: .adventureOrange, label: "Stamped")
            LegendRow(color: .secondary, label: "Not yet visited")
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(reduceTransparency
                    ? AnyShapeStyle(Color(UIColor.secondarySystemBackground))
                    : AnyShapeStyle(.ultraThinMaterial))
        }
    }

    // MARK: - Camera

    private func fitCamera() {
        let coords = mappableBuildings.compactMap { b -> CLLocationCoordinate2D? in
            guard let lat = b.latitude, let lon = b.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        guard !coords.isEmpty else { return }

        let lats = coords.map { $0.latitude }
        let lons = coords.map { $0.longitude }
        let center = CLLocationCoordinate2D(
            latitude: (lats.max()! + lats.min()!) / 2,
            longitude: (lons.max()! + lons.min()!) / 2
        )
        // Convert the landmarks' spread from degrees to metres so we know how far back
        // the camera has to sit. A degree of longitude shrinks the further you are from the equator.
        let latSpanMeters = (lats.max()! - lats.min()!) * 111_000
        let lonSpanMeters = (lons.max()! - lons.min()!) * 111_000 * cos(center.latitude * .pi / 180)
        let distance = max(max(latSpanMeters, lonSpanMeters) * 3.5, 2_500)

        // A tilted camera (pitch) is what makes the buildings stand up in 3D.
        // Straight down (pitch 0) would look like a flat satellite photo.
        position = .camera(MapCamera(
            centerCoordinate: center,
            distance: distance,
            heading: 0,
            pitch: 60
        ))
    }

    /// Swoops the camera down to a landmark, then opens its info sheet.
    private func flyTo(_ building: Building, at coordinate: CLLocationCoordinate2D) {
        // The sheet covers the bottom half of the screen. Aiming the camera slightly
        // south of the building pushes the building up into the visible top half.
        let aimPoint = CLLocationCoordinate2D(
            latitude: coordinate.latitude - 0.0015,
            longitude: coordinate.longitude
        )
        withAnimation(.easeInOut(duration: 1.5)) {
            position = .camera(MapCamera(
                centerCoordinate: aimPoint,
                distance: 700,
                heading: 0,
                pitch: 65
            ))
        }
        selectedBuilding = building
    }
}

// MARK: - Pin

private struct PinView: View {
    let isVisited: Bool

    @ScaledMetric(relativeTo: .callout) private var pinSize: CGFloat = 32
    @ScaledMetric(relativeTo: .caption) private var pinIconSize: CGFloat = 13

    var body: some View {
        ZStack {
            Circle()
                .fill(isVisited ? Color.adventureOrange : Color(UIColor.systemGray3))
                .frame(width: pinSize, height: pinSize)
                .shadow(radius: 3)
            Image(systemName: isVisited ? "checkmark" : "building.columns")
                .font(.system(size: pinIconSize, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Callout sheet

struct BuildingMapCallout: View {
    let building: Building
    let isVisited: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Wikipedia photo at the top of the sheet
            WikiBuildingPhoto(building: building, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding([.horizontal, .top])

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(building.name)
                            .font(.headline)
                        Text("\(building.buildingStyle) · Built \(String(building.yearBuilt))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isVisited {
                        Label("Stamped", systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.adventureOrange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.adventureOrange.opacity(0.12), in: Capsule())
                    }
                }

                if let lat = building.latitude, let lon = building.longitude {
                    let encodedName = building.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "maps://?ll=\(lat),\(lon)&q=\(encodedName)") {
                        Link(destination: url) {
                            Label("Open in Maps", systemImage: "map")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.adventureOrange)
                        .accessibilityLabel("Open \(building.name) in Maps")
                        .accessibilityHint("Opens the Maps app")
                    }
                }
            }
            .padding()
        }
        .presentationDetents([.fraction(0.52)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Legend row

private struct LegendRow: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
