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

    @Environment(\.openWindow) private var openWindow
    private let store = VisionStore.shared
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedBuilding: Building?
    @State private var showingQuiz = false
    @State private var showingWishlist = false
    /// Show Apple Maps' own places (restaurants, cafés, museums…) on the map.
    @State private var showsPlaces = false
    /// The Apple Maps place the user tapped; MapKit shows its place card.
    @State private var selectedFeature: MapFeature?
    /// The guided tour: flies to each landmark in turn and reads its story aloud
    @State private var tourTask: Task<Void, Never>?
    @ObservedObject private var storyPlayer = AudioStoryPlayer.shared

    private var mappableBuildings: [Building] {
        store.buildings(for: cityName).filter { $0.latitude != nil && $0.longitude != nil }
    }

    /// Only cities run through tools/city-generator have a bundled 3D model.
    private var hasCityModel: Bool {
        Bundle.main.url(forResource: cityName.lowercased(), withExtension: "usdz") != nil
    }

    var body: some View {
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
        .navigationTitle(cityName)
        .toolbar {
            ToolbarItem {
                // The narrated tour: every landmark in a short walking order, each story read aloud
                Button {
                    if tourTask == nil { startTour() } else { stopTour() }
                } label: {
                    if tourTask == nil {
                        Label("Play Tour", systemImage: "play.fill")
                    } else {
                        Label("Stop Tour", systemImage: "stop.fill")
                    }
                }
                .help("Fly to each landmark and hear its story")
                .disabled(mappableBuildings.isEmpty)
            }
            ToolbarItem {
                Toggle(isOn: $showsPlaces) {
                    Label("Places", systemImage: "mappin.and.ellipse")
                }
                .help("Show restaurants, cafés, museums and more from Apple Maps")
            }
            ToolbarItem {
                Button {
                    showingWishlist = true
                } label: {
                    Label("Want to Visit", systemImage: "heart")
                }
            }
            ToolbarItem {
                Button {
                    showingQuiz = true
                } label: {
                    Label("Quiz", systemImage: "questionmark.bubble")
                }
                .disabled(mappableBuildings.count < 4)
            }
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
                             cityName: cityName,
                             isVisited: store.visitedIDs.contains(building.id),
                             isWishlisted: store.isWishlisted(building.id),
                             isPlaying: storyPlayer.isPlaying(building),
                             onWishlist: { store.toggleWishlist(building.id) },
                             onListen: { storyPlayer.toggle(building) }) {
                    stopTour()
                    storyPlayer.stop()
                    selectedBuilding = nil
                }
                .padding(24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: selectedBuilding?.id)
        .onAppear { fitCamera() }
        // Leaving the city ends the tour and the story
        .onDisappear {
            stopTour()
            storyPlayer.stop()
        }
        // Turning Places off also closes any open place card
        .onChange(of: showsPlaces) { _, isOn in
            if !isOn { selectedFeature = nil }
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

    /// Camera swoop for a saved place (no card, since it isn't a built-in landmark).
    private func flyTo(_ coordinate: CLLocationCoordinate2D) {
        selectedBuilding = nil
        selectedFeature = nil
        withAnimation(.easeInOut(duration: 1.5)) {
            position = .camera(MapCamera(centerCoordinate: coordinate, distance: 700, heading: 0, pitch: 65))
        }
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

    // MARK: - Guided tour

    /// Flies to each landmark in walking order, shows its card and reads its story; the next
    /// stop starts when the story ends. Stop Tour, closing the card or leaving ends it.
    private func startTour() {
        let stops = Self.tourOrder(mappableBuildings)
        tourTask = Task {
            for building in stops {
                guard !Task.isCancelled, let lat = building.latitude, let lon = building.longitude else { break }
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

    /// Swoops the camera down to a landmark and shows its card.
    private func flyTo(_ building: Building, at coordinate: CLLocationCoordinate2D) {
        selectedFeature = nil
        withAnimation(.easeInOut(duration: 1.5)) {
            position = .camera(MapCamera(centerCoordinate: coordinate, distance: 700, heading: 0, pitch: 65))
        }
        selectedBuilding = building
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
    }
}

// MARK: - Landmark card

private struct LandmarkCard: View {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(building.name).font(.title2.bold())
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

            // Stand on the street in front of it: drag to look around, tap to open it big.
            // Only shown where Apple has driven its cameras.
            if lookAroundScene != nil {
                LookAroundPreview(initialScene: lookAroundScene)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel(Text("Look Around"))
            }

            // Hotels and tours, kept apart from the buttons above
            Divider()
            PartnerLinksRow(building: building, cityName: cityName)
        }
        .padding(24)
        .frame(width: 480)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 28))
        .task(id: building.id) { await fetchLookAroundScene() }
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
