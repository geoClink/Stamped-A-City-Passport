import SwiftUI
import MapKit

struct WorldMapView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var progress = GlobalProgressManager.shared
    @StateObject private var cityVM = CityViewModel()

    @State private var selectedCity: CityLocation.City?
    @State private var cityDetailToShow: CityLocation.City?
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20, longitude: 15),
            span: MKCoordinateSpan(latitudeDelta: 130, longitudeDelta: 280)
        )
    )

    /// What the map shows now and how wide it is, for grouping pins that would overlap.
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var mapWidth: CGFloat = 0

    private var cities: [CityLocation.City] { cityVM.allCities }

    private static func coordinate(of city: CityLocation.City) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: city.coordinate.lat, longitude: city.coordinate.lon)
    }

    /// Pins grouped into numbered bubbles when zoomed out. The selected city
    /// always keeps its own pin, so its callout never points at a bubble.
    private var clusters: [MapCluster<CityLocation.City>] {
        let others = cities.filter { $0 != selectedCity }
        var result = MapClusterer.clusters(
            of: others,
            coordinateOf: Self.coordinate(of:),
            region: visibleRegion,
            mapWidth: mapWidth
        )
        if let selectedCity, cities.contains(selectedCity) {
            result.append(MapCluster(items: [selectedCity], coordinate: Self.coordinate(of: selectedCity)))
        }
        return result
    }

    private func isVisited(_ city: CityLocation.City) -> Bool {
        city.buildings.contains { progress.visitedIDs.contains($0.id) }
    }

    private func visitedStampCount(_ city: CityLocation.City) -> Int {
        city.buildings.filter { progress.visitedIDs.contains($0.id) }.count
    }

    /// Real cities only; campuses are counted on their own, so the total is 140, not 241
    private var visitedCityCount: Int {
        CityLocation.City.cityCases.filter { isVisited($0) }.count
    }

    private var visitedCampusCount: Int {
        CityLocation.City.campusCases.filter { isVisited($0) }.count
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
                ToolbarItem(placement: .closeSheet) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adventureOrange)
                }
            }
            .sheet(item: $cityDetailToShow) { city in
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            CityDetailView(city: city)
                        }
                    }
                    .background(Color(UIColor.systemGroupedBackground))
                    .navigationTitle(city.name)
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $cameraPosition) {
            ForEach(clusters) { cluster in
                if cluster.isCluster {
                    Annotation("", coordinate: cluster.coordinate, anchor: .center) {
                        MapClusterBubble(count: cluster.items.count, anyVisited: cluster.items.contains(where: isVisited))
                            .onTapGesture { zoom(into: cluster) }
                    }
                    .annotationTitles(.hidden)
                } else {
                    let city = cluster.items[0]
                    let visited = isVisited(city)
                    let isSelected = selectedCity == city

                    Annotation(city.name, coordinate: cluster.coordinate, anchor: .bottom) {
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
        }
        // Regroup the pins once the map stops moving
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleRegion = context.region
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { mapWidth = $0 }
        .mapStyle(.standard(elevation: .realistic))
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedCity = nil
            }
        }
    }

    /// Tapping a bubble zooms in until its pins come apart.
    private func zoom(into cluster: MapCluster<CityLocation.City>) {
        HapticManager.shared.trigger(.selection)
        let region = cluster.zoomRegion(coordinateOf: Self.coordinate(of:), minimumSpan: 0.6)
        withAnimation(.easeInOut(duration: 0.6)) {
            cameraPosition = .region(region)
        }
    }

    // MARK: - City Callout

    @ViewBuilder
    private func cityCallout(city: CityLocation.City) -> some View {
        let visited = isVisited(city)
        let stamped = visitedStampCount(city)
        let total = city.buildings.count

        VStack(spacing: 0) {
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
                    Text(city.country.localizedName)
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
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 20)

            Button {
                HapticManager.shared.trigger(.selection)
                cityDetailToShow = city
            } label: {
                HStack {
                    Text("View City")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color.adventureOrange)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Stats Bar

    private func statCount(_ visited: Int, of total: Int, label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(visited)")
                    .font(.title2.bold())
                    .foregroundStyle(Color.adventureOrange)
                Text("/ \(total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statsBar: some View {
        // Counts on top, the pin key underneath, so neither gets squeezed
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 24) {
                statCount(visitedCityCount, of: CityLocation.City.cityCases.count, label: "cities visited")
                statCount(visitedCampusCount, of: CityLocation.City.campusCases.count, label: "campuses visited")
                Spacer(minLength: 0)
            }
            HStack(spacing: 16) {
                pinLegend(visited: true, label: "Visited")
                pinLegend(visited: false, label: "Not yet")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .safeAreaPadding(.bottom)
    }

    private func pinLegend(visited: Bool, label: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(visited ? Color.adventureOrange : Color.white)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle().stroke(
                            visited ? Color.white : Color(UIColor.systemGray2),
                            lineWidth: visited ? 2 : 1.5
                        )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
            }
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
            if visited {
                // Solid orange with white border — pops on any map background
                Circle()
                    .fill(Color.adventureOrange)
                    .frame(width: isSelected ? 20 : 14, height: isSelected ? 20 : 14)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 2.5)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            } else {
                // Hollow white with gray outline — clearly "not yet"
                Circle()
                    .fill(Color.white)
                    .frame(width: isSelected ? 16 : 10, height: isSelected ? 16 : 10)
                    .overlay(
                        Circle().stroke(Color(UIColor.systemGray2), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
            }

            if isSelected {
                Circle()
                    .stroke(visited ? Color.adventureOrange : Color(UIColor.systemGray2), lineWidth: 2)
                    .frame(width: visited ? 30 : 24, height: visited ? 30 : 24)
                    .opacity(0.5)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
