//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI
import PhotosUI
import MapKit
import CoreLocation
 
struct BuildingDetailView: View {
    // MARK: - Properties
    let building: Building
    @ObservedObject var viewModel: CityDetailViewModel
    
    // MARK: - Environment & Settings
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorSchemeContrast) var contrast
    @Environment(\.dynamicTypeSize) var dynamicType
    
    @AppStorage("high_contrast_mode") var appHighContrast = false
    @AppStorage("haptics_enabled") var hapticsEnabled = true
    @AppStorage("use_metric_units") var useMetric = true

    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    
    // MARK: - State
    @State private var showCamera = false
    @State private var showingDeleteConfirmation = false
    @State private var isEditingPhoto = false
    @State private var showGeocodeError = false
    @State private var geocodeErrorMessage: String = ""
    @State private var showingReportMenu = false
    @State private var noteText: String = ""
    @State private var nearbyVenues: [(name: String, category: String)] = []
    @State private var isLoadingVenues = false
    @State private var lookAroundScene: MKLookAroundScene? = nil
    @State private var showingLookAround = false
 
    // Manipulation State (Zoom/Pan)
    @State private var photoScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var photoOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // MARK: - Computed States
    var isVisited: Bool { GlobalProgressManager.shared.isVisited(building.id) }
    var isHighContrast: Bool { contrast == .increased || appHighContrast }
    var shouldStack: Bool { dynamicType >= .accessibility1 }
    
    var formattedHeight: String {
        if useMetric {
            return "\(Int(building.height)) m"
        } else {
            let feet = Double(building.height) * 3.28084
            return "\(Int(feet)) ft"
        }
    }
    
    // MARK: - Main Body
    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneScrollView
            }
        }
        .background(Color(.systemBackground))
        .toolbarBackground(.hidden, for: .navigationBar)
        .ignoresSafeArea(edges: .top)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(buildingID: building.id)
        }
        .alert(L.Building.deletePhotoTitle, isPresented: $showingDeleteConfirmation) {
            Button(L.Building.deletePhotoConfirm, role: .destructive) {
                GlobalProgressManager.shared.deleteImage(for: building.id)
                resetManipulation()
                isEditingPhoto = false
            }
            Button(L.CityDetail.cancel, role: .cancel) { }
        } message: {
            Text(L.Building.deletePhotoMessage)
        }
        .sheet(isPresented: $showingLookAround) {
            if let scene = lookAroundScene {
                LookAroundSheet(scene: scene, buildingName: building.name)
            }
        }
        .task(id: building.id) {
            async let venues: () = fetchNearbyVenues()
            async let lookAround: () = fetchLookAroundScene()
            _ = await (venues, lookAround)
        }
    }

    private func fetchLookAroundScene() async {
        guard let lat = building.latitude, let lon = building.longitude else { return }
        let request = MKLookAroundSceneRequest(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)
        )
        lookAroundScene = try? await request.scene
    }

    private func fetchNearbyVenues() async {
        guard let lat = building.latitude, let lon = building.longitude else { return }
        isLoadingVenues = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "restaurant"
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            latitudinalMeters: 800,
            longitudinalMeters: 800
        )
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .restaurant, .cafe, .bakery, .brewery, .foodMarket, .nightlife
        ])
        if let response = try? await MKLocalSearch(request: request).start() {
            nearbyVenues = response.mapItems.prefix(6).compactMap { item in
                guard let name = item.name else { return nil }
                let cat: String
                switch item.pointOfInterestCategory {
                case .cafe:       cat = "Café"
                case .bakery:     cat = "Bakery"
                case .brewery:    cat = "Brewery"
                case .foodMarket: cat = "Market"
                case .nightlife:  cat = "Bar"
                default:          cat = "Restaurant"
                }
                return (name: name, category: cat)
            }
        }
        isLoadingVenues = false
    }
    
    private func resetManipulation() {
        photoScale = 1.0
        lastScale = 1.0
        photoOffset = .zero
        lastOffset = .zero
    }
}
 
// MARK: - UI Components Extension
extension BuildingDetailView {
    
    private var brandColor: Color { Color.adventureOrange }
    
