//
//  CityMapVisionView.swift
//  Tally-AVP
//
//  Photoreal 3D map of one city with a pin for every landmark — the same Apple
//  3D city data as the iPhone app's map. Tap a pin to fly to it and see its story.
//  Turn on Places to see Apple Maps' restaurants, cafés and museums; tap one
//  for Apple's place card.
//

import SwiftUI
import MapKit

struct CityMapVisionView: View {

    let cityName: String

    private let store = VisionStore.shared
    @State private var position: MapCameraPosition = .automatic
    /// The landmark shown in the landmark window (LandmarkWindowView)
    private let selection = LandmarkSelection.shared
    private var selectedBuilding: Building? { selection.building }
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var showingQuiz = false
    @State private var showingWishlist = false
    /// Show Apple Maps' own places (restaurants, cafés, museums…) on the map.
    @State private var showsPlaces = false
    /// The Apple Maps place the user tapped; MapKit shows its place card.
    @State private var selectedFeature: MapFeature?
    /// The guided tour: flies to each landmark in turn and reads its story aloud
    @State private var tourTask: Task<Void, Never>?
    @ObservedObject private var storyPlayer = AudioStoryPlayer.shared
    /// Explore Together: shares the open landmark with friends on FaceTime
    private let sharePlay = SharePlayExplorer.shared
    /// Reduce Motion: the camera jumps instead of swooping, and the card fades in
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Then vs. Now: an old map of the city (OpenHistoricalMap) faded over today's
    @State private var showsOldMap = false
    @State private var oldMapYear = HistoricMap.defaultYear
    @State private var oldMapOpacity = 0.75
    /// Where the camera is, so switching maps keeps the view
    @State private var currentCamera: MapCamera?
    /// Camera moves for the old map, which isn't driven by `position`
    @State private var oldMapCameraRequest: HistoricMapView.CameraRequest?
    /// Old Library of Congress photos floated over their landmarks on the old map
    @State private var oldPhotos: [String: URL] = [:]

    private var mappableBuildings: [Building] {
        store.buildings(for: cityName).filter { $0.latitude != nil && $0.longitude != nil }
    }

    /// Only cities run through tools/city-generator have a 3D model. It's
    /// either in the app bundle or downloaded as an asset pack (CityModelStore).
    private let models = CityModelStore.shared
    private var hasCityModel: Bool {
        switch models.state(for: cityName) {
        case .checking, .unavailable: false
        default: true
        }
    }

