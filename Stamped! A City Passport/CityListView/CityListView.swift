//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI

extension EnvironmentValues {
    /// True when the whole window is wide (iPad, unfolded iPhone Duo). Screens inside a split
    /// view column read this instead of their own size class: on the unfolded Duo each column
    /// is compact, so the map opened as a half-screen sheet instead of full screen.
    @Entry var isWideWindow = false
}

// MARK: - CITY LIST VIEW
struct CityListView: View {
    
    @StateObject var viewModel = CityViewModel()
    @ObservedObject var progressManager = GlobalProgressManager.shared
    @EnvironmentObject var navManager: NavigationManager
    
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.colorSchemeContrast) var systemContrast
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @AppStorage("high_contrast_mode") var manualHighContrast = false
    @AppStorage("hasSeenPassportHint") var hasSeenPassportHint: Bool = false
    
    @State var expandedCountries: [CityLocation.Country: Bool] = [:]
    @State var expandedContinents: [CityLocation.Continent: Bool] = [:]
    @State var expandedCampusGroups: [CampusGroup.Kind: Bool] = [:]
    @State var isCampusSectionExpanded = false
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @State var searchText = ""
    /// Results for `searchedText`, worked out shortly after typing stops
    @State private var searchResults: [MixedSearchResult] = []
    @State private var searchedText = ""
    /// True while the search field is active, even before anything is typed
    @State private var isSearchActive = false
    @State var showingSettings = false
    @State var showingMyJourney = false
    @State var showingPassport = false
    @State var showingAchievements = false
    @State var showingWorldMap = false
    @State var showingMyTrips = false
    @State var showingCollegeList = false
    @ObservedObject var collegeList = CollegeListStore.shared
    @State var selectedCity: CityLocation.City?
    @State var columnVisibility = NavigationSplitViewVisibility.all
    
    var isHighContrast: Bool { manualHighContrast || systemContrast == .increased }
    var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    var brandColor: Color { isHighContrast ? .primary : Color.adventureOrange }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedCity) {
                if searchText.isEmpty {
                    headerSection
                        // No side insets: the tiles and cards draw their own backgrounds, so the
                        // row's default inset made them sit ~16 pt further in than the search bar
                        // and the continent cards below
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    
                    ForEach(viewModel.groupedByContinent) { continentGroup in
                        let isExpanded = expandedContinents[continentGroup.id, default: false]
                        
                        Section {
                            DisclosureGroup(isExpanded: Binding(
                                get: { isExpanded },
                                set: { newValue in
                                    if newValue { HapticManager.shared.trigger(.selection) }
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                        expandedContinents[continentGroup.id] = newValue
                                    }
                                }
                            )) {
                                ForEach(continentGroup.countries) { countryGroup in
                                    cityCountrySection(country: countryGroup.id, cities: countryGroup.cities)
                                }
                            } label: {
                                ContinentHeader(
                                    continent: continentGroup.id,
                                    isHighContrast: isHighContrast,
                                    isExpanded: isExpanded
                                )
                            }
                        }
                    }

                    campusSection
                } else {
                    let results = searchResults

                    if results.isEmpty && searchedText == searchText {
                        emptySearchContent
                    } else {
                        ForEach(results) { result in
                            NavigationLink(value: result.city) {
                                searchResultRow(result)
                            }
                            .tag(result.city)
                            .simultaneousGesture(TapGesture().onEnded {
                                HapticManager.shared.trigger(.selection)
                                selectedCity = result.city
                            })
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            // Same gap between every block on home (the system default is much larger)
            .listSectionSpacing(DS.Space.m)
            .disabled(!hasSeenPassportHint)
            .blur(radius: hasSeenPassportHint ? 0 : (isHighContrast ? 0 : 3))
            .safeAreaInset(edge: .bottom) {
                // Hidden while searching, so it never covers results or sits on the keyboard
                if hasSeenPassportHint && searchText.isEmpty && !isSearchActive {
                    passportFloatingButton
                        .padding(.vertical, 8)
                        .background {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .mask {
                                    LinearGradient(
                                        stops: [
                                            .init(color: .clear, location: 0),
                                            .init(color: .black, location: 0.2),
                                            .init(color: .black, location: 1.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                }
                                .ignoresSafeArea()
                        }
                }
            }
            .searchable(text: $searchText, isPresented: $isSearchActive, placement: .navigationBarDrawer(displayMode: .always), prompt: "Cities, Landmarks or Architects")
            // Search runs once typing pauses, not on every letter, so the keyboard keeps up
            .task(id: searchText) {
                if !searchText.isEmpty {
                    try? await Task.sleep(for: .milliseconds(150))
                    if Task.isCancelled { return }
                }
                searchResults = viewModel.filteredResults(query: searchText)
                searchedText = searchText
            }
            .toolbar { sidebarToolbar }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: searchText.isEmpty)

        } detail: {
            NavigationStack {
                if let city = selectedCity {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            CityDetailView(city: city)
                            CityItineraryView(city: city)
                        }
                    }
                    .id(city.id)
                    .background(Color(UIColor.systemGroupedBackground))
                    .navigationBarBackButtonHidden(horizontalSizeClass == .regular)
                } else {
                    welcomePlaceholder
                }
            }
        }
        .accentColor(brandColor)
        .fullScreenCover(isPresented: $showingSettings) { SettingsView() }
        .fullScreenCover(isPresented: $showingMyJourney) { MyJourneyView() }
        .sheet(isPresented: $showingAchievements) { AchievementsView() }
        .sheet(isPresented: $showingWorldMap) { WorldMapView() }
        // Like the trip planner: a sheet on iPhone, full screen on iPad (room for its split view)
        .sheet(isPresented: $showingCollegeList) {
            CollegeListView(onOpenCampus: { campus in
                showingCollegeList = false
                selectedCity = campus
            })
        }
        .sheet(isPresented: myTripsPresented(fullScreen: false)) { MyTripsView() }
        .fullScreenCover(isPresented: myTripsPresented(fullScreen: true)) { MyTripsView() }
        .fullScreenCover(isPresented: $showingPassport) {
            PassportGalleryView(cities: viewModel.allCities)
        }
        .onChange(of: navManager.spotlightCity) { _, city in
            if let city {
                selectedCity = city
                // Clear it so opening the same city again (from Spotlight or a link) still works
                navManager.spotlightCity = nil
            }
        }
        .overlay {
            if !hasSeenPassportHint {
                onboardingOverlay
            }
        }
        // Last, so the sheets and full-screen covers above see it too
        .environment(\.isWideWindow, horizontalSizeClass == .regular)
    }

    // MARK: - List Sections

    /// "Campus Architecture": every campus below the continents, US campuses by conference
    /// and the rest by country.
    @ViewBuilder
    private var campusSection: some View {
        let campusGroups = viewModel.campusGroups
        if !campusGroups.isEmpty {
            Section {
                DisclosureGroup(isExpanded: Binding(
                    get: { isCampusSectionExpanded },
                    set: { newValue in
                        if newValue { HapticManager.shared.trigger(.selection) }
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            isCampusSectionExpanded = newValue
                        }
                    }
                )) {
                    collegeListRow
                    ForEach(campusGroups) { group in
                        campusGroupSection(group)
                    }
                } label: {
                    CampusSectionHeader(isHighContrast: isHighContrast, isExpanded: isCampusSectionExpanded)
                }
            }
        }
    }

    /// On home, under the shortcut tiles: the student's schools and the road trip, one tap away.
    /// (Before, the list was only inside Campus Architecture at the very bottom.)
    var collegeListCard: some View {
        let schools = collegeList.campuses
        let summary: String = schools.isEmpty
            ? NSLocalizedString("Save the schools you're considering, then plan a road trip to visit them.", comment: "Home: My College List card when the list is empty")
            : ListFormatter.localizedString(byJoining: schools.prefix(3).map(\.campusVisitShortName))
                + (schools.count > 3 ? " " + String(format: NSLocalizedString("+%d more", comment: "Home: My College List card, more schools than shown"), schools.count - 3) : "")
        return HStack(spacing: 14) {
            Image(systemName: "graduationcap.fill")
                .font(.title2)
                .foregroundStyle(isHighContrast ? AnyShapeStyle(Color.primary) : AnyShapeStyle(LinearGradient.sectionIcon))
                .frame(width: 40, height: 40)
                .background(Circle().fill(brandColor.opacity(isHighContrast ? 0 : 0.12)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(NSLocalizedString("My College List", comment: "City list: row that opens the user's list of campuses"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if !schools.isEmpty {
                        Text("\(schools.count)")
                            .font(.caption.monospaced().bold())
                            .foregroundStyle(brandColor)
                    }
                }
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(isHighContrast ? .primary : .secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(isHighContrast ? Color(UIColor.systemBackground) : Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        // A tap gesture, not a Button: it sits in the same List row as the shortcut tiles
        .onTapGesture {
            HapticManager.shared.trigger(.selection)
            showingCollegeList = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { showingCollegeList = true }
    }

    /// First row of "Campus Architecture": the schools a student is considering, and their road trip.
    private var collegeListRow: some View {
        Button {
            HapticManager.shared.trigger(.selection)
            showingCollegeList = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .foregroundColor(isHighContrast ? .primary : brandColor)
                Text(NSLocalizedString("My College List", comment: "City list: row that opens the user's list of campuses"))
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                Spacer()
                if !collegeList.isEmpty {
                    Text("\(collegeList.campuses.count)")
                        .font(.caption.monospaced().bold())
                        .foregroundColor(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func searchResultRow(_ result: MixedSearchResult) -> some View {
        HStack(spacing: 15) {
            let iconName: String = {
                if result.subtitle.contains("Architect") { return "person.crop.circle.fill" }
                if result.isLandmark { return "mappin.and.ellipse" }
                return "building.2.fill"
            }()
            
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(brandColor)
                .frame(width: 32, height: 32)
                .background(brandColor.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.headline)
                    .fontWeight(isHighContrast ? .black : .semibold)
                    .foregroundColor(.primary)
                
                Text(result.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