    // MARK: - Hero Header
    func heroHeader(height: CGFloat) -> some View {
        ZStack(alignment: .bottomTrailing) {
            let userImage = GlobalProgressManager.shared.userImages[building.id]
            
            ZStack {
                if let uiImage = userImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .frame(height: height)
                        .scaleEffect(photoScale)
                        .offset(photoOffset)
                } else {
                    // WikiBuildingPhoto tries Wikipedia first, falls back to asset catalog
                    WikiBuildingPhoto(building: building, height: height)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: sizeClass == .regular ? 32 : 0))
            .background(Color(.systemBackground))
            .overlay(alignment: .bottom) {
                // Subtle fade into the white card below — blends the image edge cleanly
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.55),
                        .init(color: Color(UIColor.systemBackground).opacity(0.45), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)
                .allowsHitTesting(false)
            }
            .overlay(
                RoundedRectangle(cornerRadius: sizeClass == .regular ? 32 : 0)
                    .stroke(Color.primary, lineWidth: isHighContrast ? 3 : 0)
            )
            .gesture(userImage != nil && isEditingPhoto ?
                AnyGesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { photoScale = lastScale * $0 }
                            .onEnded { _ in lastScale = photoScale },
                        DragGesture()
                            .onChanged { photoOffset = CGSize(width: lastOffset.width + $0.translation.width, height: lastOffset.height + $0.translation.height) }
                            .onEnded { _ in lastOffset = photoOffset }
                    )
                ) : nil
            )
            
            photoControls
                .padding(.trailing, 20)
                .padding(.bottom, sizeClass == .regular ? 20 : 40)
                .shadow(color: .black.opacity(isHighContrast ? 0 : 0.2), radius: 10, x: 0, y: 5)
        }
    }
 
    // MARK: - iPad Layout
    private var iPadLayout: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            
            if isLandscape {
                HStack(spacing: 0) {
                    VStack {
                        heroHeader(height: 750)
                            .frame(width: geo.size.width * 0.50)
                        Spacer()
                    }
                    .padding(.leading, 40)
                    .padding(.vertical, 40)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        unifiedToolbar
                            .padding(.top, 10)
                            .padding(.bottom, 34)
                            .padding(.horizontal, 40)
                        
                        ScrollView(showsIndicators: false) {
                            iPadTextContent
                                .padding(.horizontal, 40)
                                .padding(.bottom, 60)
                        }
                    }
                    .padding(.top, 40)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        heroHeader(height: 400)
                            .padding(.horizontal, 40)
                            .padding(.top, 60)
 
                        unifiedToolbar
                            .padding(.horizontal, 40)
                        
                        Divider()
                            .padding(.horizontal, 40)
                            .opacity(isHighContrast ? 1 : 0.5)
                        
                        iPadTextContent
                            .padding(.horizontal, 40)
                            .padding(.bottom, 60)
                    }
                }
            }
        }
    }
    
    private var placeholderHero: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 60))
                .foregroundStyle(isHighContrast ? Color.primary.gradient : brandColor.gradient)
            
            Text(L.Building.capturePhoto)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(isHighContrast ? .primary : brandColor.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isHighContrast ? Color.clear : brandColor.opacity(0.05))
        .cornerRadius(sizeClass == .regular ? 32 : 0)
    }
 
    private var photoControls: some View {
        let userImage = GlobalProgressManager.shared.userImages[building.id]
        
        return HStack(spacing: 0) {
            if userImage != nil {
                Button {
                    withAnimation(.spring()) {
                        isEditingPhoto.toggle()
                    }
                    if hapticsEnabled { HapticManager.shared.trigger(.selection) }
                } label: {
                    Image(systemName: isEditingPhoto ? "lock.open.fill" : "lock.fill")
                        .frame(width: 44, height: 44)
                        .foregroundColor(isEditingPhoto ? brandColor : .primary)
                }
                .accessibilityLabel(isEditingPhoto ? "Lock photo" : "Unlock photo for editing")
                Divider().frame(height: 20)
            }

            PhotosPicker(selection: Binding(get: { nil }, set: { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        await MainActor.run {
                            GlobalProgressManager.shared.saveImage(img, for: building.id)
                            resetManipulation()
                            isEditingPhoto = true
                        }
                    }
                }
            }), matching: .images) {
                Image(systemName: "photo.fill").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Choose photo from library")

            Divider().frame(height: 20)

            Button { showCamera = true } label: {
                Image(systemName: "camera.fill").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Take photo with camera")

            if isEditingPhoto {
                if photoScale != 1.0 || photoOffset != .zero {
                    Divider().frame(height: 20)
                    Button {
                        withAnimation(.spring()) {
                            resetManipulation()
                        }
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .frame(width: 44, height: 44)
                            .foregroundColor(brandColor)
                    }
                    .accessibilityLabel("Reset photo position")
                }

                if userImage != nil {
                    Divider().frame(height: 20)
                    Button { showingDeleteConfirmation = true } label: {
                        Image(systemName: "trash.fill")
                            .frame(width: 44, height: 44)
                            .foregroundColor(.red)
                    }
                    .accessibilityLabel("Delete photo")
                }
            }
        }
        .foregroundColor(.primary)
        .background(reduceTransparency ? AnyShapeStyle(Color(UIColor.systemBackground)) : AnyShapeStyle(.ultraThinMaterial))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isEditingPhoto ? brandColor : Color.primary, lineWidth: isHighContrast ? 2 : (isEditingPhoto ? 1 : 0))
        )
    }
 
    // MARK: - iPhone Layout
    private var iPhoneScrollView: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroHeader(height: 380)
                VStack(alignment: .leading, spacing: 24) {
                    titleHeader
                    aboutSection
                    sectionHeader(L.Building.buildingInfo)
                    technicalGrid
                    if lookAroundScene != nil {
                        lookAroundButton
                    }
                    localFlavorsSection
                    reportIssueButton
                }
                .padding(20)
                .background(Color(.systemBackground))
                .cornerRadius(25)
                .offset(y: -25)
                .padding(.bottom, 60)
            }
        }
        .ignoresSafeArea(edges: .top)
        .safeAreaInset(edge: .bottom) {
            stickyBottomBar
        }
    }
    
    private var stickyBottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            bottomActionButton
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .background(reduceTransparency ? AnyShapeStyle(Color(UIColor.systemBackground)) : AnyShapeStyle(.ultraThinMaterial))
    }
    
    private var iPadTextContent: some View {
        VStack(alignment: .leading, spacing: 40) {
            titleHeader
            aboutSection
            sectionHeader(L.Building.technicalSpecs)
            technicalGrid
            if !building.foodSpots.isEmpty {
                foodSpotsSection(spots: building.foodSpots)
            }
            bottomActionButton
            reportIssueButton
        }
    }
 
    // MARK: - Global Components
    private var unifiedToolbar: some View {
        let spacing: CGFloat = sizeClass == .regular ? 20 : 12
        let layout = shouldStack ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing)) : AnyLayout(HStackLayout(alignment: .center, spacing: spacing))
        
        return layout {
            if sizeClass == .regular {
                Spacer()
                
                Button(action: handleActionTap) {
                    let color = isVisited ? Color.green : Color.adventureOrange
                    
                    HStack(spacing: 8) {
                        Image(systemName: isVisited ? "checkmark.seal.fill" : "checkmark.seal")
                            .fontWeight(.bold)
                        Text(isVisited ? L.Building.visited : L.Building.markVisited)
                    }
                    .font(.headline)
                    .foregroundColor(isHighContrast ? .primary : color)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isHighContrast ? Color.clear : color.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
                    )
                }
            }
        }
    }
 
    var titleHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(building.name)
                .font(.system(sizeClass == .regular ? .largeTitle : .title, design: .serif))
                .fontWeight(.bold)
            Text(L.Building.designedBy(building.architect))
                .font(.subheadline.italic())
                .foregroundColor(.secondary)
            if isVisited, let date = GlobalProgressManager.shared.visitDates[building.id] {
                Label("Stamped \(date.formatted(date: .abbreviated, time: .omitted))", systemImage: "checkmark.seal.fill")
                    .font(.caption.bold())
                    .foregroundColor(isHighContrast ? .primary : .adventureOrange)
                BuildingNoteField(buildingID: building.id, noteText: $noteText)
                    .padding(.top, 4)
            }
        }
        .onAppear {
            noteText = GlobalProgressManager.shared.buildingNotes[building.id] ?? ""
        }
    }
 
    var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(L.Building.historicalSignificance)
            Text(building.description).font(.body).lineSpacing(8)
            WikiDescriptionCard(building: building)
        }
    }
 
    var technicalGrid: some View {
        VStack(spacing: 12) {
            specCard(label: L.Building.location, value: building.address, icon: "mappin.and.ellipse")
            specCard(label: L.Building.built, value: "\(building.yearBuilt)", icon: "calendar")
            specCard(label: L.Building.height, value: formattedHeight, icon: "arrow.up.and.down")
            specCard(label: L.Building.stories, value: "\(building.numberOfStories)", icon: "building.2")
        }
    }
 
    @ViewBuilder
    var localFlavorsSection: some View {
        // Only show the section if the building has coordinates (so we can search)
        // or if there are legacy hardcoded spots to fall back on.
        if isLoadingVenues {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.7)
                Text("Finding nearby spots…")
                    .font(.caption).foregroundColor(.secondary)
            }
        } else if !nearbyVenues.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(L.Building.localFlavors)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(nearbyVenues, id: \.name) { venue in
                            localFlavorCard(name: venue.name, category: venue.category)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                Text("Dining data from Apple Maps. Stamped is not responsible for venue quality.")
                    .font(.caption2).foregroundColor(.secondary)
            }
        } else if building.latitude == nil, !building.foodSpots.isEmpty {
            // No coordinates — fall back to hardcoded spots
            foodSpotsSection(spots: building.foodSpots)
        }
    }

    private func localFlavorCard(name: String, category: String) -> some View {
        let mapsURL: URL? = {
            let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let lat = building.latitude, let lon = building.longitude {
                return URL(string: "maps://?q=\(encoded)&near=\(lat),\(lon)")
            }
            return URL(string: "maps://?q=\(encoded)")
        }()

        let card = VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(isHighContrast ? Color.primary.opacity(0.1) : brandColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "fork.knife")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isHighContrast ? .primary : brandColor)
            }

            Text(name)
                .font(.subheadline).fontWeight(.bold)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.primary)

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Text(category)
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(width: 160)
        .frame(minHeight: 160)
        .background(isHighContrast ? Color.clear : Color.primary.opacity(0.05))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary, lineWidth: isHighContrast ? 2 : 0)
        )

        return Group {
            if let url = mapsURL {
                Link(destination: url) { card }
                    .simultaneousGesture(TapGesture().onEnded {
                        HapticManager.shared.trigger(.selection)
                    })
                    .accessibilityLabel("\(name), \(category)")
                    .accessibilityHint("Opens in Apple Maps")
            } else {
                card
            }
        }
    }

    func foodSpotsSection(spots: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(L.Building.localFlavors)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(spots, id: \.self) { spot in
                        foodSpotCard(spot: spot)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
 
    private func foodSpotCard(spot: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(isHighContrast ? Color.primary.opacity(0.1) : brandColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "fork.knife")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isHighContrast ? .primary : brandColor)
            }
            
            Text(spot)
                .font(.subheadline)
                .fontWeight(.bold)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true) // Prevents truncation
                .multilineTextAlignment(.leading)
                .foregroundColor(.primary)
            
            Spacer(minLength: 4)
            
            Text(L.Building.nearby)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .padding(16)
        .frame(width: 160)
        .frame(minHeight: 160)
        .background(isHighContrast ? Color.clear : Color.primary.opacity(0.05))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary, lineWidth: isHighContrast ? 2 : 0)
        )
    }
 
    var bottomActionButton: some View {
        let activeColor = isVisited ? Color.green : brandColor
        
        return Button(action: handleActionTap) {
            Label(isVisited ? L.Building.visited : L.Building.markVisited, systemImage: isVisited ? "checkmark.seal.fill" : "checkmark.seal")
                .fontWeight(.bold)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .foregroundColor(isHighContrast ? .primary : activeColor)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isHighContrast ? Color.clear : activeColor.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
                )
        }
        .accessibilityHint(isVisited ? "Tap to remove stamp from this building" : "Marks this building as visited and stamps your passport")
    }
    
    func sectionHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.title3, design: .serif))
                .fontWeight(.bold)
            
            Rectangle()
                .fill(isHighContrast ? Color.primary : brandColor.opacity(0.3))
                .frame(width: 40, height: 4)
                .cornerRadius(2)
        }
    }
 
    func specCard(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(isHighContrast ? .primary : brandColor)
                .font(.system(size: 18, weight: isHighContrast ? .bold : .regular))
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                if label == L.Building.location {
                    // Make address tappable: open in Maps when tapped
                    Button(action: {
                        Task { await openInMaps(address: value) }
                    }) {
                        HStack(spacing: 6) {
                            Text(value)
                                .font(.callout.monospaced())
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .alert(L.Building.mapErrorTitle, isPresented: $showGeocodeError, actions: {
                        Button(L.Building.mapOK, role: .cancel) { showGeocodeError = false }
                    }, message: {
                        Text(geocodeErrorMessage)
                    })
                 } else {
                     Text(value)
                         .font(.callout.monospaced())
                         .fontWeight(.bold)
                 }
              }
             Spacer()
         }
         .padding()
         .background(isHighContrast ? Color.clear : Color.primary.opacity(0.05))
         .cornerRadius(12)
         .overlay(
             RoundedRectangle(cornerRadius: 12)
                 .stroke(Color.primary, lineWidth: isHighContrast ? 2 : 0)
         )
     }
 
    // Open the provided address in Apple Maps. Prefer coordinate-based pin if geocoding succeeds.
    private func openInMaps(address: String) async {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
 
        // Try to geocode via our GeocodingManager
        // debug log start
        print("openInMaps: attempting geocode for: \(trimmed)")
        // If building already has coordinates, use them immediately
        if let lat = building.latitude, let lon = building.longitude {
            print("openInMaps: using building coordinates \(lat),\(lon)")
            let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = building.name
            let launchOptions: [String: Any] = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
             await MainActor.run {
                 _ = mapItem.openInMaps(launchOptions: launchOptions)
             }
             return
         }
 
         if let coord = await GeocodingManager.shared.coordinate(for: trimmed) {
              print("openInMaps: geocoded to \(coord.latitude),\(coord.longitude)")
              let placemark = MKPlacemark(coordinate: coord)
              let mapItem = MKMapItem(placemark: placemark)
              mapItem.name = building.name
              let launchOptions: [String: Any] = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
              await MainActor.run {
                  // openInMaps returns a Bool; explicitly ignore it to avoid unused-result warnings
                  _ = mapItem.openInMaps(launchOptions: launchOptions)
              }
              return
          } else {
             // geocoding failed — fallback to search URL and show an alert to the user explaining it
             let urlStr = "http://maps.apple.com/?q=\(trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
             print("openInMaps: geocode failed, falling back to URL search: \(urlStr)")
             await MainActor.run {
                 if let url = URL(string: urlStr) {
                     UIApplication.shared.open(url)
                 }
                 geocodeErrorMessage = L.Building.mapErrorMessage
                 showGeocodeError = true
             }
         }
     }
    
    func handleActionTap() {
        withAnimation(.spring()) { viewModel.toggleVisited(for: building) }
        if hapticsEnabled { HapticManager.shared.trigger(isVisited ? .success : .warning) }
        // Seed noteText if this is the first stamp
        if noteText.isEmpty {
            noteText = GlobalProgressManager.shared.buildingNotes[building.id] ?? ""
        }
    }

    // MARK: - Look Around button
    var lookAroundButton: some View {
        Button {
            HapticManager.shared.trigger(.selection)
            showingLookAround = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "binoculars.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(isHighContrast ? Color.primary : Color.adventureOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Look Around")
                        .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                    Text("Street-level view near this building")
                        .font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Look Around — street-level view near \(building.name)")
        .accessibilityHint("Opens Apple Maps Look Around viewer")
    }

    // MARK: - Report Issue
    var reportIssueButton: some View {

        // Replace georgeclinkscalesdev@proton.me with your support email before shipping
        let email = "georgeclinkscalesdev@proton.me"
        let subject = "Content Issue: \(building.name)"
        let body = "Building: \(building.name)\nCity: \(viewModel.city.name)\n\nWhat's wrong:\n"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        return Group {
            if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "flag")
                            .font(.caption)
                        Text("Report an issue with this building")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                }
                .accessibilityLabel("Report an issue with \(building.name)")
                .accessibilityHint("Opens your email app")
            }
        }
    }
}

