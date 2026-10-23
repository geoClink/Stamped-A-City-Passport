//
//  CityMapView.swift
//  Stamped! A City Passport
//
//  Photoreal 3D map of a city's landmarks.
//  • Tap a pin to fly to it; a floating card shows quick actions and View Details.
//  • ◀ ▶ on the card steps through landmarks in walking order.
//  • Tour flies between every landmark automatically.
//  • Filter by visited / stamped / want to visit / architectural style.
//

import SwiftUI
import MapKit

struct CityMapView: View {
    let buildings: [Building]
    let cityName: String
    /// Needed to stamp landmarks and open BuildingDetailView, like the landmark list does.
    @ObservedObject var viewModel: CityDetailViewModel

    // Watched live so pins and the card update the moment something is stamped or saved
    @ObservedObject private var progress = GlobalProgressManager.shared

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedBuilding: Building?
    /// A place the user saved from Apple Maps search (only one card shows at a time).
    @State private var selectedPlace: CustomPlace?
    @State private var showingAddPlace = false
    /// Website or ticket page shown inside the app.
    @State private var browserLink: BrowserLink?
    /// The building page currently pushed onto the map's navigation stack.
    @State private var detailBuilding: Building?
    /// onAppear also fires when coming Back from a building page; only frame the city the first time.
    @State private var hasFramedCity = false

    @State private var filter: MapFilter = .all
    @State private var styleFilter: String?

    @State private var lookAroundScene: MKLookAroundScene?
    @State private var showingLookAround = false

    @State private var tourTask: Task<Void, Never>?
    @State private var userLocation: CLLocation?

    @AppStorage("haptics_enabled") private var hapticsEnabled = true
    /// Satellite photos (default) or the regular drawn map; remembered between launches.
    @AppStorage("map_uses_satellite") private var useSatellite = true
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    // MARK: - Derived data

    private var mappableBuildings: [Building] {
        buildings.filter { $0.latitude != nil && $0.longitude != nil }
    }

    /// Landmarks that pass the current filter — these get pins, arrows and the tour.
    private var filteredBuildings: [Building] {
        mappableBuildings.filter { building in
            let passesFilter: Bool
            switch filter {
            case .all:        passesFilter = true
            case .notVisited: passesFilter = !progress.isVisited(building.id)
            case .stamped:    passesFilter = progress.isVisited(building.id)
            case .wishlist:   passesFilter = progress.isWishlisted(building.id)
            }
            return passesFilter && (styleFilter == nil || building.buildingStyle == styleFilter)
        }
    }

    /// The user's own saved places in this city. They're wishlist items, so they
    /// only show for "All" and "Want to Visit", and not while a style is chosen.
    private var visibleCustomPlaces: [CustomPlace] {
        guard styleFilter == nil, filter == .all || filter == .wishlist else { return [] }
        return progress.customPlaces(in: cityName)
    }

    /// Changes whenever a different landmark or place is selected (drives Look Around loading).
    private var selectionKey: String? {
        selectedBuilding?.id ?? selectedPlace?.id
    }

    private var selectionCoordinate: CLLocationCoordinate2D? {
        if let building = selectedBuilding { return coordinate(of: building) }
        return selectedPlace?.coordinate
    }

    private var styles: [String] {
        Set(mappableBuildings.map(\.buildingStyle)).filter { !$0.isEmpty }.sorted()
    }

    /// Middle of the city's landmarks. The median ignores one far-away landmark
    /// (an airport, say) that would drag an average off the city centre.
    private var cityCenter: CLLocationCoordinate2D? {
        guard !mappableBuildings.isEmpty else { return nil }
        let lats = mappableBuildings.map { $0.latitude! }.sorted()
        let lons = mappableBuildings.map { $0.longitude! }.sorted()
        return CLLocationCoordinate2D(latitude: lats[lats.count / 2], longitude: lons[lons.count / 2])
    }

