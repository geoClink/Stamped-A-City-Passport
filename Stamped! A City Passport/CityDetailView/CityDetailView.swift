//
//  CityDetailView.swift
//  Stamped
//
//  Created by George Clinkscales on 2/1/26.
//

import SwiftUI

struct CityDetailView: View {
    // MARK: - State & Settings
    @StateObject var viewModel: CityDetailViewModel
    @ObservedObject var soundManager = SoundManager.shared
    
    @Environment(\.colorSchemeContrast) var systemContrast
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.isWideWindow) private var isWideWindow
    
    @AppStorage("high_contrast_mode") var appHighContrast = false
    @AppStorage("reduce_motion") var reduceMotion = false
    @AppStorage var highScore: Int
    
    @State private var showingQuiz = false
    @State private var showingFinalConfirmation = false
    @State private var showingCelebration = false
    @State private var showingMap = false
    @State private var showingExplore = false
    @State private var showingTripPlanner = false
    /// The trip the planner opens on, set by "Plan a Campus Visit". nil opens the trip list.
    @State private var tripPlannerTripID: String?
    @State private var resetType: CityDetailViewModel.ResetType = .none
    /// Which part of the city page shows under the tiles; kept between cities
    @AppStorage("city_page_tab") private var selectedTab: CityPageTab = .landmarks

    /// The city page in three parts, so it isn't one very long scroll
    enum CityPageTab: String, CaseIterable, Identifiable {
        case landmarks, plan, local
        var id: String { rawValue }
        var title: String {
            switch self {
            case .landmarks: return NSLocalizedString("Landmarks", comment: "City page tab: the landmark list")
            case .plan: return NSLocalizedString("Plan", comment: "City page tab: itinerary, events, hotels and travel info")
            case .local: return NSLocalizedString("Local", comment: "City page tab: weather and nearby dining")
            }
        }
    }
    
    var isHighContrast: Bool { systemContrast == .increased || appHighContrast }
    var brandColor: Color { isHighContrast ? .primary : Color.adventureOrange }
    
    init(city: CityLocation.City) {
        _viewModel = StateObject(wrappedValue: CityDetailViewModel(city: city))
        self._highScore = AppStorage(wrappedValue: 0, "high_score_\(city.name)")
    }
    
    private var cityMap: some View {
        NavigationStack {
            CityMapView(
                buildings: viewModel.city.buildings,
                cityName: viewModel.city.name,
                viewModel: viewModel
            )
        }
    }

    /// One `showingMap` flag drives two presentations; each only "sees" it on its own size class.
    private func mapPresented(fullScreen: Bool) -> Binding<Bool> {
        Binding(
            get: { showingMap && isWideWindow == fullScreen },
            set: { showingMap = $0 }
        )
    }

    /// Same iPhone-sheet / iPad-full-screen split as the map.
    private func tripPlannerPresented(fullScreen: Bool) -> Binding<Bool> {
        Binding(
            get: { showingTripPlanner && isWideWindow == fullScreen },
            set: { showingTripPlanner = $0 }
        )
    }

    var body: some View {
        ScrollView {
            // Sections are separated by space, not divider lines (DS.Space.section)
            VStack(spacing: DS.Space.section) {
                CityHeroHeader(
                    city: viewModel.city,
                    progress: viewModel.progress,
                    isHighContrast: isHighContrast,
                    masteryTier: viewModel.getMastery(isHighContrast: isHighContrast).tier
                )
                
                CityActionTiles(tiles: actionTiles, isHighContrast: isHighContrast)
                    .dsPageMargin()
                
                if viewModel.isCompleted {
                    PassportStampView(
                        cityName: viewModel.city.name,
                        dateCompleted: viewModel.completionDate,
                        funFact: viewModel.city.details.funFact,
                        isHighContrast: isHighContrast
                    )
                    .padding(.horizontal)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                }
                
                Picker(NSLocalizedString("Section", comment: "City page: picker between Landmarks, Plan and Local"), selection: $selectedTab) {
                    ForEach(CityPageTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .dsPageMargin()
                .onChange(of: selectedTab) { _, _ in HapticManager.shared.trigger(.selection) }

                switch selectedTab {
                case .landmarks:
                    // Campuses only: the traditions scavenger hunt
                    if !viewModel.city.traditions.isEmpty {
                        CampusTraditionsSection(campus: viewModel.city, isHighContrast: isHighContrast)
                    }

                    LandmarkSection(viewModel: viewModel, isHighContrast: isHighContrast)

                    BuildingTimelineSection(
                        buildings: viewModel.city.buildings,
                        visitedIDs: GlobalProgressManager.shared.visitedIDs,
                        isHighContrast: isHighContrast
                    )

                case .plan:
                    CityItineraryView(city: viewModel.city)

                    // Events — hidden when there are none
                    let events = TicketmasterService.shared
                    if events.isLoading || !events.events.isEmpty {
                        EventsSection(service: events, isHighContrast: isHighContrast)
                    }

                    // Campuses only: the school's own calendar (hides itself when there's nothing)
                    if viewModel.city.campusEventFeed != nil {
                        CampusEventsSection(service: CampusEventsService.shared, campus: viewModel.city, isHighContrast: isHighContrast)
                    }

                    TravelInfoSection(viewModel: viewModel, isHighContrast: isHighContrast)

                case .local:
                    // Weather — hidden when failed/empty so we don't advertise broken state
                    let weather = WeatherManager.shared
                    if weather.isLoading || !weather.temperature.isEmpty || weather.showsSetupError {
                        WeatherSection(weather: weather, isHighContrast: isHighContrast)
                    }

                    // Top Eats — hidden when failed so we don't show "Couldn't load"
                    let eats = FoursquareService.shared
                    if eats.isLoading || !eats.venues.isEmpty {
                        TopEatsSection(service: eats, isHighContrast: isHighContrast)
                    }
                }
            }
            .padding(.top, DS.Space.s)
            .padding(.bottom, DS.Space.section)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .background(isHighContrast ? Color(UIColor.systemBackground) : Color(UIColor.systemGroupedBackground))
        .refreshable {
            async let w: () = WeatherManager.shared.fetchWeather(
                cityName: viewModel.city.name,
                buildings: viewModel.city.buildings
            )
            async let e: () = TicketmasterService.shared.fetchEvents(
                cityName: viewModel.city.name,
                buildings: viewModel.city.buildings
            )
            async let f: () = FoursquareService.shared.fetchTopEats(
                cityName: viewModel.city.name,
                buildings: viewModel.city.buildings
            )
            async let c: () = CampusEventsService.shared.fetchEvents(for: viewModel.city)
            _ = await (w, e, f, c)
        }
        .onAppear {
            ProximityManager.shared.startMonitoring(
                buildings: viewModel.city.buildings,
                visitedIDs: GlobalProgressManager.shared.visitedIDs
            )
            Task {
                await WeatherManager.shared.fetchWeather(
                    cityName: viewModel.city.name,
                    buildings: viewModel.city.buildings
                )
            }
            Task {
                await FoursquareService.shared.fetchTopEats(
                    cityName: viewModel.city.name,
                    buildings: viewModel.city.buildings
                )
            }
            Task {
                await TicketmasterService.shared.fetchEvents(
                    cityName: viewModel.city.name,
                    buildings: viewModel.city.buildings
                )
            }
            Task {
                await CampusEventsService.shared.fetchEvents(for: viewModel.city)
            }
        }
        .onDisappear {
            ProximityManager.shared.stopMonitoring()
        }
        .onReceive(viewModel.$didJustComplete) { justCompleted in
            if justCompleted {
                // One-shot presentation for the celebration overlay
                HapticManager.shared.trigger(.success)
                SoundManager.shared.playStampSound()
                showingCelebration = true
                // Reset the flag so it can fire again for future completions
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    viewModel.didJustComplete = false
                }
            }
        }
        .fullScreenCover(isPresented: $showingCelebration) {
            celebrationCover
        }
        .fullScreenCover(isPresented: $showingQuiz) {
            NavigationStack {
                QuizView(buildings: viewModel.city.buildings, cityName: viewModel.city.name)
            }
            #if os(macOS)
            // On the Mac a full-screen cover becomes a sheet sized to its content; the quiz's
            // side-by-side layout needs room or the answer buttons collapse to nothing.
            .frame(minWidth: 1100, idealWidth: 1200, minHeight: 760, idealHeight: 820)
            #endif
        }
        // iPhone: swipe-down sheet. iPad: full screen, since an iPad sheet is a small centered window.
        .sheet(isPresented: mapPresented(fullScreen: false)) { cityMap }
        .fullScreenCover(isPresented: mapPresented(fullScreen: true)) { cityMap }
        .sheet(isPresented: tripPlannerPresented(fullScreen: false)) { TripPlannerView(viewModel: viewModel, initialTripID: tripPlannerTripID) }
        .fullScreenCover(isPresented: tripPlannerPresented(fullScreen: true)) { TripPlannerView(viewModel: viewModel, initialTripID: tripPlannerTripID) }
        #if os(iOS)
        .fullScreenCover(isPresented: $showingExplore) {
            CityExploreView(
                buildings: viewModel.city.buildings,
                visitedIDs: GlobalProgressManager.shared.visitedIDs,
                cityName: viewModel.city.name
            )
        }
        #endif
        .alert("Confirm Reset", isPresented: $showingFinalConfirmation) {
            Button("Yes, Reset", role: .destructive) { executeResetAction() }
            Button("Cancel", role: .cancel) { resetType = .none }
        } message: {
            Text(viewModel.getConfirmationMessage(for: resetType))
        }
    }
    
    // MARK: - Toolbar
    /// Quiz, Plan a Trip and (campuses) Campus Visit, shown as one row of tiles.
    private var actionTiles: [CityActionTile] {
        var tiles = [
            CityActionTile(
                id: "quiz",
                title: highScore == 10
                    ? NSLocalizedString("Quiz Mastered", comment: "City page tile: quiz with a perfect score")
                    : NSLocalizedString("Architecture Quiz", comment: "City page tile: start the quiz"),
                detail: highScore > 0
                    ? String(format: NSLocalizedString("Best %d/10", comment: "City page tile: best quiz score, e.g. Best 7/10"), highScore)
                    : NSLocalizedString("10 questions", comment: "City page tile: quiz length"),
                systemImage: highScore == 10 ? "medal.fill" : "doc.text.magnifyingglass",
                iconColor: highScore == 10 ? .yellow : .adventureOrange,
                accessibilityHint: NSLocalizedString("Double tap to start the quiz.", comment: "City page tile: VoiceOver hint"),
                action: { showingQuiz = true }
            ),
            CityActionTile(
                id: "trip",
                title: NSLocalizedString("Plan a Trip", comment: "City page tile: open the trip planner"),
                detail: NSLocalizedString("Day by day", comment: "City page tile: what the trip planner does"),
                systemImage: "suitcase.rolling.fill",
                accessibilityHint: NSLocalizedString("Plan your days, stop by stop.", comment: "City page tile: VoiceOver hint for Plan a Trip"),
                action: {
                    tripPlannerTripID = nil
                    showingTripPlanner = true
                }
            ),
        ]
        // Campuses only: a ready-made one-day walk of every landmark
        if viewModel.city.isCampus {
            let hasVisit = TripStore.shared.existingCampusVisit(for: viewModel.city) != nil
            tiles.append(CityActionTile(
                id: "visit",
                title: NSLocalizedString("Campus Visit", comment: "Campus page tile: the one-day walking tour of the campus"),
                detail: hasVisit
                    ? NSLocalizedString("Open your visit", comment: "Campus page tile: the campus visit trip already exists")
                    : String(format: NSLocalizedString("%d stops, 1 day", comment: "Campus page tile: e.g. 5 stops, 1 day"), viewModel.city.buildings.count),
                systemImage: "graduationcap.fill",
                accessibilityHint: NSLocalizedString("Opens a one-day walking trip of every landmark on campus.", comment: "Campus page: VoiceOver hint for the Plan a Campus Visit card"),
                action: {
                    tripPlannerTripID = TripStore.shared.campusVisitTrip(for: viewModel.city).id
                    showingTripPlanner = true
                }
            ))
        }
        return tiles
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        

        #if os(iOS)
        // Only show Explore for cities that have a bundled USDZ.
        if Bundle.main.url(forResource: viewModel.city.name.lowercased(), withExtension: "usdz") != nil {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingExplore = true
                } label: {
                    Image(systemName: "globe")
                        .font(.system(size: 20))
                        .fontWeight(isHighContrast ? .black : .regular)
                        .foregroundColor(brandColor)
                }
                .accessibilityLabel("Explore \(viewModel.city.name) in AR")
                .accessibilityHint("Places a 3D city model in your space")
            }
        }
        #endif

        // Campuses only: add the school to My College List
        if viewModel.city.isCampus {
            ToolbarItem(placement: .navigationBarTrailing) {
                CollegeListButton(campus: viewModel.city)
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showingMap = true
            } label: {
                Image(systemName: "map")
                    .font(.system(size: 20))
                    .fontWeight(isHighContrast ? .black : .regular)
                    .foregroundColor(brandColor)
            }
            .accessibilityLabel("View \(viewModel.city.name) map")
            .accessibilityHint("Shows all landmarks on a map")
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Section("Report") {
                    if let url = reportCityURL() {
                        Link(destination: url) {
                            Label(LocalizedStringKey("cityDetail.menu.reportCityInfo"), systemImage: "flag")
                        }
                    }
                }
                Section("Reset Progress") {
                    Button(role: .destructive) { promptReset(.quiz) } label: { Label("Reset Quiz Score", systemImage: "arrow.counterclockwise") }
                    Button(role: .destructive) { promptReset(.passport) } label: { Label("Reset Stamps", systemImage: "person.badge.minus") }
                    Button(role: .destructive) { promptReset(.photos) } label: { Label("Reset Photos", systemImage: "photo.on.rectangle.angled") }
                    Button(role: .destructive) { promptReset(.everything) } label: { Label("Reset Everything", systemImage: "trash") }
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 22))
                    .fontWeight(isHighContrast ? .black : .regular)
                    .foregroundColor(brandColor)
                    .contentShape(Circle())
            }
            .accessibilityLabel("More options")
        }
    }
    
    // MARK: - Helpers
    private func promptReset(_ type: CityDetailViewModel.ResetType) {
        self.resetType = type
        self.showingFinalConfirmation = true
    }
    
    private func executeResetAction() {
        viewModel.resetProgress(for: resetType)
        if resetType == .everything || resetType == .quiz {
            highScore = 0
        }
        resetType = .none
    }

    private func reportCityURL() -> URL? {
        FeedbackMail.place(viewModel.city)
    }
}