// MARK: - Building Note Field

private struct BuildingNoteField: View {
    let buildingID: String
    @Binding var noteText: String
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("My Note", systemImage: "note.text")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            TextField("Add a personal memory…", text: $noteText, axis: .vertical)
                .font(.caption)
                .lineLimit(3, reservesSpace: false)
                .focused($isFocused)
                .padding(10)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isFocused ? Color.adventureOrange : Color.primary.opacity(0.15), lineWidth: 1)
                )
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        GlobalProgressManager.shared.saveNote(noteText, for: buildingID)
                    }
                }
        }
    }
}

// MARK: - Look Around sheet + viewer

private struct LookAroundSheet: View {
    let scene: MKLookAroundScene
    let buildingName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // GeometryReader reads the real safe area top so Done lines up with
        // Apple's own Look Around badge, which sits at safeAreaInsets.top + ~12pt.
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                LookAroundViewer(scene: scene)
                    .ignoresSafeArea()

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                }
                .padding(.top, geo.safeAreaInsets.top + 12)
                .padding(.trailing, 16)
            }
        }
        .ignoresSafeArea()
    }
}

private struct LookAroundViewer: UIViewControllerRepresentable {
    var scene: MKLookAroundScene

    func makeUIViewController(context: Context) -> MKLookAroundViewController {
        let vc = MKLookAroundViewController(scene: scene)
        vc.showsRoadLabels = true
        return vc
    }

    func updateUIViewController(_ vc: MKLookAroundViewController, context: Context) {
        vc.scene = scene
    }
}