    /// The user's location, but only if they're actually in this city (within 30 km).
    private var userLocationInCity: CLLocationCoordinate2D? {
        guard let user = userLocation?.coordinate, let center = cityCenter,
              distanceMeters(user, center) < 30_000 else { return nil }
        return user
    }

    /// Filtered landmarks in walking order: start nearest the user (or the city centre),
    /// then always hop to the closest landmark not yet visited on the route.
    private var route: [Building] {
        guard var current = userLocationInCity ?? cityCenter else { return [] }
        var remaining = filteredBuildings
        var ordered: [Building] = []
        while !remaining.isEmpty {
            let nextIndex = remaining.indices.min { a, b in
                distanceMeters(current, coordinate(of: remaining[a])) < distanceMeters(current, coordinate(of: remaining[b]))
            }!
            let next = remaining.remove(at: nextIndex)
            ordered.append(next)
            current = coordinate(of: next)
        }
        return ordered
    }

    /// The closest landmark the user hasn't stamped yet; its pin pulses.
    private var upNext: Building? {
        route.first { !progress.isVisited($0.id) }
    }

    private var isTouring: Bool { tourTask != nil }

    // MARK: - Body

    var body: some View {
        Map(position: $position) {
            ForEach(filteredBuildings) { building in
                let isVisited = progress.isVisited(building.id)
                Annotation(building.name, coordinate: coordinate(of: building), anchor: .bottom) {
                    PinView(
                        isVisited: isVisited,
                        isWishlisted: progress.isWishlisted(building.id),
                        isUpNext: building.id == upNext?.id,
                        isSelected: building.id == selectedBuilding?.id
                    )
                    .onTapGesture {
                        stopTour()
                        flyTo(building)
                    }
                    .accessibilityLabel(isVisited ? "\(building.name), stamped" : "\(building.name), not yet visited")
                    .accessibilityHint("Shows this landmark's card")
                    .accessibilityAddTraits(.isButton)
                }
            }
            ForEach(visibleCustomPlaces) { place in
                Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) {
                    CustomPlacePin(category: place.category, isSelected: place.id == selectedPlace?.id)
                        .onTapGesture {
                            stopTour()
                            flyTo(place)
                        }
                        .accessibilityLabel("\(place.name), your saved place")
                        .accessibilityAddTraits(.isButton)
                }
            }
            if userLocationInCity != nil {
                UserAnnotation()
            }
        }
        // Satellite photos draped over Apple's 3D city scans (the same data as Flyover).
        // Cities without 3D coverage fall back to flat satellite imagery automatically.
        .mapStyle(useSatellite ? .imagery(elevation: .realistic) : .standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapPitchToggle()
        }
        .navigationTitle("\(cityName) Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear {
            guard !hasFramedCity else { return }
            hasFramedCity = true
            userLocation = currentLocationIfAllowed()
            fitCamera()
        }
        .onDisappear { stopTour() }
        .overlay(alignment: .bottom) {
            if let building = selectedBuilding {
                MapLandmarkCard(
                    building: building,
                    isVisited: progress.isVisited(building.id),
                    isWishlisted: progress.isWishlisted(building.id),
                    hasLookAround: lookAroundScene != nil,
                    stopLabel: stopLabel(for: building),
                    reduceTransparency: reduceTransparency,
                    onStamp: { stamp(building) },
                    onWishlist: { toggleWishlist(building) },
                    onLookAround: { showingLookAround = true },
                    onPrevious: { step(by: -1) },
                    onNext: { step(by: 1) },
                    onViewDetails: {
                        stopTour()
                        detailBuilding = building
                    },
                    onOpenTickets: { browserLink = BrowserLink(url: $0) },
                    onClose: {
                        stopTour()
                        selectedBuilding = nil
                    }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let place = selectedPlace {
                CustomPlaceCard(
                    place: place,
                    hasLookAround: lookAroundScene != nil,
                    reduceTransparency: reduceTransparency,
                    onLookAround: { showingLookAround = true },
                    onOpenWebPage: { browserLink = BrowserLink(url: $0) },
                    onRemove: {
                        withAnimation { progress.removeCustomPlace(place.id) }
                        selectedPlace = nil
                    },
                    onClose: { selectedPlace = nil }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                legend
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding()
            }
        }
        .overlay(alignment: .top) {
            if filteredBuildings.isEmpty {
                Text("No landmarks match this filter")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 12)
            }
        }
        .animation(.spring(duration: 0.35), value: selectionKey)
        // Fetch street-level imagery for the selected landmark or place, if Apple has it
        .task(id: selectionKey) {
            lookAroundScene = nil
            guard let target = selectionCoordinate else { return }
            let request = MKLookAroundSceneRequest(coordinate: target)
            lookAroundScene = try? await request.scene
        }
        .sheet(isPresented: $showingAddPlace) {
            if let center = cityCenter {
                AddPlaceSheet(cityName: cityName, cityCenter: center)
            }
        }
        .sheet(isPresented: $showingLookAround) {
            if let scene = lookAroundScene {
                ZStack(alignment: .topTrailing) {
                    LookAroundPreviewWrapper(scene: scene)
                        .ignoresSafeArea()
                    Button("Done") { showingLookAround = false }
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .padding()
                }
            }
        }
        .sheet(item: $browserLink) { link in
            InAppBrowser(url: link.url)
                .ignoresSafeArea()
        }
        .navigationDestination(item: $detailBuilding) { building in
            BuildingDetailView(building: building, viewModel: viewModel)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Picker("Show", selection: $filter) {
                    ForEach(MapFilter.allCases) { option in
                        Label(option.title, systemImage: option.icon).tag(option)
                    }
                }
                if styles.count > 1 {
                    Picker("Style", selection: $styleFilter) {
                        Text("All Styles").tag(String?.none)
                        ForEach(styles, id: \.self) { style in
                            Text(style).tag(String?.some(style))
                        }
                    }
                    .pickerStyle(.menu)
                }
            } label: {
                Image(systemName: filter == .all && styleFilter == nil
                      ? "line.3.horizontal.decrease.circle"
                      : "line.3.horizontal.decrease.circle.fill")
            }
            .accessibilityLabel("Filter landmarks")
        }
        ToolbarItem(placement: .topBarLeading) {
            Button {
                stopTour()
                showingAddPlace = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add a place to Want to Visit")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                useSatellite.toggle()
            } label: {
                Image(systemName: useSatellite ? "map" : "globe.americas.fill")
            }
            .accessibilityLabel(useSatellite ? "Show map view" : "Show satellite view")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isTouring ? stopTour() : startTour()
            } label: {
                Label(isTouring ? "Stop" : "Tour", systemImage: isTouring ? "stop.fill" : "play.fill")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(route.isEmpty)
            .accessibilityHint(isTouring ? "Stops the guided tour" : "Flies between every landmark automatically")
        }
    }

