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
import CloudKit
 
struct BuildingDetailView: View {
    // MARK: - Properties
    let building: Building
    @ObservedObject var viewModel: CityDetailViewModel
    // Watched so the wishlist heart updates when tapped
    @ObservedObject private var progressManager = GlobalProgressManager.shared

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
    @State private var showingModelViewer = false
    @State private var existingScanRecord: CKRecord? = nil
    @State private var localModelURL: URL? = nil
    @State private var isCheckingScan = false
    #if os(iOS)
    @State private var showingScan = false
    @State private var showingScanNudge = false
    #endif
 
    // Manipulation State (Zoom/Pan)
    @State private var photoScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var photoOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    // Food cards and their icon grow with the text size so names don't clip
    @ScaledMetric(relativeTo: .subheadline) var flavorCardWidth: CGFloat = 160
    @ScaledMetric(relativeTo: .subheadline) var flavorIconSize: CGFloat = 40
    @ScaledMetric(relativeTo: .largeTitle) var placeholderIconSize: CGFloat = 60
    
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
        .background(DS.Palette.pageBackground)
        .toolbarBackground(.hidden, for: .navigationBar)
        #if os(iOS)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(buildingID: building.id)
        }
        #elseif os(macOS)
        // A Mac has no camera picker: the same button imports an image file instead.
        .fileImporter(isPresented: $showCamera, allowedContentTypes: [.image]) { result in
            guard let url = try? result.get() else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            if let img = UIImage(contentsOf: url) {
                GlobalProgressManager.shared.saveImage(img, for: building.id)
                resetManipulation()
                isEditingPhoto = true
            }
        }
        #endif
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
        #if os(iOS)
        .sheet(isPresented: $showingScan) {
            ScanBuildingView(building: building, cityName: viewModel.city.name)
        }
        .sheet(isPresented: $showingScanNudge) {
            ScanNudgeSheet(building: building, cityName: viewModel.city.name) {
                showingScanNudge = false
                showingScan = true
            }
        }
        #endif
        .sheet(isPresented: $showingModelViewer) {
            if let url = localModelURL {
                BuildingModelViewer(modelURL: url, buildingName: building.name)
            }
        }
        .task(id: building.id) {
            async let venues: () = fetchNearbyVenues()
            async let lookAround: () = fetchLookAroundScene()
            async let scan: () = checkForExistingScan()
            _ = await (venues, lookAround, scan)
        }
    }

    private func checkForExistingScan() async {
        isCheckingScan = true
        existingScanRecord = await BuildingScanService.shared.fetchLatestScan(buildingID: building.id)
        isCheckingScan = false
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
    
    private var brandColor: Color { DS.Palette.accent }
    /// Keeps the iPad portrait column at a readable line length
    private var readableWidth: CGFloat { 720 }
    
    // MARK: - Hero Header
    func heroHeader(height: CGFloat) -> some View {
        let userImage = GlobalProgressManager.shared.userImages[building.id]

        return ZStack(alignment: .bottomTrailing) {
            // The size comes from this clear frame; the photo is laid over it, so a wide
            // photo can't push the page wider than the screen (same as the city hero)
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .overlay {
                    if let uiImage = userImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(photoScale)
                            .offset(photoOffset)
                    } else {
                        // WikiBuildingPhoto tries Wikipedia first, falls back to asset catalog
                        WikiBuildingPhoto(building: building, height: height)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous)
                        .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
                )
                .contentShape(Rectangle())
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
            
            // Floating over the photo, so this one keeps its shadow
            photoControls
                .padding(DS.Space.m)
                .shadow(color: .black.opacity(isHighContrast ? 0 : 0.2), radius: 10, x: 0, y: 5)
        }
    }
 
    // MARK: - iPad Layout
    private var iPadLayout: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            
            if isLandscape {
                HStack(alignment: .top, spacing: DS.Space.section) {
                    heroHeader(height: max(0, geo.size.height - DS.Space.l * 2))
                        .frame(width: geo.size.width * 0.50)
                        .padding(.vertical, DS.Space.l)
                    
                    ScrollView(showsIndicators: false) {
                        detailContent
                            .padding(.vertical, DS.Space.l)
                            .padding(.bottom, DS.Space.section)
                    }
                }
                .dsPageMargin()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Space.xl) {
                        heroHeader(height: 400)
                        detailContent
                    }
                    .frame(maxWidth: readableWidth)
                    .dsPageMargin()
                    .padding(.top, DS.Space.l)
                    .padding(.bottom, DS.Space.section)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    private var placeholderHero: some View {
        VStack(spacing: DS.Space.m) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: placeholderIconSize))
                .foregroundStyle(isHighContrast ? Color.primary.gradient : brandColor.gradient)
            
            Text(L.Building.capturePhoto)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(isHighContrast ? .primary : brandColor.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isHighContrast ? Color.clear : brandColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous))
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

            #if os(iOS)
            Button { showCamera = true } label: {
                Image(systemName: "camera.fill").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Take photo with camera")
            #elseif os(macOS)
            Button { showCamera = true } label: {
                Image(systemName: "folder.fill").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Choose image file")
            #endif

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
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                heroHeader(height: 340)
                detailContent
            }
            .dsPageMargin()
            .padding(.top, DS.Space.s)
            .padding(.bottom, DS.Space.section)
            .containerRelativeFrame([.horizontal])
        }
    }
    
    /// Everything under the photo, shared by iPhone and iPad: name and facts, the
    /// stamp button, then the reading sections.
    private var detailContent: some View {
        VStack(alignment: .leading, spacing: DS.Space.section) {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                titleHeader
                factChips
                actionButtons
            }
            if isVisited {
                BuildingNoteField(buildingID: building.id, noteText: $noteText, isHighContrast: isHighContrast)
            }
            aboutSection
            infoSection
            threeDModelSection
            localFlavorsSection
            reportIssueButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
 
    // MARK: - Global Components
    var titleHeader: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text(building.name)
                .font(.system(sizeClass == .regular ? .largeTitle : .title, design: .serif))
                .fontWeight(.bold)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let architect = building.knownArchitect {
                Text(L.Building.designedBy(architect))
                    .font(.subheadline.italic())
                    .foregroundColor(isHighContrast ? .primary : .secondary)
            }
            if isVisited, let date = GlobalProgressManager.shared.visitDates[building.id] {
                Label("Stamped \(date.formatted(date: .abbreviated, time: .omitted))", systemImage: "checkmark.seal.fill")
                    .font(.caption.bold())
                    .foregroundColor(isHighContrast ? .primary : brandColor)
            }
        }
        .onAppear {
            noteText = GlobalProgressManager.shared.buildingNotes[building.id] ?? ""
        }
    }

    /// Year, style, height and stories as a wrapping row of chips. Each is left out when
    /// the registry doesn't know it.
    @ViewBuilder
    var factChips: some View {
        let tint: Color = isHighContrast ? .primary : .secondary
        let hasFacts = building.hasKnownYear || building.knownStyle != nil || building.height > 0 || building.numberOfStories > 0
        if hasFacts {
            ChipFlowLayout(spacing: DS.Space.s) {
                if building.hasKnownYear {
                    DSChip(text: "\(L.Building.built) \(building.yearBuilt)", systemImage: "calendar", tint: tint)
                }
                if let style = building.knownStyle {
                    DSChip(text: style, systemImage: "building.columns", tint: tint)
                }
                if building.height > 0 {
                    DSChip(text: "\(L.Building.height) \(formattedHeight)", systemImage: "arrow.up.and.down", tint: tint)
                }
                if building.numberOfStories > 0 {
                    DSChip(text: "\(L.Building.stories) \(building.numberOfStories)", systemImage: "building.2", tint: tint)
                }
            }
        }
    }

    /// The Stamp button on its own line, then Want to Visit and Look Around side by side
    /// (stacked at accessibility text sizes).
    var actionButtons: some View {
        let layout = shouldStack
            ? AnyLayout(VStackLayout(spacing: DS.Space.m))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DS.Space.m))

        return VStack(spacing: DS.Space.m) {
            bottomActionButton
            layout {
                wishlistButton
                if lookAroundScene != nil {
                    lookAroundButton
                }
            }
        }
    }
 
    var aboutSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader("building.historicalSignificance", systemImage: "book.closed", isHighContrast: isHighContrast)
            Text(building.description)
                .font(.body)
                .lineSpacing(DS.Space.xs)
                .fixedSize(horizontal: false, vertical: true)
            WikiDescriptionCard(building: building, isHighContrast: isHighContrast)
        }
    }

    /// The address (taps through to Maps); the other specs are the chips under the name.
    var infoSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader(sizeClass == .regular ? LocalizedStringKey("building.technicalSpecs") : LocalizedStringKey("building.buildingInfo"),
                            systemImage: "info.circle", isHighContrast: isHighContrast)
            specCard(label: L.Building.location, value: building.address, icon: "mappin.and.ellipse")
        }
    }
 
    @ViewBuilder
    var localFlavorsSection: some View {
        // Only show the section if the building has coordinates (so we can search)
        // or if there are legacy hardcoded spots to fall back on.
        if isLoadingVenues {
            HStack(spacing: DS.Space.s) {
                ProgressView().scaleEffect(0.7)
                Text("Finding nearby spots…")
                    .font(.caption).foregroundColor(.secondary)
            }
        } else if !nearbyVenues.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                DSSectionHeader("building.localFlavors", systemImage: "fork.knife", isHighContrast: isHighContrast)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: DS.Space.m) {
                        ForEach(nearbyVenues, id: \.name) { venue in
                            localFlavorCard(name: venue.name, category: venue.category)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                Text("Dining data from Apple Maps. Stamped is not responsible for venue quality.")
                    .font(.caption2).foregroundColor(isHighContrast ? .primary : .secondary)
            }
        } else if building.latitude == nil, !building.foodSpots.isEmpty {
            // No coordinates — fall back to hardcoded spots
            foodSpotsSection(spots: building.foodSpots)
        }
    }

    /// The round fork-and-knife badge at the top of each food card.
    private var flavorIcon: some View {
        ZStack {
            Circle()
                .fill(isHighContrast ? Color.primary.opacity(0.1) : brandColor.opacity(0.15))
                .frame(width: flavorIconSize, height: flavorIconSize)
            Image(systemName: "fork.knife")
                .font(.subheadline.bold())
                .foregroundColor(isHighContrast ? .primary : brandColor)
        }
    }

    /// Food cards: the grouped card surface, a fixed width that grows with the text size.
    private func flavorCardStyle<Content: View>(_ content: Content) -> some View {
        content
            .padding(DS.Space.l)
            .frame(width: flavorCardWidth, alignment: .leading)
            .frame(minHeight: flavorCardWidth, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(isHighContrast ? Color.clear : DS.Palette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(Color.primary, lineWidth: isHighContrast ? 2 : 0)
            )
    }

    private func localFlavorCard(name: String, category: String) -> some View {
        let mapsURL: URL? = {
            let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let lat = building.latitude, let lon = building.longitude {
                return URL(string: "maps://?q=\(encoded)&near=\(lat),\(lon)")
            }
            return URL(string: "maps://?q=\(encoded)")
        }()

        let card = flavorCardStyle(VStack(alignment: .leading, spacing: DS.Space.s) {
            flavorIcon

            Text(name)
                .font(.subheadline).fontWeight(.bold)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.primary)

            Spacer(minLength: DS.Space.xs)

            HStack(spacing: DS.Space.xs) {
                Text(category)
                    .font(.caption2.monospaced()).fontWeight(.semibold)
                    .foregroundColor(isHighContrast ? .primary : .secondary)
                    .textCase(.uppercase)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundColor(isHighContrast ? .primary : .secondary)
            }
        })

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
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader("building.localFlavors", systemImage: "fork.knife", isHighContrast: isHighContrast)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: DS.Space.m) {
                    ForEach(spots, id: \.self) { spot in
                        foodSpotCard(spot: spot)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
 
    private func foodSpotCard(spot: String) -> some View {
        flavorCardStyle(VStack(alignment: .leading, spacing: DS.Space.s) {
            flavorIcon
            
            Text(spot)
                .font(.subheadline)
                .fontWeight(.bold)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true) // Prevents truncation
                .multilineTextAlignment(.leading)
                .foregroundColor(.primary)
            
            Spacer(minLength: DS.Space.xs)
            
            Text(L.Building.nearby)
                .font(.caption2.monospaced())
                .fontWeight(.semibold)
                .foregroundColor(isHighContrast ? .primary : .secondary)
                .textCase(.uppercase)
        })
    }

    /// Fill and outline shared by the secondary buttons under Stamp.
    private func secondaryButtonStyle<Content: View>(_ content: Content, tint: Color) -> some View {
        content
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .multilineTextAlignment(.center)
            .foregroundColor(isHighContrast ? .primary : tint)
            .padding(.vertical, DS.Space.m)
            .padding(.horizontal, DS.Space.s)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(isHighContrast ? Color.clear : tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
            )
    }
 
    /// Saves the landmark to the user's "Want to Visit" list for a future trip.
    var wishlistButton: some View {
        let isSaved = progressManager.isWishlisted(building.id)
        return Button {
            withAnimation(.spring()) { progressManager.toggleWishlist(building.id) }
            if hapticsEnabled { HapticManager.shared.trigger(.selection) }
        } label: {
            secondaryButtonStyle(
                Label {
                    Text(isSaved ? LocalizedStringKey("Saved") : LocalizedStringKey("Want to Visit"))
                } icon: {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .contentTransition(.symbolEffect(.replace))
                },
                tint: DS.Palette.wishlist
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSaved ? "Remove from Want to Visit" : "Add to Want to Visit")
    }

    /// The page's one primary action: filled orange until stamped, then a green "Visited" state.
    var bottomActionButton: some View {
        let fill: Color = isVisited ? Color.green.opacity(0.15) : brandColor
        let textColor: Color = isVisited ? .green : .white
        
        return Button(action: handleActionTap) {
            Label(isVisited ? L.Building.visited : L.Building.markVisited, systemImage: isVisited ? "checkmark.seal.fill" : "checkmark.seal")
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.vertical, DS.Space.l)
                .padding(.horizontal, DS.Space.m)
                .frame(maxWidth: .infinity)
                .foregroundColor(isHighContrast ? .primary : textColor)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .fill(isHighContrast ? Color.clear : fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .accessibilityHint(isVisited ? "Tap to remove stamp from this building" : "Marks this building as visited and stamps your passport")
    }
 
    func specCard(label: String, value: String, icon: String) -> some View {
        HStack(spacing: DS.Space.l) {
            Image(systemName: icon)
                .foregroundColor(isHighContrast ? .primary : brandColor)
                .font(.body.weight(isHighContrast ? .bold : .regular))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.monospaced().bold())
                    .textCase(.uppercase)
                    .foregroundColor(isHighContrast ? .primary : .secondary)
                if label == L.Building.location {
                    Button(action: {
                        Task { await openInMaps(address: value) }
                    }) {
                        Text(value)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
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
                        .font(.callout)
                        .fontWeight(.semibold)
                }
            }
            Spacer(minLength: 0)
            if label == L.Building.location {
                Image(systemName: "arrow.up.right.square")
                    .font(.body)
                    .foregroundColor(isHighContrast ? .primary : .secondary)
            }
        }
        .dsCard(isHighContrast: isHighContrast)
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
        let wasUnvisited = !isVisited
        withAnimation(.spring()) { viewModel.toggleVisited(for: building) }
        if hapticsEnabled { HapticManager.shared.trigger(isVisited ? .success : .warning) }
        if noteText.isEmpty {
            noteText = GlobalProgressManager.shared.buildingNotes[building.id] ?? ""
        }
        #if os(iOS)
        // Show scan nudge after the stamp animation plays, but only when:
        // - user just stamped (wasn't visited before)
        // - no community scan exists yet
        if wasUnvisited && existingScanRecord == nil && !isCheckingScan {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                showingScanNudge = true
            }
        }
        #endif
    }

    // MARK: - 3D Model Section

    /// One tappable row in the 3D Model card: icon, title, subtitle and a chevron.
    private func modelRow(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        HStack(spacing: DS.Space.m) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isHighContrast ? Color.primary : brandColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2).foregroundStyle(isHighContrast ? Color.primary : Color.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption).foregroundStyle(isHighContrast ? Color.primary : Color.secondary)
        }
        .dsCard(isHighContrast: isHighContrast)
        .contentShape(Rectangle())
    }

    var threeDModelSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader("3D Model", systemImage: "rotate.3d", isHighContrast: isHighContrast)

            if isCheckingScan {
                HStack(spacing: DS.Space.s) {
                    ProgressView().scaleEffect(0.8)
                    Text("Checking for 3D model…")
                        .font(.caption).foregroundStyle(.secondary)
                }

            } else if let record = existingScanRecord {
                // A scan exists — show View button
                Button {
                    HapticManager.shared.trigger(.selection)
                    Task {
                        localModelURL = try? await BuildingScanService.shared.localModelURL(for: record)
                        if localModelURL != nil { showingModelViewer = true }
                    }
                } label: {
                    modelRow(icon: "rotate.3d", title: "View in 3D", subtitle: "Community scan available")
                }
                .buttonStyle(.plain)

                #if os(iOS)
                Button {
                    HapticManager.shared.trigger(.selection)
                    showingScan = true
                } label: {
                    Label("Contribute a better scan", systemImage: "camera.viewfinder")
                        .font(.caption)
                        .foregroundStyle(isHighContrast ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                #endif

            } else {
                #if os(iOS)
                // No scan yet — invite them to be first
                Button {
                    HapticManager.shared.trigger(.selection)
                    showingScan = true
                } label: {
                    modelRow(icon: "camera.viewfinder", title: "Scan This Building", subtitle: "Be the first to add a 3D model")
                }
                .buttonStyle(.plain)
                #endif
            }
        }
    }

    // MARK: - Look Around button
    var lookAroundButton: some View {
        Button {
            HapticManager.shared.trigger(.selection)
            showingLookAround = true
        } label: {
            secondaryButtonStyle(
                Label("Look Around", systemImage: "binoculars.fill"),
                tint: brandColor
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
                    HStack(spacing: DS.Space.xs) {
                        Image(systemName: "flag")
                            .font(.caption)
                        Text("Report an issue with this building")
                            .font(.caption)
                    }
                    .foregroundColor(isHighContrast ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, DS.Space.s)
                }
                .accessibilityLabel("Report an issue with \(building.name)")
                .accessibilityHint("Opens your email app")
            }
        }
    }
}