    var body: some View {
        Group {
            if showsOldMap, let currentCamera {
                oldMap(startingAt: currentCamera)
            } else {
                liveMap
            }
        }
        .ornament(visibility: showsOldMap ? .visible : .hidden, attachmentAnchor: .scene(.top)) {
            HistoricMapControls(year: $oldMapYear, opacity: $oldMapOpacity,
                                showsPhotoCredit: !oldPhotos.isEmpty)
        }
        .task(id: showsOldMap) { if showsOldMap { await loadOldPhotos() } }
        .navigationTitle(cityName)
        // Is the 3D model on this device, downloadable, or missing?
        .task(id: cityName) { await models.refresh(cityName) }
        .toolbar {
            // The map's main controls float in an ornament under the window,
            // where visionOS puts a window's everyday controls.
            ToolbarItemGroup(placement: .bottomOrnament) {
                // The narrated tour: every landmark in a short walking order, each story read aloud
                Button {
                    if tourTask == nil { startTour() } else { stopTour() }
                } label: {
                    if tourTask == nil {
                        // With the old map on, the tour is a time walk: each stop in its own year
                        if showsOldMap {
                            Label("Time Walk", systemImage: "figure.walk.motion")
                        } else {
                            Label("Play Tour", systemImage: "play.fill")
                        }
                    } else {
                        Label("Stop Tour", systemImage: "stop.fill")
                    }
                }
                .help("Fly to each landmark and hear its story")
                .disabled(mappableBuildings.isEmpty)

                Toggle(isOn: $showsPlaces) {
                    Label("Places", systemImage: "mappin.and.ellipse")
                }
                .help("Show restaurants, cafés, museums and more from Apple Maps")
                .disabled(showsOldMap)

                // Then vs. Now: fade an old map of the city over today's
                Toggle(isOn: $showsOldMap) {
                    Label("Then & Now", systemImage: "clock.arrow.circlepath")
                }
                .help("Fade an old map of the city over today's")
                .disabled(currentCamera == nil)

                Button {
                    showingWishlist = true
                } label: {
                    Label("Want to Visit", systemImage: "heart")
                }

                Button {
                    showingQuiz = true
                } label: {
                    Label("Quiz", systemImage: "questionmark.bubble")
                }
                .disabled(mappableBuildings.count < 4)

                // Explore this city together with friends on FaceTime
                SharePlayButton(cityName: cityName)
            }
            if hasCityModel {
                ToolbarItem {
                    // Open 3D Model, or Download … in 3D with progress and Cancel
                    CityModelButton(cityName: cityName)
                }
            }
        }
        .onAppear {
            fitCamera()
            // Closing the landmark window ends the tour and the story, here and for friends
            selection.onClose = {
                stopTour()
                storyPlayer.stop()
                sharePlay.landmarkOpened(nil, in: cityName)
            }
            // Joining a friend's session switches city; open what they're looking at
            showFriendsLandmark(sharePlay.remoteLandmark)
        }
        .onChange(of: sharePlay.remoteLandmark) { _, remote in
            showFriendsLandmark(remote)
        }
        // Leaving the city ends the tour and the story
        .onDisappear {
            stopTour()
            storyPlayer.stop()
            closeLandmarkWindow()
        }
        // Turning Places off also closes any open place card
        .onChange(of: showsPlaces) { _, isOn in
            if !isOn { selectedFeature = nil }
        }
        // Back to today's map where the old map left off
        .onChange(of: showsOldMap) { _, isOn in
            if !isOn, let currentCamera { position = .camera(currentCamera) }
        }
        .sheet(isPresented: $showingQuiz) {
            VisionQuizView(cityName: cityName, buildings: store.buildings(for: cityName))
        }
        .sheet(isPresented: $showingWishlist) {
            WantToVisitList(
                cityName: cityName,
                onSelectBuilding: { building in
                    showingWishlist = false
                    if let lat = building.latitude, let lon = building.longitude {
                        flyTo(building, at: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                    }
                },
                onSelectPlace: { place in
                    showingWishlist = false
                    flyTo(place.coordinate)
                }
            )
        }
    }

    /// The same city with an old map on top, and the landmark pins
    private func oldMap(startingAt camera: MapCamera) -> some View {
        let landmarkPins = mappableBuildings.map { building in
            let visited = store.visitedIDs.contains(building.id)
            return HistoricMapView.Pin(
                id: building.id, title: building.name,
                coordinate: CLLocationCoordinate2D(latitude: building.latitude!, longitude: building.longitude!),
                systemImage: visited ? "checkmark" : "building.columns",
                color: visited ? .orange : .gray,
                photoURL: oldPhotos[building.id])
        }
        let placePins = store.customPlaces(in: cityName).map { place in
            HistoricMapView.Pin(id: "place:\(place.id)", title: place.name, coordinate: place.coordinate,
                                systemImage: CustomPlace.icon(forCategory: place.category), color: .systemPink)
        }
        return HistoricMapView(
            year: oldMapYear,
            opacity: oldMapOpacity,
            pins: landmarkPins + placePins,
            initialCamera: camera,
            cameraRequest: oldMapCameraRequest,
            onSelectPin: { id in
                if let building = mappableBuildings.first(where: { $0.id == id }) {
                    flyTo(building, at: CLLocationCoordinate2D(latitude: building.latitude!, longitude: building.longitude!))
                } else if let place = store.customPlaces(in: cityName).first(where: { "place:\($0.id)" == id }) {
                    flyTo(place.coordinate)
                }
            },
            onCameraChange: { currentCamera = $0 }
        )
    }

    /// One old photo per US landmark (the Library of Congress surveys only cover the US),
    /// fetched one at a time so loc.gov isn't flooded.
    private func loadOldPhotos() async {
        for building in mappableBuildings where oldPhotos[building.id] == nil {
            guard !Task.isCancelled else { return }
            guard LibraryOfCongressService.cityAndState(from: building.address) != nil else { continue }
            let images = await LibraryOfCongressService.shared.images(
                buildingID: building.id, name: building.name,
                address: building.address, cityName: cityName)
            if let photo = images.first(where: { !$0.isDrawing }) {
                oldPhotos[building.id] = photo.thumbnailURL
            }
        }
    }

    private var liveMap: some View {
        // `selection` lets the user tap Apple's own places. Our landmark pins
        // handle their own taps, so they're unaffected.
        Map(position: $position, selection: $selectedFeature) {
            ForEach(mappableBuildings) { building in
                let coordinate = CLLocationCoordinate2D(latitude: building.latitude!, longitude: building.longitude!)
                Annotation(building.name, coordinate: coordinate, anchor: .bottom) {
                    LandmarkPin(isVisited: store.visitedIDs.contains(building.id),
                                isWishlisted: store.isWishlisted(building.id),
                                isSelected: selectedBuilding?.id == building.id)
                        .onTapGesture { flyTo(building, at: coordinate) }
                        .hoverEffect()
                        .accessibilityLabel(building.name)
                        .accessibilityAddTraits(.isButton)
                        // The tap is a gesture, so give VoiceOver's double-tap the same action
                        .accessibilityAction { flyTo(building, at: coordinate) }
                }
            }
            // Places saved from Apple Maps search on iPhone
            ForEach(store.customPlaces(in: cityName)) { place in
                Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) {
                    Image(systemName: CustomPlace.icon(forCategory: place.category))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.pink, in: Circle())
                        .shadow(radius: 4)
                        .onTapGesture { flyTo(place.coordinate) }
                        .hoverEffect()
                        .accessibilityLabel("\(place.name), your saved place")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { flyTo(place.coordinate) }
                }
            }
        }
        // Satellite photos draped over Apple's 3D city scans. Cities without
        // 3D coverage fall back to flat satellite imagery automatically.
        // Places on: .hybrid adds Apple's labels and place icons on top of the same photos.
        .mapStyle(showsPlaces ? .hybrid(elevation: .realistic) : .imagery(elevation: .realistic))
        // Apple's place card pops up next to a tapped place
        .mapFeatureSelectionAccessory(.callout)
        .mapControls {
            MapCompass()
            MapPitchToggle()
        }
        .onMapCameraChange(frequency: .onEnd) { context in currentCamera = context.camera }
    }

    /// Camera swoop for a saved place (no card, since it isn't a built-in landmark).
    private func flyTo(_ coordinate: CLLocationCoordinate2D) {
        closeLandmarkWindow()
        selectedFeature = nil
        moveCamera(to: MapCamera(centerCoordinate: coordinate, distance: 700, heading: 0, pitch: 65))
    }

    // MARK: - Camera

    /// Swoops whichever map is showing to `camera`
    private func moveCamera(to camera: MapCamera) {
        if showsOldMap {
            oldMapCameraRequest = .init(camera: camera, animated: !reduceMotion)
        } else {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.5)) {
                position = .camera(camera)
            }
        }
    }

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

    // MARK: - Guided tour

    /// Flies to each landmark in walking order, shows its card and reads its story; the next
    /// stop starts when the story ends. Stop Tour, closing the card or leaving ends it.
    private func startTour() {
        let stops = Self.tourOrder(mappableBuildings)
        tourTask = Task {
            for building in stops {
                guard !Task.isCancelled, let lat = building.latitude, let lon = building.longitude else { break }
                // Time walk: the old map turns to the year the landmark was built
                if showsOldMap, building.hasKnownYear {
                    oldMapYear = HistoricMap.clampedYear(building.yearBuilt)
                }
                flyTo(building, at: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                // Let the camera arrive before the story starts
                try? await Task.sleep(for: .seconds(1.8))
                guard !Task.isCancelled else { break }
                await storyPlayer.playAndWait(building)
                guard !Task.isCancelled else { break }
                try? await Task.sleep(for: .seconds(1))
            }
            tourTask = nil
        }
    }

    private func stopTour() {
        tourTask?.cancel()
        tourTask = nil
        storyPlayer.stop()
    }

    /// A short walking order: start at the landmark nearest the middle of the city, then always
    /// go to the nearest landmark not yet visited.
    static func tourOrder(_ buildings: [Building]) -> [Building] {
        var remaining = buildings.filter { $0.latitude != nil && $0.longitude != nil }
        guard !remaining.isEmpty else { return [] }
        func distance(_ a: Building, _ lat: Double, _ lon: Double) -> Double {
            let dx = (a.longitude! - lon) * cos(lat * .pi / 180)
            let dy = a.latitude! - lat
            return dx * dx + dy * dy
        }
        let midLat = remaining.map { $0.latitude! }.reduce(0, +) / Double(remaining.count)
        let midLon = remaining.map { $0.longitude! }.reduce(0, +) / Double(remaining.count)
        var current = remaining.min { distance($0, midLat, midLon) < distance($1, midLat, midLon) }!
        var order = [current]
        remaining.removeAll { $0.id == current.id }
        while !remaining.isEmpty {
            let next = remaining.min { distance($0, current.latitude!, current.longitude!) < distance($1, current.latitude!, current.longitude!) }!
            order.append(next)
            remaining.removeAll { $0.id == next.id }
            current = next
        }
        return order
    }

    /// Swoops the camera down to a landmark and shows its card. In SharePlay it also
    /// opens the landmark for everyone, unless the tap came from a friend already.
    private func flyTo(_ building: Building, at coordinate: CLLocationCoordinate2D,
                       shareWithGroup: Bool = true) {
        selectedFeature = nil
        moveCamera(to: MapCamera(centerCoordinate: coordinate, distance: 700, heading: 0, pitch: 65))
        selection.show(building, in: cityName)
        openWindow(id: LandmarkWindowView.windowID)
        if shareWithGroup {
            sharePlay.landmarkOpened(building.id, in: cityName)
        }
    }

    // MARK: - SharePlay

    /// A friend in SharePlay opened (or closed) a landmark: do the same here.
    private func showFriendsLandmark(_ remote: SharePlayExplorer.RemoteLandmark?) {
        guard let message = remote?.message, message.cityName == cityName else { return }
        // A friend took the lead, so this device's own tour stops
        if tourTask != nil { stopTour() }
        if let landmarkID = message.landmarkID {
            guard let building = mappableBuildings.first(where: { $0.id == landmarkID }),
                  let latitude = building.latitude, let longitude = building.longitude else { return }
            flyTo(building, at: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                  shareWithGroup: false)
        } else {
            storyPlayer.stop()
            closeLandmarkWindow()
        }
    }

    /// Closes the landmark window without the close-button side effects (see `onClose`)
    private func closeLandmarkWindow() {
        selection.building = nil
        dismissWindow(id: LandmarkWindowView.windowID)
    }
}