    // MARK: - Legend

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            LegendRow(color: .adventureOrange, label: "Stamped")
            LegendRow(color: .secondary, label: "Not yet visited")
            if upNext != nil {
                LegendRow(color: .adventureOrange, label: "Up next (pulsing)", isRing: true)
            }
            if !visibleCustomPlaces.isEmpty {
                LegendRow(color: .pink, label: "Your places")
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(reduceTransparency
                    ? AnyShapeStyle(Color(UIColor.secondarySystemBackground))
                    : AnyShapeStyle(.ultraThinMaterial))
        }
    }

    // MARK: - Actions

    private func stamp(_ building: Building) {
        withAnimation(.spring()) { viewModel.toggleVisited(for: building) }
        if hapticsEnabled { HapticManager.shared.trigger(progress.isVisited(building.id) ? .success : .warning) }
    }

    private func toggleWishlist(_ building: Building) {
        withAnimation(.spring()) { progress.toggleWishlist(building.id) }
        if hapticsEnabled { HapticManager.shared.trigger(.selection) }
    }

    /// Moves the card to the previous/next landmark in walking order.
    private func step(by offset: Int) {
        stopTour()
        let stops = route
        guard !stops.isEmpty else { return }
        let currentIndex = stops.firstIndex { $0.id == selectedBuilding?.id } ?? -1
        let nextIndex = (currentIndex + offset + stops.count) % stops.count
        flyTo(stops[nextIndex])
    }

    private func stopLabel(for building: Building) -> String? {
        let stops = route
        guard let index = stops.firstIndex(where: { $0.id == building.id }) else { return nil }
        return "Stop \(index + 1) of \(stops.count)"
    }

    /// Flies to each landmark in walking order, pausing on each so its card can be read.
    private func startTour() {
        let stops = route
        guard !stops.isEmpty else { return }
        tourTask = Task { @MainActor in
            for building in stops {
                if Task.isCancelled { break }
                flyTo(building, duration: 2.5)
                try? await Task.sleep(for: .seconds(7))
            }
            if !Task.isCancelled {
                selectedBuilding = nil
                withAnimation(.easeInOut(duration: 3)) { fitCamera() }
            }
            tourTask = nil
        }
    }

    private func stopTour() {
        tourTask?.cancel()
        tourTask = nil
    }

    // MARK: - Camera

    /// Frames the city's landmarks with a tilted camera so the buildings stand up in 3D.
    private func fitCamera() {
        guard let center = cityCenter else { return }
        // Fit most landmarks (80%), ignoring the farthest outliers
        let distances = mappableBuildings.map { distanceMeters(center, coordinate(of: $0)) }.sorted()
        let typicalSpread = distances[min(distances.count - 1, Int(Double(distances.count) * 0.8))]
        let distance = min(max(typicalSpread * 4, 2_500), 25_000)

        // A tilted camera (pitch) is what makes the buildings stand up in 3D.
        // Straight down (pitch 0) would look like a flat satellite photo.
        position = .camera(MapCamera(centerCoordinate: center, distance: distance, heading: 0, pitch: 60))
    }

    /// Swoops the camera down to a landmark and shows its card.
    private func flyTo(_ building: Building, duration: Double = 1.5) {
        let target = coordinate(of: building)
        // The card covers the bottom of the screen. Aiming the camera slightly
        // south of the building pushes the building up into the visible area.
        let aimPoint = CLLocationCoordinate2D(latitude: target.latitude - 0.0015, longitude: target.longitude)
        withAnimation(.easeInOut(duration: duration)) {
            position = .camera(MapCamera(centerCoordinate: aimPoint, distance: 700, heading: 0, pitch: 65))
        }
        selectedPlace = nil
        selectedBuilding = building
    }

    /// Same swoop for a place the user saved themselves.
    private func flyTo(_ place: CustomPlace) {
        let aimPoint = CLLocationCoordinate2D(latitude: place.latitude - 0.0015, longitude: place.longitude)
        withAnimation(.easeInOut(duration: 1.5)) {
            position = .camera(MapCamera(centerCoordinate: aimPoint, distance: 700, heading: 0, pitch: 65))
        }
        selectedBuilding = nil
        selectedPlace = place
    }

    // MARK: - Geometry helpers

    private func coordinate(of building: Building) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: building.latitude ?? 0, longitude: building.longitude ?? 0)
    }

    /// Straight-line distance in metres. A degree of longitude shrinks away from the equator.
    private func distanceMeters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let dx = (b.longitude - a.longitude) * 111_000 * cos(a.latitude * .pi / 180)
        let dy = (b.latitude - a.latitude) * 111_000
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Last known location, only if the user already granted location access (never prompts).
    private func currentLocationIfAllowed() -> CLLocation? {
        let manager = CLLocationManager()
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return manager.location
        default: return nil
        }
    }
}

