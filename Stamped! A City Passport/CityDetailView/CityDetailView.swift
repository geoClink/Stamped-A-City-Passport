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
    
    @AppStorage("high_contrast_mode") var appHighContrast = false
    @AppStorage("reduce_motion") var reduceMotion = false
    @AppStorage var highScore: Int
    
    @State private var showingQuiz = false
    @State private var showingFinalConfirmation = false
    @State private var showingCelebration = false
    @State private var showingMap = false
    @State private var resetType: CityDetailViewModel.ResetType = .none
    
    var isHighContrast: Bool { systemContrast == .increased || appHighContrast }
    var brandColor: Color { isHighContrast ? .primary : Color.adventureOrange }
    
    init(city: CityLocation.City) {
        _viewModel = StateObject(wrappedValue: CityDetailViewModel(city: city))
        self._highScore = AppStorage(wrappedValue: 0, "high_score_\(city.name)")
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: isHighContrast ? 32 : 24) {
                CityHeroHeader(
                    city: viewModel.city,
                    progress: viewModel.progress,
                    isHighContrast: isHighContrast,
                    masteryTier: viewModel.getMastery(isHighContrast: isHighContrast).tier
                )
                
                QuizInteractionCard(
                    highScore: highScore,
                    isHighContrast: isHighContrast,
                    onTap: {
                        HapticManager.shared.trigger(.selection)
                        showingQuiz = true
                    }
                )
                .padding(.horizontal)
                .hoverEffect(.lift)
                
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
                
                Divider()

                LandmarkSection(viewModel: viewModel, isHighContrast: isHighContrast)

                Divider()

                BuildingTimelineSection(
                    buildings: viewModel.city.buildings,
                    visitedIDs: GlobalProgressManager.shared.visitedIDs,
                    isHighContrast: isHighContrast
                )

                // Weather — hidden when failed/empty so we don't advertise broken state
                let weather = WeatherManager.shared
                if weather.isLoading || !weather.temperature.isEmpty {
                    Divider()
                    WeatherSection(weather: weather, isHighContrast: isHighContrast)
                }

                // Events — shown before Top Eats since Ticketmaster is more reliable
                let events = TicketmasterService.shared
                if events.isLoading || !events.events.isEmpty {
                    Divider()
                    EventsSection(service: events, isHighContrast: isHighContrast)
                }

                // Top Eats — hidden when failed so we don't show "Couldn't load"
                let eats = FoursquareService.shared
                if eats.isLoading || !eats.venues.isEmpty {
                    Divider()
                    TopEatsSection(service: eats, isHighContrast: isHighContrast)
                }

                Divider()

                TravelInfoSection(viewModel: viewModel, isHighContrast: isHighContrast)
                
            }
            .padding(.bottom)
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
            _ = await (w, e, f)
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
        }
        .sheet(isPresented: $showingMap) {
            NavigationStack {
                CityMapView(
                    buildings: viewModel.city.buildings,
                    visitedIDs: GlobalProgressManager.shared.visitedIDs,
                    cityName: viewModel.city.name
                )
            }
        }
        .alert("Confirm Reset", isPresented: $showingFinalConfirmation) {
            Button("Yes, Reset", role: .destructive) { executeResetAction() }
            Button("Cancel", role: .cancel) { resetType = .none }
        } message: {
            Text(viewModel.getConfirmationMessage(for: resetType))
        }
    }
    
    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        
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
}
