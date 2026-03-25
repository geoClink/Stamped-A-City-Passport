//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI

// MARK: - CITY LIST VIEW
struct CityListView: View {
    @Environment(\.isSearching) private var isSearching
    
    @StateObject var viewModel = CityViewModel()
    @ObservedObject var progressManager = GlobalProgressManager.shared
    
    @Environment(\.horizontalSizeClass) var sizeClass

    
    @Environment(\.colorSchemeContrast) var systemContrast
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @AppStorage("high_contrast_mode") var manualHighContrast = false
    @AppStorage("hasSeenPassportHint") var hasSeenPassportHint: Bool = false
    
    @State var expandedCountries: [CityLocation.Country: Bool] = [:]
    @State var expandedContinents: [CityLocation.Continent: Bool] = [:]
    @State var searchText = ""
    @State var showingSettings = false
    @State var showingPassport = false
    @State var selectedCity: CityLocation.City?
    @State var columnVisibility = NavigationSplitViewVisibility.all
    
    var isHighContrast: Bool { manualHighContrast || systemContrast == .increased }
    var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    var brandColor: Color { isHighContrast ? .primary : Color.adventureOrange }


    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // SIDEBAR
            List(selection: $selectedCity) {
                if searchText.isEmpty {
                    headerSection
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
                } else {
                    let results = viewModel.filteredResults(query: searchText)
                    
                    if results.isEmpty {
                        emptySearchContent
                    } else {
                        ForEach(results) { result in
                            NavigationLink(value: result.city) {
                                HStack(spacing: 15) {
                                    Image(systemName: result.isLandmark ? "mappin.and.ellipse" : "building.2.fill")
                                        .foregroundColor(isHighContrast ? .primary : Color.adventureOrange)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading) {
                                        Text(result.title)
                                            .fontWeight(isHighContrast ? .black : .semibold)
                                            .foregroundColor(.primary)
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
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
            .disabled(!hasSeenPassportHint)
            .blur(radius: hasSeenPassportHint ? 0 : (isHighContrast ? 0 : 3))
            
            .safeAreaInset(edge: .bottom) {
                if hasSeenPassportHint && searchText.isEmpty {
                    passportFloatingButton
                        .padding(.vertical, 8)
                        .background {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .mask {
                                    LinearGradient(
                                        stops: [
                                            .init(color: .clear, location: 0),
                                            .init(color: .black, location: 0.2), // Quick fade in
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
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Cities, Landmarks or Architects")
            .toolbar { sidebarToolbar }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: searchText.isEmpty)

        } detail: {
            NavigationStack {
                if let city = selectedCity {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            CityDetailView(city: city)
                            
                            Divider()
                                .padding(.top, 10)
                                .padding(.bottom, 25)
                                .padding(.horizontal, 25)
                            
//                            CityItineraryView(city: city)
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
        .fullScreenCover(isPresented: $showingPassport) {
            PassportGalleryView(cities: viewModel.allCities)
        }
        .overlay {
            if !hasSeenPassportHint {
                onboardingOverlay
            }
        }
    }

    // MARK: - List Sections
    
    @ViewBuilder
    private func continentSection(_ group: ContinentGroup) -> some View {
        let isExpanded = expandedContinents[group.id, default: false]
        
        Section {
            DisclosureGroup(isExpanded: Binding(
                get: { isExpanded },
                set: { newValue in
                    if newValue { HapticManager.shared.trigger(.selection) }
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        expandedContinents[group.id] = newValue
                    }
                }
            )) {
                ForEach(group.countries) { countryGroup in
                    cityCountrySection(country: countryGroup.id, cities: countryGroup.cities)
                }
            } label: {
                ContinentHeader(continent: group.id, isHighContrast: isHighContrast, isExpanded: isExpanded)
            }
        }
    }

    @ViewBuilder
    private var searchSection: some View {
        let results = viewModel.filteredResults(query: searchText)
        if results.isEmpty {
            emptySearchContent
        } else {
            ForEach(results) { result in
                NavigationLink(value: result.city) {
                    searchResultRow(result)
                }
            }
        }
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

// MARK: - HELPER: ITINERARY SECTION (iOS 15/16+ COMPATIBLE)
struct CityItinerarySection: View {
    let city: CityLocation.City
    let brandColor: Color
    
    var buildings: [Building] {
        BuildingRegistry.data[city] ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            VStack(alignment: .leading, spacing: 4) {
                Text(city.country.localGreeting)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(brandColor)
                
                Text("Architectural Itinerary")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding(.horizontal)
            
            if buildings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "building.2")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No landmarks registered for this city yet.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(buildings.sorted(by: { $0.yearBuilt < $1.yearBuilt }).enumerated()), id: \.offset) { index, building in
                        HStack(alignment: .top, spacing: 20) {
                            
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(city.country.continent.iconGradient)
                                    .frame(width: 14, height: 14)
                                
                                if index != buildings.count - 1 {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(width: 2, height: 90)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(building.name)
                                    .font(.headline)
                                
                                Text("\(String(building.yearBuilt)) • \(building.architect)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(building.newUse.lowercased().contains("museum") ? "Visit the galleries." : "Admire the \(building.buildingStyle) style.")
                                    .font(.subheadline)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(brandColor.opacity(0.1))
                                    .cornerRadius(6)
                                
                                if let food = building.foodSpots.first {
                                    Label(food, systemImage: "fork.knife")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.bottom, 25)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