// MARK: - Pin

private struct LandmarkPin: View {
    let isVisited: Bool
    var isWishlisted = false
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
        .overlay(alignment: .topTrailing) {
            if isWishlisted {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(Color.pink, in: Circle())
                    .offset(x: 6, y: -6)
            }
        }
        // One element; the map gives it the landmark's name as its label
        .accessibilityElement(children: .ignore)
        .accessibilityValue(accessibilityStatus)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// What the pin's colour and heart show, in words
    private var accessibilityStatus: Text {
        switch (isVisited, isWishlisted) {
        case (true, true): Text("Stamped, Want to Visit")
        case (true, false): Text("Stamped")
        case (false, true): Text("Want to Visit")
        case (false, false): Text(verbatim: "")
        }
    }
}

// MARK: - Landmark card

struct LandmarkCard: View {
    let building: Building
    let cityName: String
    let isVisited: Bool
    let isWishlisted: Bool
    var isPlaying = false
    let onWishlist: () -> Void
    var onListen: () -> Void = {}
    let onClose: () -> Void

    /// Apple's street-level imagery at the landmark, or nil where Apple has none
    @State private var lookAroundScene: MKLookAroundScene?
    @State private var showingAsk = false
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(building.name).font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle = building.styleAndYear {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if isVisited {
                        Label("Stamped", systemImage: "checkmark.seal.fill")
                            .font(.callout.bold())
                            .foregroundStyle(.orange)
                    }
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonBorderShape(.circle)
                .accessibilityLabel("Close")
            }

