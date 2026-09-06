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
                        .onTapGesture { selectedBuilding = building }
                        .accessibilityLabel(isVisited ? "\(building.name), stamped" : "\(building.name), not yet visited")
                        .accessibilityHint("Tap to see building details")
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
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
        let span = MKCoordinateSpan(
            latitudeDelta: max((lats.max()! - lats.min()!) * 1.4, 0.01),
            longitudeDelta: max((lons.max()! - lons.min()!) * 1.4, 0.01)
        )
        position = .region(MKCoordinateRegion(center: center, span: span))
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
