import SwiftUI
import MapKit

struct WorldMapView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var progress = GlobalProgressManager.shared
    @StateObject private var cityVM = CityViewModel()

    @State private var selectedCity: CityLocation.City?
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20, longitude: 15),
            span: MKCoordinateSpan(latitudeDelta: 130, longitudeDelta: 280)
        )
    )

    private var cities: [CityLocation.City] { cityVM.allCities }

    private func isVisited(_ city: CityLocation.City) -> Bool {
        city.buildings.contains { progress.visitedIDs.contains($0.id) }
    }

    private func visitedStampCount(_ city: CityLocation.City) -> Int {
        city.buildings.filter { progress.visitedIDs.contains($0.id) }.count
    }

    private var visitedCityCount: Int {
        cities.filter { isVisited($0) }.count
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                map

                VStack(spacing: 0) {
                    Spacer()
                    if let city = selectedCity {
                        cityCallout(city: city)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    statsBar
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("World Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adventureOrange)
                }
            }
        }
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $cameraPosition) {
            ForEach(cities) { city in
                let coord = CLLocationCoordinate2D(
                    latitude: city.coordinate.lat,
                    longitude: city.coordinate.lon
                )
                let visited = isVisited(city)
                let isSelected = selectedCity == city

                Annotation(city.name, coordinate: coord, anchor: .bottom) {
                    CityMapPin(visited: visited, isSelected: isSelected)
                        .onTapGesture {
                            HapticManager.shared.trigger(.selection)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selectedCity = (selectedCity == city) ? nil : city
                            }
                        }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedCity = nil
            }
        }
    }

    // MARK: - City Callout

    @ViewBuilder
    private func cityCallout(city: CityLocation.City) -> some View {
        let visited = isVisited(city)
        let stamped = visitedStampCount(city)
        let total = city.buildings.count

        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(visited ? Color.adventureOrange.opacity(0.15) : Color(UIColor.tertiarySystemFill))
                    .frame(width: 44, height: 44)
                Image(systemName: visited ? "checkmark.seal.fill" : "mappin.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(visited ? Color.adventureOrange : Color.secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(city.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(city.country.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(stamped)/\(total)")
                    .font(.title3.bold())
                    .foregroundStyle(visited ? Color.adventureOrange : Color.secondary)
                Text("stamps")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(visitedCityCount)")
                        .font(.title2.bold())
                        .foregroundStyle(Color.adventureOrange)
                    Text("/ \(cities.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("cities visited")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                pinLegend(color: .adventureOrange, label: "Visited")
                pinLegend(color: Color(UIColor.systemGray3), label: "Not yet")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .safeAreaPadding(.bottom)
    }

    private func pinLegend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Map Pin

private struct CityMapPin: View {
    let visited: Bool
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(visited ? Color.adventureOrange : Color(UIColor.systemGray4))
                .frame(width: isSelected ? 14 : 8, height: isSelected ? 14 : 8)
            if isSelected {
                Circle()
                    .stroke(visited ? Color.adventureOrange : Color.secondary, lineWidth: 2)
                    .frame(width: 22, height: 22)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