            // Full labels on one line when they fit; icons only when they don't
            // (longer languages), instead of wrapping each button onto two lines.
            ViewThatFits(in: .horizontal) {
                actionButtons
                    .labelStyle(.titleAndIcon)
                    .fixedSize()
                actionButtons
                    .labelStyle(.iconOnly)
            }

            Text(building.description)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !building.architect.isEmpty {
                VisionArchitectLink(building: building)
            }

            // Stand on the street in front of it: drag to look around, tap to open it big.
            // Only shown where Apple has driven its cameras.
            if lookAroundScene != nil {
                LookAroundPreview(initialScene: lookAroundScene)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel(Text("Look Around"))
            }

            // Built, opened, listed, and what the papers said at the time
            HistoryTimelineSection(building: building, cityName: cityName)

            // Hotels and tours, kept apart from the buttons above
            Divider()
            PartnerLinksRow(building: building, cityName: cityName)
        }
        .padding(24)
        .task(id: building.id) { await fetchLookAroundScene() }
        .sheet(isPresented: $showingAsk) {
            AskBuildingView(building: building, cityName: cityName)
        }
    }

    private var actionButtons: some View {
        HStack {
            // Hear the story read aloud while looking at the building in 3D
            Button(action: onListen) {
                let title: LocalizedStringKey = isPlaying ? "Stop" : "Listen"
                Label(title, systemImage: isPlaying ? "stop.fill" : "speaker.wave.2.fill")
            }
            .tint(.orange)
            PanoramaButton(building: building)
            // Ask the building a question; it answers from Stamped's facts
            Button { showingAsk = true } label: {
                Label("Ask", systemImage: "bubble.left.and.text.bubble.right")
            }
            // Old film or photos all around you, with the story read aloud
            Button {
                Task { await openImmersiveSpace(id: PastImmersiveView.spaceID, value: building.id) }
            } label: {
                Label("Step into the Past", systemImage: "film")
            }
            Button(action: onWishlist) {
                // Typed as LocalizedStringKey so both titles get translated
                let title: LocalizedStringKey = isWishlisted ? "Saved" : "Want to Go"
                Label(title, systemImage: isWishlisted ? "heart.fill" : "heart")
            }
            .tint(.pink)
        }
    }

    private func fetchLookAroundScene() async {
        lookAroundScene = nil
        guard let latitude = building.latitude, let longitude = building.longitude else { return }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        // Asking with Apple Maps' own place for the landmark makes Look Around face
        // the building. Asking with just the pin gives the nearest street spot,
        // which can face a wall or a café instead.
        if let place = await appleMapsPlace(near: coordinate) {
            lookAroundScene = try? await MKLookAroundSceneRequest(mapItem: place).scene
        }
        if lookAroundScene == nil {
            lookAroundScene = try? await MKLookAroundSceneRequest(coordinate: coordinate).scene
        }
    }

    /// Apple Maps' place for this landmark: a search for its name around the pin,
    /// keeping the closest result within 300 m so we never jump to a namesake elsewhere.
    private func appleMapsPlace(near coordinate: CLLocationCoordinate2D) async -> MKMapItem? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = building.name
        request.region = MKCoordinateRegion(center: coordinate,
                                            latitudinalMeters: 1000,
                                            longitudinalMeters: 1000)
        guard let response = try? await MKLocalSearch(request: request).start() else { return nil }

        let pin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let nearest = response.mapItems.min { first, second in
            first.placemark.location?.distance(from: pin) ?? .infinity
                < second.placemark.location?.distance(from: pin) ?? .infinity
        }
        guard let nearest, let location = nearest.placemark.location,
              location.distance(from: pin) <= 300 else { return nil }
        return nearest
    }
}