// MARK: - Filter

enum MapFilter: String, CaseIterable, Identifiable {
    case all, notVisited, stamped, wishlist
    var id: Self { self }

    var title: String {
        switch self {
        case .all:        "All Landmarks"
        case .notVisited: "Not Visited"
        case .stamped:    "Stamped"
        case .wishlist:   "Want to Visit"
        }
    }

    var icon: String {
        switch self {
        case .all:        "building.2"
        case .notVisited: "circle.dashed"
        case .stamped:    "checkmark.seal"
        case .wishlist:   "heart"
        }
    }
}

// MARK: - Pin

private struct PinView: View {
    let isVisited: Bool
    let isWishlisted: Bool
    let isUpNext: Bool
    let isSelected: Bool

    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .callout) private var pinSize: CGFloat = 32
    @ScaledMetric(relativeTo: .caption) private var pinIconSize: CGFloat = 13

    var body: some View {
        ZStack {
            // Expanding ring on the closest unvisited landmark
            if isUpNext {
                Circle()
                    .stroke(Color.adventureOrange, lineWidth: 3)
                    .frame(width: pinSize, height: pinSize)
                    .scaleEffect(pulse ? 1.9 : 1)
                    .opacity(pulse ? 0 : 0.9)
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
                    }
            }
            Circle()
                .fill(isVisited ? Color.adventureOrange : Color(UIColor.systemGray3))
                .frame(width: pinSize, height: pinSize)
                .overlay {
                    if isUpNext { Circle().stroke(Color.adventureOrange, lineWidth: 3) }
                }
                .shadow(radius: 3)
            Image(systemName: isVisited ? "checkmark" : "building.columns")
                .font(.system(size: pinIconSize, weight: .bold))
                .foregroundColor(.white)
        }
        .overlay(alignment: .topTrailing) {
            if isWishlisted {
                Image(systemName: "heart.fill")
                    .font(.system(size: pinIconSize * 0.8))
                    .foregroundStyle(.white, .pink)
                    .padding(3)
                    .background(Color.pink, in: Circle())
                    .offset(x: 6, y: -6)
            }
        }
        .scaleEffect(isSelected ? 1.3 : 1)
        .animation(.spring(duration: 0.3), value: isSelected)
    }
}

