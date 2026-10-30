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
    /// Which part of the world the home list shows: a continent's raw value, or "campuses"
    @AppStorage("home_explore_filter") var exploreFilter = CityLocation.Continent.northAmerica.rawValue
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @State var searchText = ""
    /// Results for `searchedText`, worked out shortly after typing stops
    @State private var searchResults: [MixedSearchResult] = []
    @State private var searchedText = ""
    /// True while the search field is active, even before anything is typed
    @State var isSearchActive = false
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
    var isIPad: Bool { DeviceInfo.isLargeScreen }
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
                    
                    exploreFilterBar
                        .listRowInsets(EdgeInsets(top: DS.Space.s, leading: 0, bottom: DS.Space.s, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    if exploreFilter == Self.campusFilter {
                        campusSection
                    } else {
                        // One continent at a time, its countries shown open: a city is one tap away
                        ForEach(selectedContinentGroup?.countries ?? []) { countryGroup in
                            Section {
                                ForEach(countryGroup.cities) { city in
                                    cityRowWrapper(city: city)
                                }
                            } header: {
                                CountryHeaderLabel(country: countryGroup.id,
                                                   isMastered: viewModel.isCountryMastered(countryGroup.id),
                                                   isHighContrast: isHighContrast)
                            }
                        }
                    }
                } else {
                    let results = searchResults

                    if results.isEmpty && searchedText == searchText {
                        emptySearchContent
                    } else {
                        ForEach(results) { result in
                            #if os(macOS)
                            // Every landmark of a city shares that city's tag, so the Mac list would
                            // highlight all of them at once. Plain buttons select the city without that.
                            Button {
                                selectedCity = result.city
                            } label: {
                                searchResultRow(result)
                            }
                            .buttonStyle(.plain)
                            .selectionDisabled()
                            #else
                            NavigationLink(value: result.city) {
                                searchResultRow(result)
                            }
                            .tag(result.city)
                            .simultaneousGesture(TapGesture().onEnded {
                                HapticManager.shared.trigger(.selection)
                                selectedCity = result.city
                            })
                            #endif
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
            .searchable(text: $searchText, isPresented: $isSearchActive, placement: .sidebarSearch, prompt: "Cities, Landmarks or Architects")
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
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 460)
            #endif
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: searchText.isEmpty)

        } detail: {
            NavigationStack {
                if let city = selectedCity {
                    #if os(macOS)
                    // Mac: the 3D map fills the window, the city's details sit in an inspector
                    MacCityWorkspace(city: city)
                        .id(city.id)
                    #else
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // The itinerary is in the city page's Plan tab
                            CityDetailView(city: city)
                        }
                    }
                    .id(city.id)
                    .background(Color(UIColor.systemGroupedBackground))
                    .navigationBarBackButtonHidden(horizontalSizeClass == .regular)
                    #endif
                } else {
                    welcomePlaceholder
                }
            }
        }
        .accentColor(brandColor)
        .fullScreenCover(isPresented: $showingSettings) { SettingsView() }
        .fullScreenCover(isPresented: $showingMyJourney) { MyJourneyView() }
        .sheet(isPresented: $showingAchievements) { AchievementsView() }
        .sheet(isPresented: $showingWorldMap) {
            WorldMapView()
            #if os(macOS)
                // The map has no natural size, so without this the Mac sheet collapses to a thin strip.
                .frame(minWidth: 1100, minHeight: 760)
            #endif
        }
        // Like the trip planner: a sheet on iPhone, full screen on iPad (room for its split view)
        .sheet(isPresented: $showingCollegeList) {
            CollegeListView(onOpenCampus: { campus in
                showingCollegeList = false
                selectedCity = campus
            })
            #if os(macOS)
            // Like the World Map, the list has no natural size, so the Mac sheet collapsed without this.
            .frame(minWidth: 900, minHeight: 700)
            #endif
        }
        .sheet(isPresented: myTripsPresented(fullScreen: false)) { MyTripsView() }
        .fullScreenCover(isPresented: myTripsPresented(fullScreen: true)) { MyTripsView() }
        .fullScreenCover(isPresented: $showingPassport) {
            PassportGalleryView(cities: viewModel.allCities)
        }
        #if os(macOS)
        .onChange(of: navManager.menuCommand) { _, command in
            guard let command else { return }
            navManager.menuCommand = nil
            handleMenuCommand(command)
        }
        #endif
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

    /// The Campuses filter: the student's College List first, then every campus,
    /// US campuses by conference and the rest by country.
    @ViewBuilder
    private var campusSection: some View {
        Section {
            collegeListRow
        }
        ForEach(viewModel.campusGroups) { group in
            campusGroupSection(group)
        }
    }

    // MARK: - Explore filter

    static let campusFilter = "campuses"

    private var selectedContinentGroup: ContinentGroup? {
        viewModel.groupedByContinent.first { $0.id.rawValue == exploreFilter }
            ?? viewModel.groupedByContinent.sorted { $0.id < $1.id }.first
    }

    /// Continents, then Campuses, as a row of chips that scrolls sideways
    private var exploreFilterBar: some View {
        let continents = viewModel.groupedByContinent.map(\.id).sorted()
        let selected = exploreFilter == Self.campusFilter ? Self.campusFilter : (selectedContinentGroup?.id.rawValue ?? "")
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Space.s) {
                    ForEach(continents, id: \.self) { continent in
                        filterChip(continent.localizedName, systemImage: continent.iconName,
                                   isSelected: selected == continent.rawValue) {
                            exploreFilter = continent.rawValue
                        }
                        .id(continent.rawValue)
                    }
                    if !viewModel.campusGroups.isEmpty {
                        filterChip(NSLocalizedString("Campuses", comment: "Home filter chip: show campuses instead of a continent's cities"),
                                   systemImage: "graduationcap.fill",
                                   isSelected: selected == Self.campusFilter) {
                            exploreFilter = Self.campusFilter
                        }
                        .id(Self.campusFilter)
                    }
                }
            }
            // The chosen chip may be off the right edge (North America, Campuses): bring it into view
            .onAppear { proxy.scrollTo(selected, anchor: .center) }
        }
    }

    private func filterChip(_ title: String, systemImage: String, isSelected: Bool,
                            action: @escaping () -> Void) -> some View {
        // A tap gesture, not a Button: every Button in a List row fires on any tap in the row
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.footnote)
                .foregroundStyle(isSelected ? AnyShapeStyle(isHighContrast ? Color(UIColor.systemBackground) : .white) : AnyShapeStyle(isHighContrast ? Color.primary : Color.adventureOrange))
                .accessibilityHidden(true)
            Text(title)
        }
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? (isHighContrast ? Color(UIColor.systemBackground) : .white) : .primary)
            .background(
                Capsule().fill(isSelected
                    ? (isHighContrast ? Color.primary : Color.adventureOrange)
                    : (isHighContrast ? Color(UIColor.systemBackground) : Color(UIColor.secondarySystemGroupedBackground)))
            )
            .overlay(Capsule().stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2))
            .contentShape(Capsule())
            .onTapGesture {
                guard !isSelected else { return }
                HapticManager.shared.trigger(.selection)
                withAnimation(.snappy) { action() }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { action() }
    }

    /// First row of the Campuses filter: the schools a student is considering, and their road trip.
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

#if os(macOS)
// MARK: - Mac menu bar commands
extension CityListView {
    func handleMenuCommand(_ command: MenuCommand) {
        switch command {
        case .search:
            columnVisibility = .all
            isSearchActive = true
        case .passport: showingPassport = true
        case .myJourney: showingMyJourney = true
        case .myTrips: showingMyTrips = true
        case .worldMap: showingWorldMap = true
        case .achievements: showingAchievements = true
        case .collegeList: showingCollegeList = true
        case .settings: showingSettings = true
        }
    }
}
#endif