// MARK: - Hotel and tour links

/// Where to stay and which tours to book near a landmark, from the same partner links as
/// the iPhone app. Two menus keep the card short; each choice opens the partner's site in
/// Safari. Stamped never books or takes payment.
private struct PartnerLinksRow: View {
    let building: Building
    let cityName: String

    /// Labels clicks from Vision Pro in the partners' reports, apart from the iPhone app's
    private static let clickLabel = "vision"

    private let expedia = HotelLinkBuilder(clickLabel: Self.clickLabel)
    private let booking = HotelLinkBuilder(provider: .booking,
                                           affiliateID: HotelPartner.bookingAffiliateID,
                                           clickLabel: Self.clickLabel)
    private let vrbo = VrboLinkBuilder(clickLabel: Self.clickLabel)
    private let getYourGuide = TourLinkBuilder(campaign: Self.clickLabel)
    private let viator = ViatorLinkBuilder(campaign: Self.clickLabel)

    @Environment(\.openURL) private var openURL

    /// "Colosseum, Rome", centred on the landmark's pin so the site searches around it
    private var hotelSearch: HotelSearch {
        let destination = building.name.localizedCaseInsensitiveContains(cityName)
            ? building.name
            : "\(building.name), \(cityName)"
        return HotelSearch(destination: destination, latitude: building.latitude, longitude: building.longitude)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                staysMenu
                toursMenu
            }
            // Only when the links carry our partner IDs
            if expedia.earnsCommission || getYourGuide.earnsCommission {
                HotelCommissionNote()
            }
        }
    }

    private var staysMenu: some View {
        Menu {
            if let url = expedia.url(for: hotelSearch) {
                linkButton("Find Hotels", systemImage: "bed.double.fill", url: url,
                           hint: "Opens the hotel website. Stamped! doesn't handle bookings or payments.")
            }
            // Like the iPhone's Booking.com button: only with our ID, never an untracked link
            if booking.earnsCommission, let url = booking.url(for: hotelSearch) {
                linkButton("Compare on Booking.com", systemImage: "magnifyingglass", url: url,
                           hint: "Opens Booking.com. Stamped! doesn't handle bookings or payments.")
            }
            if let url = vrbo.url(for: hotelSearch) {
                linkButton("Vacation Rentals on Vrbo", systemImage: "house.fill", url: url,
                           hint: "Opens Vrbo. Stamped! doesn't handle bookings or payments.")
            }
        } label: {
            Label("Stay", systemImage: "bed.double.fill")
        }
    }

    private var toursMenu: some View {
        Menu {
            if let url = getYourGuide.url(landmark: building.name, place: cityName) {
                linkButton("Find Tours & Tickets", systemImage: "ticket.fill", url: url,
                           hint: "Opens GetYourGuide. Stamped! doesn't handle bookings or payments.")
            }
            if let url = viator.url(landmark: building.name, place: cityName) {
                linkButton("More tours on Viator", systemImage: "arrow.up.right.square", url: url,
                           hint: "Opens Viator. Stamped! doesn't handle bookings or payments.")
            }
        } label: {
            Label("Tours & Tickets", systemImage: "ticket.fill")
        }
    }

    /// One menu choice that opens a partner's site in Safari.
    private func linkButton(_ title: LocalizedStringKey, systemImage: String, url: URL,
                            hint: LocalizedStringKey) -> some View {
        Button {
            openURL(url)
        } label: {
            Label(title, systemImage: systemImage)
        }
        .accessibilityHint(Text(hint))
    }
}