// MARK: - Floating landmark card

private struct MapLandmarkCard: View {
    let building: Building
    let isVisited: Bool
    let isWishlisted: Bool
    let hasLookAround: Bool
    let stopLabel: String?
    let reduceTransparency: Bool
    let onStamp: () -> Void
    let onWishlist: () -> Void
    let onLookAround: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onViewDetails: () -> Void
    let onOpenTickets: (URL) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                WikiBuildingPhoto(building: building, height: 84)
                    .frame(width: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    // New identity per building, so the photo reloads instead of
                    // keeping the previous landmark's image when the card switches
                    .id(building.id)

                VStack(alignment: .leading, spacing: 4) {
                    Text(building.name)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text("\(building.buildingStyle) · Built \(String(building.yearBuilt))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if let stopLabel {
                        Text(stopLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Close")
            }

            // Quick actions
            HStack(spacing: 8) {
                QuickAction(title: isVisited ? "Stamped" : "Stamp",
                            systemImage: isVisited ? "checkmark.seal.fill" : "checkmark.seal",
                            isOn: isVisited, action: onStamp)
                QuickAction(title: isWishlisted ? "Saved" : "Want to Go",
                            systemImage: isWishlisted ? "heart.fill" : "heart",
                            isOn: isWishlisted, action: onWishlist)
                QuickAction(title: "Look Around", systemImage: "binoculars",
                            isOn: false, action: onLookAround)
                    .disabled(!hasLookAround)
                    .opacity(hasLookAround ? 1 : 0.4)
            }

            HStack(spacing: 8) {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left").frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Previous landmark")

                Button(action: onViewDetails) {
                    Label("View Details", systemImage: "building.columns")
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Opens the full page for \(building.name)")

                Button(action: onNext) {
                    Image(systemName: "chevron.right").frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Next landmark")
            }

            // Stadiums, theatres, concert halls: show what's on there
            if let lat = building.latitude, let lon = building.longitude {
                PlaceEventsView(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    placeName: building.name,
                    includeNearby: false,
                    onOpenTickets: onOpenTickets
                )
            }
        }
        .tint(.adventureOrange)
        .padding(16)
        .frame(maxWidth: 520)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(reduceTransparency
                    ? AnyShapeStyle(Color(UIColor.secondarySystemBackground))
                    : AnyShapeStyle(.regularMaterial))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        }
    }
}

private struct QuickAction: View {
    let title: String
    let systemImage: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .contentTransition(.symbolEffect(.replace))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .foregroundStyle(isOn ? Color.white : Color.adventureOrange)
        .background(isOn ? Color.adventureOrange : Color.clear, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Custom place pin and card

private struct CustomPlacePin: View {
    let category: String?
    let isSelected: Bool
    @ScaledMetric(relativeTo: .callout) private var pinSize: CGFloat = 32
    @ScaledMetric(relativeTo: .caption) private var pinIconSize: CGFloat = 13

    var body: some View {
        Image(systemName: CustomPlace.icon(forCategory: category))
            .font(.system(size: pinIconSize, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: pinSize, height: pinSize)
            .background(Color.pink, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(radius: 3)
            .scaleEffect(isSelected ? 1.3 : 1)
            .animation(.spring(duration: 0.3), value: isSelected)
    }
}

private struct CustomPlaceCard: View {
    let place: CustomPlace
    let hasLookAround: Bool
    let reduceTransparency: Bool
    let onLookAround: () -> Void
    let onOpenWebPage: (URL) -> Void
    let onRemove: () -> Void
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL

    private var mapsURL: URL? {
        let name = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "maps://?ll=\(place.latitude),\(place.longitude)&q=\(name)")
    }

    private var phoneURL: URL? {
        guard let phone = place.phoneNumber else { return nil }
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: CustomPlace.icon(forCategory: place.category))
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.pink, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name).font(.headline).lineLimit(2)
                    if let address = place.address {
                        Text(address).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Label("Your place", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.pink)
                }
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Close")
            }

            HStack(spacing: 8) {
                QuickAction(title: "Look Around", systemImage: "binoculars", isOn: false, action: onLookAround)
                    .disabled(!hasLookAround)
                    .opacity(hasLookAround ? 1 : 0.4)
                if let website = place.websiteURL {
                    QuickAction(title: "Website", systemImage: "safari", isOn: false) { onOpenWebPage(website) }
                }
                if let phoneURL {
                    QuickAction(title: "Call", systemImage: "phone", isOn: false) { openURL(phoneURL) }
                }
                if let mapsURL {
                    QuickAction(title: "Directions", systemImage: "arrow.triangle.turn.up.right.diamond", isOn: false) {
                        openURL(mapsURL)
                    }
                }
            }

            PlaceEventsView(coordinate: place.coordinate, placeName: place.name,
                            onOpenTickets: onOpenWebPage)

            Button(role: .destructive, action: onRemove) {
                Label("Remove from Want to Visit", systemImage: "heart.slash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .tint(.adventureOrange)
        .padding(16)
        .frame(maxWidth: 520)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(reduceTransparency
                    ? AnyShapeStyle(Color(UIColor.secondarySystemBackground))
                    : AnyShapeStyle(.regularMaterial))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        }
    }
}

// MARK: - Legend row

private struct LegendRow: View {
    let color: Color
    let label: String
    var isRing = false

    var body: some View {
        HStack(spacing: 6) {
            if isRing {
                Circle().stroke(color, lineWidth: 2).frame(width: 10, height: 10)
            } else {
                Circle().fill(color).frame(width: 10, height: 10)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
