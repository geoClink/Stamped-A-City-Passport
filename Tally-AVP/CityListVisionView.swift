//
//  CityListVisionView.swift
//  Tally-AVP
//
//  Main window: every city in a searchable sidebar, with the selected city's
//  photoreal 3D map on the right.
//

import SwiftUI

struct CityListVisionView: View {

    private let store = VisionStore.shared
    @State private var selectedCity: String?
    @State private var searchText = ""
    @State private var showingTipJar = false
    /// The iPhone app's passport and achievements, shared code, shown as sheets
    @State private var showingPassport = false
    @State private var showingAchievements = false
    @State private var showingCollegeList = false
    /// Explore Together keeps everyone in a SharePlay session on the same city
    private let sharePlay = SharePlayExplorer.shared
    @Environment(\.openWindow) private var openWindow
    /// Set by the globe's "Show in Main Window" button (see GlobeVolumeView).
    @AppStorage("globeRequestedCity") private var globeRequestedCity = ""
    /// Read by the globe, which highlights the city selected here.
    @AppStorage("globeHighlightedCity") private var globeHighlightedCity = ""

    private var filteredCities: [String] {
        guard !searchText.isEmpty else { return store.cityNames }
        return store.cityNames.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedCity) {
                // Today in history at the app's landmarks and cities. A plain row (not a
                // pinned inset) so it scrolls away with the list instead of covering it.
                if searchText.isEmpty {
                    OnThisDayCard(landmarks: store.buildingsByCity.mapValues { $0.map(\.name) },
                                  cities: store.cityNames) { city in selectedCity = city }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                }
                ForEach(filteredCities, id: \.self) { city in
                    CityRow(
                        cityName: city,
                        visitedCount: store.visitedCount(for: city),
                        total: store.buildings(for: city).count
                    )
                }
            }
            .navigationTitle("Stamped!")
            .searchable(text: $searchText, prompt: "Search cities")
            .toolbar {
                ToolbarItem {
                    Button("Globe", systemImage: "globe.americas.fill") {
                        openWindow(id: "globe")
                    }
                    .accessibilityHint("Opens a 3D globe of every city in its own window")
                }
                ToolbarItem {
                    // Every stamp from the iPhone app, synced over iCloud
                    Button("My Passport", systemImage: "book.closed.fill") {
                        showingPassport = true
                    }
                    .accessibilityHint("Shows your city and campus stamps")
                }
                ToolbarItem {
                    // Schools saved on iPhone; picking one flies there on the map
                    Button("My College List", systemImage: "graduationcap.fill") {
                        showingCollegeList = true
                    }
                    .accessibilityHint("Shows the campuses you saved")
                }
                ToolbarItem {
                    Button("Achievements", systemImage: "trophy.fill") {
                        showingAchievements = true
                    }
                    .accessibilityHint("Shows the badges you've earned")
                }
                ToolbarItem {
                    // The iPhone app's trip planner, in its own window beside the map
                    Button("My Trips", systemImage: "suitcase.fill") {
                        openWindow(id: "trips")
                    }
                    .accessibilityHint("Opens your trips in their own window")
                }
                ToolbarItem {
                    Button("Support Stamped!", systemImage: "heart") {
                        showingTipJar = true
                    }
                }
            }
        } detail: {
            if let city = selectedCity {
                CityMapVisionView(cityName: city)
                    .id(city)   // fresh map + camera for each city
            } else {
                ContentUnavailableView(
                    "Pick a City",
                    systemImage: "globe.americas.fill",
                    description: Text("Fly through \(store.cityNames.count) cities in 3D and explore their landmarks.")
                )
            }
        }
        .sheet(isPresented: $showingTipJar) {
            NavigationStack {
                TipJarView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingTipJar = false }
                        }
                    }
            }
            .tint(DS.Palette.accent)
            .frame(minWidth: 560, minHeight: 640)
        }
        .sheet(isPresented: $showingPassport) {
            // No .tint here: on visionOS it fills the glass toolbar buttons orange, hiding their orange icons
            PassportGalleryView(cities: CityLocation.City.allCases)
                .frame(minWidth: 760, minHeight: 820)
        }
        .sheet(isPresented: $showingCollegeList) {
            CollegeListView(onOpenCampus: { campus in
                showingCollegeList = false
                searchText = ""
                selectedCity = campus.name
            })
            .frame(minWidth: 700, minHeight: 760)
        }
        .sheet(isPresented: $showingAchievements) {
            AchievementsView()
                .frame(minWidth: 760, minHeight: 820)
        }
        .onAppear {
            if selectedCity == nil { selectedCity = store.cityNames.contains("New York") ? "New York" : store.cityNames.first }
        }
        .onChange(of: globeRequestedCity) { _, city in
            guard !city.isEmpty else { return }
            searchText = ""            // make sure the city isn't hidden by a search
            selectedCity = city
            globeRequestedCity = ""    // reset, so picking the same city again still works
        }
        .onChange(of: selectedCity) { _, city in
            globeHighlightedCity = city ?? ""
            sharePlay.cityChanged(to: city)    // in SharePlay, everyone follows
        }
        // Joined a friend's SharePlay, or a friend picked another city
        .onChange(of: sharePlay.sharedCity) { _, city in
            guard let city, store.cityNames.contains(city) else { return }
            searchText = ""
            selectedCity = city
        }
        // Listens for Explore Together sessions, started here or by a friend
        .task { await sharePlay.listenForSessions() }
    }
}

// MARK: - City row

private struct CityRow: View {
    let cityName: String
    let visitedCount: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(cityName).font(.headline)
                Spacer()
                if total > 0 && visitedCount == total {
                    // The count below already says every landmark is stamped
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(DS.Palette.accent)
                        .accessibilityHidden(true)
                }
            }
            Text("\(visitedCount) / \(total) stamped")
                .font(.caption)
                .foregroundStyle(.secondary)
                // VoiceOver would read the slash; say it in words instead
                .accessibilityLabel(Text("\(visitedCount) of \(total) landmarks stamped"))
            ProgressView(value: total == 0 ? 0 : Double(visitedCount) / Double(total))
                .tint(DS.Palette.accent)
                .accessibilityHidden(true)   // same number as the text above
        }
        .padding(.vertical, 4)
        // One row reads "Chicago, 3 of 12 landmarks stamped"
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Helpers

/// Landmarks for a city. Used by the Detroit volume and immersive views.
@MainActor
func loadBuildings(for cityName: String) -> [Building] {
    VisionStore.shared.buildings(for: cityName)
}