// MARK: - Fact chip layout

/// Lays chips out left to right and wraps to a new line when the next one doesn't fit.
/// A chip wider than the whole row is offered the row's width, so it truncates instead
/// of pushing the page wider.
private struct ChipFlowLayout: Layout {
    var spacing: CGFloat = DS.Space.s

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, maxWidth: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(subviews, maxWidth: bounds.width)
        for (index, subview) in subviews.enumerated() {
            let frame = result.frames[index]
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrange(_ subviews: Subviews, maxWidth: CGFloat) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            var size = subview.sizeThatFits(.unspecified)
            if size.width > maxWidth {
                size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            }
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (frames, CGSize(width: widest, height: y + rowHeight))
    }
}

// MARK: - Building Note Field

private struct BuildingNoteField: View {
    let buildingID: String
    @Binding var noteText: String
    var isHighContrast = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader("My Note", systemImage: "note.text", isHighContrast: isHighContrast)

            TextField("Add a personal memory…", text: $noteText, axis: .vertical)
                .font(.subheadline)
                .lineLimit(3, reservesSpace: false)
                .focused($isFocused)
                .padding(DS.Space.m)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                        .fill(isHighContrast ? Color.clear : DS.Palette.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                        .stroke(isFocused ? (isHighContrast ? Color.primary : DS.Palette.accent)
                                          : Color.primary.opacity(isHighContrast ? 1 : 0.15),
                                lineWidth: isHighContrast ? 2 : 1)
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
                        .padding(.horizontal, DS.Space.l)
                        .padding(.vertical, DS.Space.s)
                        .background(.regularMaterial, in: Capsule())
                }
                .padding(.top, geo.safeAreaInsets.top + DS.Space.m)
                .padding(.trailing, DS.Space.l)
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
