//
//  CityMapView.swift
//  Stamped! A City Passport
//
//  Photoreal 3D map of a city's landmarks.
//  • Tap a pin to fly to it; a floating card shows quick actions and View Details.
//  • ◀ ▶ on the card steps through landmarks in walking order
//    (or through the trip's stops while touring a trip).
//  • Tour flies between every landmark automatically, or through one of your
//    trips day by day (each day's route first, then its stops in order).
//  • Filter by visited / stamped / want to visit / architectural style.
//  • Chips (Landmarks · Food · Coffee · Culture) show Apple Maps places; tap one
//    for Apple's place card and a Want to Visit button.
//

import SwiftUI
import MapKit

struct CityMapView: View {
    let buildings: [Building]
    let cityName: String
    /// Needed to stamp landmarks and open BuildingDetailView, like the landmark list does.
    @ObservedObject var viewModel: CityDetailViewModel
    /// Set when the map is opened from a trip's "Tour" button: that trip's tour starts on open.
    var tripToTour: String? = nil
    /// False when the map is the Mac window's main view rather than a sheet, so there is nothing to close.
    var showsDoneButton = true

    // Watched live so pins and the card update the moment something is stamped or saved
    @ObservedObject private var progress = GlobalProgressManager.shared
    @ObservedObject private var tripStore = TripStore.shared

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedBuilding: Building?
    /// A place the user saved from Apple Maps search (only one card shows at a time).
    @State private var selectedPlace: CustomPlace?
    @State private var showingAddPlace = false
    /// The landmark or saved place being added to a trip, if the picker is open.
    @State private var addToTrip: AddToTripRequest?
    /// Website or ticket page shown inside the app.
    @State private var browserLink: BrowserLink?
    /// The building page currently pushed onto the map's navigation stack.
    @State private var detailBuilding: Building?
    /// onAppear also fires when coming Back from a building page; only frame the city the first time.
    @State private var hasFramedCity = false

    @State private var filter: MapFilter = .all
    @State private var styleFilter: String?
    /// Which Apple Maps places to show alongside the landmarks (the chips at the top).
    @State private var category: MapCategory = .landmarks

    /// An Apple Maps place (restaurant, café, museum…) the user tapped on the map.
    @State private var selectedFeature: MapFeature?
    /// Its full details, once loaded; showing this opens Apple's place card.
    @State private var tappedApplePlace: TappedApplePlace?

    @State private var lookAroundScene: MKLookAroundScene?
    @State private var showingLookAround = false

    @State private var tourTask: Task<Void, Never>?
    /// The trip being toured, when the Tour follows a trip instead of every landmark.
    @State private var touringTrip: Trip?
    /// "Day 2 · Stop 3 of 5" on the card while touring a trip.
    @State private var tripTourLabel: String?
    /// Which of the trip tour's steps the card is showing, so ◀ ▶ can move from it.
    @State private var tripTourStepIndex: Int?
    /// "Day 2 · Sat, Oct 24", shown at the top between days of a trip tour.
    @State private var tripTourDayBanner: String?
    /// The current day's walking route, drawn as a dashed line while touring a trip.
    @State private var tripTourLine: [CLLocationCoordinate2D] = []
    @State private var userLocation: CLLocation?

    @AppStorage("haptics_enabled") private var hapticsEnabled = true
    /// Satellite photos (default) or the regular drawn map; remembered between launches.
    @AppStorage("map_uses_satellite") private var useSatellite = true
    /// The map key shows by itself once, then lives behind the "?" button
    @AppStorage("map_legend_seen") private var hasSeenMapLegend = false
    @State private var showingLegend = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss

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
        Set(mappableBuildings.compactMap(\.knownStyle)).sorted()
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

    private var cityTrips: [Trip] { tripStore.trips(in: cityName) }

    // MARK: - Body