// MARK: - Want to Visit list

/// Landmarks and saved places the user wants to visit in this city (shared with iPhone).
private struct WantToVisitList: View {
    let cityName: String
    let onSelectBuilding: (Building) -> Void
    let onSelectPlace: (CustomPlace) -> Void

    @Environment(\.dismiss) private var dismiss
    private let store = VisionStore.shared

    var body: some View {
        NavigationStack {
            List {
                let landmarks = store.wishlistBuildings(in: cityName)
                let places = store.customPlaces(in: cityName)
                if landmarks.isEmpty && places.isEmpty {
                    ContentUnavailableView(
                        "Nothing Saved Yet",
                        systemImage: "heart",
                        description: Text("Tap Want to Go on a landmark, or add places in Stamped on your iPhone.")
                    )
                }
                if !landmarks.isEmpty {
                    Section("Landmarks") {
                        ForEach(landmarks) { building in
                            Button { onSelectBuilding(building) } label: {
                                Label(building.name, systemImage: "building.columns.fill")
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { store.toggleWishlist(landmarks[index].id) }
                        }
                    }
                }
                if !places.isEmpty {
                    Section("Your Places") {
                        ForEach(places) { place in
                            Button { onSelectPlace(place) } label: {
                                VStack(alignment: .leading) {
                                    Label(place.name, systemImage: CustomPlace.icon(forCategory: place.category))
                                    if let address = place.address {
                                        Text(address).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { store.removeCustomPlace(places[index].id) }
                        }
                    }
                }
            }
            .navigationTitle("Want to Visit · \(cityName)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 520, minHeight: 500)
    }
}