    var body: some View {
        map
        // Orange, not system blue, for Apple's own map controls (the 2D/3D toggle, the compass)
        .tint(.adventureOrange)
        .navigationTitle(mapTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear {
            guard !hasFramedCity else { return }
            hasFramedCity = true
            userLocation = currentLocationIfAllowed()
            fitCamera()
            // Opened from a trip's Tour button: give the city a moment to appear, then start
            if let tripID = tripToTour, let trip = tripStore.trip(withID: tripID) {
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    startTour(of: trip)
                }
            }
        }
        .onDisappear { stopTour() }
        .overlay(alignment: .bottom) {
            if let building = selectedBuilding {
                MapLandmarkCard(
                    building: building,
                    isVisited: progress.isVisited(building.id),
                    isWishlisted: progress.isWishlisted(building.id),
                    lookAroundScene: lookAroundScene,
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
                    onAddToTrip: {
                        stopTour()
                        addToTrip = AddToTripRequest(stop: .landmark(buildingID: building.id), name: building.name)
                    },
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
                    onAddToTrip: {
                        addToTrip = AddToTripRequest(stop: .place(placeID: place.id), name: place.name)
                    },
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
                legendButton
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding()
            }
        }
        .overlay(alignment: .top) {
            if filteredBuildings.isEmpty && category == .landmarks {
                Text("No landmarks match this filter")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 12)
            }
        }
        .overlay(alignment: .top) {
            if let banner = tripTourDayBanner {
                VStack(spacing: 2) {
                    Text(touringTrip?.name ?? "")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(banner)
                        .font(.title3.bold())
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityElement(children: .combine)
            }
        }
        // Category chips sit above the map, like Apple Maps; the compass moves down to make room
        .safeAreaInset(edge: .top, spacing: 0) {
            MapCategoryChips(selection: $category)
        }
        .animation(.spring(duration: 0.35), value: selectionKey)
        // Fetch street-level imagery for the selected landmark or place, if Apple has it
        .task(id: selectionKey) {
            lookAroundScene = nil
            guard let target = selectionCoordinate else { return }
            let request = MKLookAroundSceneRequest(coordinate: target)
            lookAroundScene = try? await request.scene
        }
        // Tapped an Apple Maps place: close any Stamped card and load the place's details
        #if os(iOS)
        .task(id: selectedFeature) {
            guard let feature = selectedFeature else { return }
            stopTour()
            selectedBuilding = nil
            selectedPlace = nil
            guard let mapItem = try? await MKMapItemRequest(feature: feature).mapItem else {
                selectedFeature = nil
                return
            }
            tappedApplePlace = TappedApplePlace(mapItem: mapItem)
        }
        #endif
        .sheet(item: $tappedApplePlace, onDismiss: { selectedFeature = nil }) { place in
            ApplePlaceSheet(mapItem: place.mapItem, cityName: cityName)
        }
        .sheet(isPresented: $showingAddPlace) {
            if let center = cityCenter {
                AddPlaceSheet(cityName: cityName, cityCenter: center)
            }
        }
        .fullScreenCover(isPresented: $showingLookAround) {
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
        .sheet(item: $addToTrip) { request in
            AddToTripSheet(cityName: cityName, stop: request.stop, stopName: request.name)
        }
        .inAppBrowser(item: $browserLink)
        .navigationDestination(item: $detailBuilding) { building in
            BuildingDetailView(building: building, viewModel: viewModel)
        }
    }

    // MARK: - Map

    private var map: some View {
        mapBase
        // Satellite photos draped over Apple's 3D city scans (the same data as Flyover).
        // Cities without 3D coverage fall back to flat satellite imagery automatically.
        // Each category chip decides which Apple Maps places are drawn (see MapCategory).
        .mapStyle(category.mapStyle(satellite: useSatellite))
        .mapControls {
            MapCompass()
            MapPitchToggle()
        }
    }

    @ViewBuilder
    private var mapBase: some View {
        #if os(macOS)
        // MapKit can't select Apple's own places on the Mac (MapFeature isn't Hashable there),
        // so only our own pins and saved places are tappable.
        Map(position: $position) { mapContent }
        #else
        // `selection` lets the user tap Apple's own places. Our landmark pins
        // handle their own taps, so they're unaffected.
        Map(position: $position, selection: $selectedFeature) { mapContent }
        #endif
    }

    @MapContentBuilder
    private var mapContent: some MapContent {
        if tripTourLine.count > 1 {
            MapPolyline(coordinates: tripTourLine)
                .stroke(Color.adventureOrange, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [8, 6]))
        }
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

    // MARK: - Toolbar

    /// "Michigan State" rather than "Michigan State University Map", so the title fits between the buttons.
    private var mapTitle: String {
        guard let city = CityLocation.City(rawValue: cityName), city.isCampus else { return cityName }
        return city.campusVisitShortName
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Swiping down pans the map instead of closing it, so every device gets a Done button
        if showsDoneButton {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    stopTour()
                    dismiss()
                }
            }
        }
        // Filters, Add a Place and the satellite switch share one menu, so the title has room
        ToolbarItem(placement: .topBarTrailing) {
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
                Section {
                    Button {
                        useSatellite.toggle()
                    } label: {
                        Label(useSatellite ? "Show Map View" : "Show Satellite View",
                              systemImage: useSatellite ? "map" : "globe.americas.fill")
                    }
                    Button {
                        stopTour()
                        showingAddPlace = true
                    } label: {
                        Label("Add a Place", systemImage: "plus")
                    }
                }
            } label: {
                Image(systemName: filter == .all && styleFilter == nil
                      ? "line.3.horizontal.decrease.circle"
                      : "line.3.horizontal.decrease.circle.fill")
            }
            .accessibilityLabel("Map options")
            .accessibilityHint("Filter landmarks, switch to satellite view or add a place")
        }
        ToolbarItem(placement: .topBarTrailing) {
            if isTouring {
                Button {
                    stopTour()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .labelStyle(.titleAndIcon)
                }
                .accessibilityHint("Stops the guided tour")
            } else if cityTrips.isEmpty {
                Button {
                    startTour()
                } label: {
                    Label("Tour", systemImage: "play.fill")
                        .labelStyle(.titleAndIcon)
                }
                .disabled(route.isEmpty)
                .accessibilityHint("Flies between every landmark automatically")
            } else {
                // With trips planned, Tour asks what to fly through
                Menu {
                    Button("All Landmarks", systemImage: "building.2") { startTour() }
                        .disabled(route.isEmpty)
                    Section("Your Trips") {
                        ForEach(cityTrips) { trip in
                            Button(trip.name, systemImage: "suitcase.rolling") { startTour(of: trip) }
                                .disabled(tourSteps(for: trip).isEmpty)
                        }
                    }
                } label: {
                    Label("Tour", systemImage: "play.fill")
                        .labelStyle(.titleAndIcon)
                }
                .accessibilityHint("Choose every landmark or one of your trips to tour")
            }
        }
    }

    // MARK: - Legend

    /// A small "?" in the corner; the legend opens on tap. It shows by itself the first time
    /// someone opens a map, then stays out of the way.
    private var legendButton: some View {
        Button {
            showingLegend.toggle()
        } label: {
            Image(systemName: "questionmark")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Color.primary)
                .frame(width: 36, height: 36)
                .background {
                    Circle().fill(reduceTransparency
                        ? AnyShapeStyle(Color(UIColor.secondarySystemBackground))
                        : AnyShapeStyle(.regularMaterial))
                }
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Map key")
        .popover(isPresented: $showingLegend) {
            legend
                .padding(6)
                .presentationCompactAdaptation(.popover)
        }
        .onAppear {
            if !hasSeenMapLegend {
                hasSeenMapLegend = true
                showingLegend = true
            }
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            LegendRow(color: .adventureOrange, label: "Stamped")
            LegendRow(color: .secondary, label: "Not yet visited")
            if upNext != nil {
                LegendRow(color: .adventureOrange, label: "Up next (pulsing)", isRing: true)
            }
            if !visibleCustomPlaces.isEmpty {
                LegendRow(color: DS.Palette.wishlist, label: "Your places")
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
    /// While touring a trip, it moves to the trip's previous/next stop instead
    /// and the tour carries on from there.
    private func step(by offset: Int) {
        if let trip = touringTrip, let currentIndex = tripTourStepIndex {
            let steps = tourSteps(for: trip)
            guard currentIndex < steps.count else { return }
            let nextIndex = (currentIndex + offset + steps.count) % steps.count
            startTour(of: trip, from: nextIndex, currentDay: steps[currentIndex].dayNumber)
            return
        }
        stopTour()
        let stops = route
        guard !stops.isEmpty else { return }
        let currentIndex = stops.firstIndex { $0.id == selectedBuilding?.id } ?? -1
        let nextIndex = (currentIndex + offset + stops.count) % stops.count
        flyTo(stops[nextIndex])
    }

    private func stopLabel(for building: Building) -> String? {
        // While touring a trip, the card shows the trip's numbering instead
        if let tripTourLabel { return tripTourLabel }
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
            // A cancelled tour was already cleaned up by stopTour(). Clearing tourTask
            // here too could wipe out a new tour that started in the meantime.
            if !Task.isCancelled {
                selectedBuilding = nil
                withAnimation(.easeInOut(duration: 3)) { fitCamera() }
                tourTask = nil
            }
        }
    }

    private func tourSteps(for trip: Trip) -> [TripTourStep] {
        TripTour.steps(for: trip, buildings: buildings, customPlaces: progress.customPlaces)
    }

    /// Flies through a trip day by day: first an overview of the day's route with a
    /// "Day N" banner, then each stop in order, pausing so its card can be read.
    /// `startIndex` and `currentDay` let ◀ ▶ restart the tour part-way through;
    /// the day overview only shows again when the new stop is on a different day.
    private func startTour(of trip: Trip, from startIndex: Int = 0, currentDay startDay: Int = 0) {
        let steps = tourSteps(for: trip)
        guard steps.indices.contains(startIndex) else { return }
        stopTour()
        // Show every pin, so no stop on the trip is hidden by a filter
        filter = .all
        styleFilter = nil
        touringTrip = trip
        tourTask = Task { @MainActor in
            var currentDay = startDay
            for (index, step) in steps.enumerated().dropFirst(startIndex) {
                if Task.isCancelled { break }
                if step.dayNumber != currentDay {
                    currentDay = step.dayNumber
                    let dayRoute = steps.filter { $0.dayNumber == currentDay }.map(\.coordinate)
                    showDayOverview(dayNumber: currentDay, route: dayRoute)
                    try? await Task.sleep(for: .seconds(3.5))
                    if Task.isCancelled { break }
                    withAnimation { tripTourDayBanner = nil }
                }
                tripTourStepIndex = index
                tripTourLabel = "Day \(step.dayNumber) · Stop \(step.stopNumber) of \(step.stopsInDay)"
                switch step.target {
                case .landmark(let building): flyTo(building, duration: 2.5)
                case .place(let place): flyTo(place, duration: 2.5)
                }
                try? await Task.sleep(for: .seconds(7))
            }
            if !Task.isCancelled {
                selectedBuilding = nil
                selectedPlace = nil
                endTripTour()
                withAnimation(.easeInOut(duration: 3)) { fitCamera() }
                tourTask = nil
            }
        }
    }

    /// Pulls the camera back to show a whole day's route, with its dashed line and banner.
    private func showDayOverview(dayNumber: Int, route dayRoute: [CLLocationCoordinate2D]) {
        tripTourStepIndex = nil
        selectedBuilding = nil
        selectedPlace = nil
        var banner = "Day \(dayNumber)"
        if let date = touringTrip?.date(ofDayAt: dayNumber - 1) {
            banner += " · \(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))"
        }
        withAnimation {
            tripTourLine = dayRoute
            tripTourDayBanner = banner
        }

        guard !dayRoute.isEmpty else { return }
        // Let MapKit fit the day's stops to the screen. Picking a camera distance by
        // hand cut the route off on narrow phone screens. The fit is seen from
        // above; each stop's swoop afterwards is tilted 3D again.
        let points = dayRoute.map(MKMapPoint.init)
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        var box = MKMapRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
        // Room around the stops for their names, the day banner and the chips.
        // At least 500 m, so a one-stop day shows its neighbourhood, not one rooftop.
        // (Map points aren't metres; MapKit converts for this latitude.)
        let minimumMargin = 500 * MKMapPointsPerMeterAtLatitude(dayRoute[0].latitude)
        let margin = max(max(box.width, box.height) * 0.35, minimumMargin)
        box = box.insetBy(dx: -margin, dy: -margin)
        withAnimation(.easeInOut(duration: 2.5)) {
            position = .rect(box)
        }
    }

    private func stopTour() {
        tourTask?.cancel()
        tourTask = nil
        endTripTour()
    }

    /// Clears the trip tour's banner, card numbering and route line.
    private func endTripTour() {
        touringTrip = nil
        tripTourLabel = nil
        tripTourStepIndex = nil
        withAnimation {
            tripTourDayBanner = nil
            tripTourLine = []
        }
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
    private func flyTo(_ place: CustomPlace, duration: Double = 1.5) {
        let aimPoint = CLLocationCoordinate2D(latitude: place.latitude - 0.0015, longitude: place.longitude)
        withAnimation(.easeInOut(duration: duration)) {
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

    // LocalizedStringKey so Label looks the titles up in Localizable.strings
    var title: LocalizedStringKey {
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
                    .foregroundStyle(.white, DS.Palette.wishlist)
                    .padding(3)
                    .background(DS.Palette.wishlist, in: Circle())
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
    /// Street-level imagery for this landmark, if Apple has it.
    let lookAroundScene: MKLookAroundScene?
    let stopLabel: String?
    let reduceTransparency: Bool
    let onStamp: () -> Void
    let onWishlist: () -> Void
    let onLookAround: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onViewDetails: () -> Void
    let onOpenTickets: (URL) -> Void
    let onAddToTrip: () -> Void
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
                    Text([building.knownStyle, building.hasKnownYear ? "Built \(String(building.yearBuilt))" : nil]
                            .compactMap { $0 }
                            .joined(separator: " · "))
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

            // Small street-level preview. Tapping it opens Look Around full screen.
            if let lookAroundScene {
                CardLookAroundPreview(scene: lookAroundScene)
                    .frame(height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture(perform: onLookAround)
                    // A fresh preview per landmark, so it doesn't keep the previous street
                    .id(building.id)
                    .accessibilityLabel("Look Around preview of \(building.name)")
                    .accessibilityAddTraits(.isButton)
            }

            // Quick actions
            HStack(spacing: 8) {
                QuickAction(title: isVisited ? "Stamped" : "Stamp",
                            systemImage: isVisited ? "checkmark.seal.fill" : "checkmark.seal",
                            isOn: isVisited, action: onStamp)
                QuickAction(title: isWishlisted ? "Saved" : "Want to Go",
                            systemImage: isWishlisted ? "heart.fill" : "heart",
                            isOn: isWishlisted, action: onWishlist)
                QuickAction(title: "Add to Trip", systemImage: "suitcase.rolling",
                            isOn: false, action: onAddToTrip)
                QuickAction(title: "Look Around", systemImage: "binoculars",
                            isOn: false, action: onLookAround)
                    .disabled(lookAroundScene == nil)
                    .opacity(lookAroundScene == nil ? 0.4 : 1)
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

// MARK: - Look Around preview

/// The card's small street-level picture. SwiftUI's LookAroundPreview shows
/// full-screen Look Around's close button, compass and street name on iPad,
/// because the iPad is a "regular width" screen. Wrapping Apple's view controller
/// lets us tell it the space is compact (like iPhone) so it stays a plain picture.
private struct CardLookAroundPreview: UIViewControllerRepresentable {
    let scene: MKLookAroundScene

    func makeUIViewController(context: Context) -> MKLookAroundViewController {
        let controller = MKLookAroundViewController(scene: scene)
        controller.badgePosition = .bottomTrailing
        // Taps open the full-screen Look Around instead of moving around in the small preview
        controller.isNavigationEnabled = false
        #if os(iOS)
        controller.traitOverrides.horizontalSizeClass = .compact
        #endif
        return controller
    }

    func updateUIViewController(_ controller: MKLookAroundViewController, context: Context) {
        controller.scene = scene
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
            .background(DS.Palette.wishlist, in: Circle())
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
    let onAddToTrip: () -> Void
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
                    .background(DS.Palette.wishlist, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name).font(.headline).lineLimit(2)
                    if let address = place.address {
                        Text(address).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Label("Your place", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(DS.Palette.wishlist)
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

            HStack(spacing: 8) {
                Button(action: onAddToTrip) {
                    Label("Add to Trip", systemImage: "suitcase.rolling")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "heart.slash")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Remove from Want to Visit")
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

// MARK: - Legend row

private struct LegendRow: View {
    let color: Color
    let label: LocalizedStringKey
    var isRing = false

    var body: some View {
        HStack(spacing: 6) {
            if isRing {
                Circle().stroke(color, lineWidth: 2).frame(width: 10, height: 10)
            } else {
                Circle().fill(color).frame(width: 10, height: 10)
            }
            Text(label)
                .font(.footnote)
                .foregroundStyle(.primary)
        }
    }
}
