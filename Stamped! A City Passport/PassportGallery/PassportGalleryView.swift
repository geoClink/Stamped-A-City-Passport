//
//  PassportGalleryView.swift
//  Stamped
//
//  Created by George Clinkscales on 2/7/26.
//


import SwiftUI

struct PassportGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Settings & Data
    @AppStorage("reduce_motion") var reduceMotion = false
    @AppStorage("high_contrast_mode") var highContrast = false
    @AppStorage("haptics_enabled") var hapticsEnabled = true
    @ObservedObject var progressManager = GlobalProgressManager.shared
    
    let cities: [CityLocation.City]
    @State private var selectedCity: CityLocation.City?
    @State private var selectedCountry: CityLocation.Country?
    @State private var showingShareCard = false
    /// iPad: the Campuses entry in the sidebar is showing instead of a country
    @State private var showingCampusPage = false
    /// Filters the stamps by city or country name
    @State private var searchText = ""

    /// Decorative icons scale with the text around them
    @ScaledMetric(relativeTo: .largeTitle) private var trophySize: CGFloat = 70
    @ScaledMetric(relativeTo: .largeTitle) private var emptyIconSize: CGFloat = 80
    
    // MARK: - Platform Detection & Adaptive Colors
    private var isIPad: Bool { DeviceInfo.isLargeScreen }
    
    private var brandColor: Color {
        if highContrast {
            return colorScheme == .dark ? .white : .black
        }
        return DS.Palette.accent
    }
    
    /// Gold is for mastery only: a country with every city stamped
    private var masteryColor: Color { highContrast ? brandColor : DS.Palette.gold }

    var body: some View {
        Group {
            if isIPad {
                NavigationSplitView {
                    sidebarList
                        .navigationTitle("Countries")
                        .searchable(text: $searchText, placement: .sidebar, prompt: searchPrompt)
                        .background(brandColor.opacity(highContrast ? 0 : 0.03))
                } detail: {
                    if showingCampusPage {
                        ScrollView { campusSection(columns: [GridItem(.adaptive(minimum: 220))]).padding(DS.Space.section) }
                            .background(pageBackground)
                    } else if let country = selectedCountry {
                        passportPage(for: country)
                    } else {
                        emptyBookState
                    }
                }
                .onAppear {
                    if selectedCountry == nil {
                        selectedCountry = sortedCountries.first
                    }
                }
            } else {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: DS.Space.section) {
                            if isSearching {
                                if !hasSearchResults { noResultsState }
                            } else {
                                passportHeader
                            }
                            // Campuses first: the countries below are mostly locked cities
                            campusSection(columns: stampColumns)
                            countryGridSection
                        }
                        .dsPageMargin()
                        .padding(.vertical, DS.Space.l)
                    }
                    #if os(macOS)
                    .searchable(text: $searchText, prompt: searchPrompt)
                    #else
                    .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: searchPrompt)
                    #endif
                    .navigationTitle("Your Passport")
                    .navigationBarTitleDisplayMode(.inline)
                    .background(pageBackground)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                showingShareCard = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(brandColor)
                            }
                            .accessibilityLabel("Share Passport")
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { dismiss() }
                                .fontWeight(highContrast ? .black : .bold)
                                .foregroundColor(brandColor)
                        }
                    }
                    .sheet(isPresented: $showingShareCard) { PassportShareCardView() }
                }
            }
        }
        .accentColor(brandColor)
        .sheet(item: $selectedCity) { city in
            ZoomedStampView(city: city, passedHighContrast: highContrast)
        }
    }
}

// MARK: - Layout
private extension PassportGalleryView {
    var pageBackground: Color {
        highContrast ? (colorScheme == .dark ? .black : .white) : DS.Palette.pageBackground
    }

    /// Two stamps per row on iPhone
    var stampColumns: [GridItem] {
        [GridItem(.flexible(), spacing: DS.Space.m), GridItem(.flexible(), spacing: DS.Space.m)]
    }
}

// MARK: - iPad Sidebar & Page Views
private extension PassportGalleryView {
    var sidebarList: some View {
        List(selection: $selectedCountry) {
            Section {
                ForEach(visibleCountries, id: \.self) { country in
                    countryRow(country)
                }
            }
            if !allCampuses.isEmpty && (!isSearching || !campusesToShow.isEmpty) {
                Section {
                    Button {
                        selectedCountry = nil
                        showingCampusPage = true
                    } label: {
                        HStack {
                            Text(NSLocalizedString("CAMPUSES", comment: "Passport: section of campus stamps"))
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(highContrast ? .black : .bold)
                            Spacer()
                            Text("\(stampedCampuses.count)/\(allCampuses.count)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(showingCampusPage ? brandColor.opacity(0.1) : Color.clear)
                }
            }
        }
        .onChange(of: selectedCountry) { _, country in
            if country != nil { showingCampusPage = false }
        }
    }

    func countryRow(_ country: CityLocation.Country) -> some View {
            NavigationLink(value: country) {
                HStack {
                    Text(country.localizedName.localizedUppercase)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(highContrast ? .black : .bold)
                    Spacer()
                    if isCountryComplete(country) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(masteryColor)
                    }
                }
            }
            .listRowBackground(selectedCountry == country ? brandColor.opacity(0.1) : Color.clear)
    }
    
    func passportPage(for country: CityLocation.Country) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.section) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        Text("JOURNEY LOG")
                            .font(.caption2.monospaced().bold())
                            .foregroundColor(brandColor)
                            .tracking(2)
                        
                        // Shrinks rather than breaking a long name mid-word
                        Text(country.localizedName.localizedUppercase)
                            .font(.system(.largeTitle, design: .serif).weight(.black))
                            .foregroundColor(brandColor)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                    }
                    Spacer(minLength: DS.Space.l)
                    if isCountryComplete(country) {
                        Image(systemName: "trophy.circle.fill")
                            .font(.system(size: trophySize))
                            .foregroundColor(masteryColor)
                    }
                }
                
                Capsule()
                    .fill(brandColor)
                    .frame(height: 4)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: DS.Space.xl)], spacing: DS.Space.xl) {
                    let countryCities = visibleCities(in: country)
                    ForEach(countryCities) { city in
                        if isCityCompleted(city) {
                            MiniPassportStamp(city: city, highContrast: highContrast)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if hapticsEnabled { HapticManager.shared.trigger(.selection) }
                                    selectedCity = city
                                }
                        } else {
                            LockedStampView(cityName: city.name, isHighContrast: highContrast)
                        }
                    }
                }
            }
            .padding(DS.Space.section)
        }
        .background(pageBackground)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .fontWeight(highContrast ? .black : .bold)
                    .foregroundColor(brandColor)
            }
        }
    }
    
    /// Shown when the search matches no city, country or campus
    var noResultsState: some View {
        VStack(spacing: DS.Space.m) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(String(format: NSLocalizedString("No stamps match \u{201C}%@\u{201D}", comment: "Passport search: nothing matches, e.g. No stamps match “Paris”"), searchQuery))
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Space.section)
    }

    var emptyBookState: some View {
        VStack(spacing: DS.Space.xl) {
            Image(systemName: "map.fill")
                .font(.system(size: emptyIconSize))
                .foregroundStyle(brandColor)
            Text("Select a country to view your stamps")
                .font(.title2.bold())
                .foregroundColor(highContrast ? brandColor : .secondary)
                .multilineTextAlignment(.center)
        }
        .padding(DS.Space.section)
    }
}

// MARK: - iPhone Header & Sections
private extension PassportGalleryView {
    var passportHeader: some View {
        VStack(spacing: DS.Space.l) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text("EXPLORATION PROGRESS")
                        .font(.caption2.monospaced().weight(.black))
                        .tracking(1)
                        .foregroundColor(highContrast ? brandColor : .white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Text(String(format: NSLocalizedString("%d Cities Stamped", comment: "Passport header: completed cities"), completedCount))
                        .font(.title2.bold())
                        .foregroundColor(highContrast ? brandColor : .white)
                    if !allCampuses.isEmpty {
                        Text(String(format: NSLocalizedString("%d of %d campuses", comment: "Passport header: completed campuses, e.g. 2 of 101 campuses"), stampedCampuses.count, allCampuses.count))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(highContrast ? brandColor : .white.opacity(0.85))
                    }
                }
                Spacer(minLength: DS.Space.s)
                Image(systemName: "globe.americas.fill")
                    .font(.largeTitle)
                    .foregroundColor(highContrast ? brandColor : .white.opacity(0.5))
                    .accessibilityHidden(true)
            }
            
            ProgressView(value: Double(completedCount), total: Double(max(cityCount, 1)))
                .tint(highContrast ? brandColor : .white)
                .background(highContrast ? brandColor.opacity(0.2) : Color.black.opacity(0.1))
                .scaleEffect(x: 1, y: 2.5)
                .clipShape(Capsule())
        }
        .padding(DS.Space.xl)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(highContrast ? (colorScheme == .dark ? Color.black : Color.white) : DS.Palette.accent)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(highContrast ? brandColor : Color.clear, lineWidth: 2)
        )
    }

    var countryGridSection: some View {
        ForEach(visibleCountries, id: \.self) { country in
            VStack(alignment: .leading, spacing: DS.Space.m) {
                // One line, shrinking to fit, so long names like ARGENTINA never break mid-word.
                // Country names aren't translated, so the key just shows as written.
                DSSectionHeader(title: LocalizedStringKey(country.localizedName), isHighContrast: highContrast) {
                    if isCountryComplete(country) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(masteryColor)
                    }
                }
                
                LazyVGrid(columns: stampColumns, spacing: DS.Space.m) {
                    let countryCities = visibleCities(in: country)
                    ForEach(countryCities) { city in
                        if isCityCompleted(city) {
                            MiniPassportStamp(city: city, highContrast: highContrast)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if hapticsEnabled { HapticManager.shared.trigger(.selection) }
                                    selectedCity = city
                                }
                        } else {
                            LockedStampView(cityName: city.name, isHighContrast: highContrast)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Campus stamps
private extension PassportGalleryView {
    /// Stamped campuses in school colors. Locked campuses aren't listed (there are 101);
    /// the count says how many are left.
    @ViewBuilder
    func campusSection(columns: [GridItem]) -> some View {
        if isSearching {
            // A search lists matching campuses, locked ones too, so a school is easy to find
            if !campusesToShow.isEmpty {
                VStack(alignment: .leading, spacing: DS.Space.m) {
                    DSSectionHeader(title: "CAMPUSES", systemImage: "graduationcap.fill", isHighContrast: highContrast) { EmptyView() }
                    LazyVGrid(columns: columns, spacing: DS.Space.m) {
                        ForEach(campusesToShow) { campus in
                            if isCityCompleted(campus) {
                                MiniPassportStamp(city: campus, highContrast: highContrast)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if hapticsEnabled { HapticManager.shared.trigger(.selection) }
                                        selectedCity = campus
                                    }
                            } else {
                                LockedStampView(cityName: campus.name, isHighContrast: highContrast)
                            }
                        }
                    }
                }
            }
        } else {
            allCampusesSection(columns: columns)
        }
    }

    func allCampusesSection(columns: [GridItem]) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader(title: "CAMPUSES", systemImage: "graduationcap.fill", isHighContrast: highContrast) {
                Text("\(stampedCampuses.count)/\(allCampuses.count)")
                    .font(.caption.monospaced().bold())
                    .foregroundColor(brandColor)
            }
            if stampedCampuses.isEmpty {
                Text(NSLocalizedString("Stamp every landmark on a campus to add its stamp here, in school colors.", comment: "Passport: empty campus section"))
                    .font(.subheadline)
                    .foregroundColor(highContrast ? brandColor : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVGrid(columns: columns, spacing: DS.Space.m) {
                    ForEach(stampedCampuses) { campus in
                        MiniPassportStamp(city: campus, highContrast: highContrast)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if hapticsEnabled { HapticManager.shared.trigger(.selection) }
                                selectedCity = campus
                            }
                    }
                }
            }
        }
    }
}

// MARK: - Logic Helpers
extension PassportGalleryView {
    /// Real cities by country; campuses get their own section, not a country page
    var groupedCities: [CityLocation.Country: [CityLocation.City]] {
        Dictionary(grouping: cities.filter { !$0.isCampus }, by: { $0.country })
    }

    var allCampuses: [CityLocation.City] { cities.filter(\.isCampus) }

    /// Campuses with a stamp, sorted like the campus list
    var stampedCampuses: [CityLocation.City] {
        allCampuses.filter { isCityCompleted($0) }.sorted { $0.campusSortName < $1.campusSortName }
    }
    
    var sortedCountries: [CityLocation.Country] {
        groupedCities.keys.sorted { $0.localizedName.localizedStandardCompare($1.localizedName) == .orderedAscending }
    }
    
    var searchPrompt: String {
        NSLocalizedString("Search cities or countries", comment: "Passport: search field prompt")
    }

    var searchQuery: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isSearching: Bool { !searchQuery.isEmpty }

    /// A city matches by its own name or its country's
    func matchesSearch(_ city: CityLocation.City) -> Bool {
        !isSearching
            || city.name.localizedCaseInsensitiveContains(searchQuery)
            || city.country.localizedName.localizedCaseInsensitiveContains(searchQuery)
    }

    func visibleCities(in country: CityLocation.Country) -> [CityLocation.City] {
        (groupedCities[country] ?? []).filter(matchesSearch)
    }

    var visibleCountries: [CityLocation.Country] {
        sortedCountries.filter { !visibleCities(in: $0).isEmpty }
    }

    /// While searching: every matching campus, stamped or not
    var campusesToShow: [CityLocation.City] {
        allCampuses.filter(matchesSearch).sorted { $0.campusSortName < $1.campusSortName }
    }

    var hasSearchResults: Bool { !visibleCountries.isEmpty || !campusesToShow.isEmpty }

    var completedCount: Int {
        cities.filter { !$0.isCampus && isCityCompleted($0) }.count
    }

    var cityCount: Int { cities.filter { !$0.isCampus }.count }
    
    func isCityCompleted(_ city: CityLocation.City) -> Bool {
        return !city.buildings.isEmpty && city.buildings.allSatisfy { progressManager.visitedIDs.contains($0.id) }
    }

    func isCountryComplete(_ country: CityLocation.Country) -> Bool {
        let citiesInCountry = groupedCities[country] ?? []
        return !citiesInCountry.isEmpty && citiesInCountry.allSatisfy { isCityCompleted($0) }
    }
}

// MARK: - SHARED COMPONENTS
struct MiniPassportStamp: View {
    let city: CityLocation.City
    let highContrast: Bool
    @Environment(\.colorScheme) var colorScheme
    @ScaledMetric(relativeTo: .title) private var sealSize: CGFloat = 40
    
    var body: some View {
        // Campus stamps use the school's color, like the full stamp
        let accent: Color = highContrast
            ? (colorScheme == .dark ? .white : .black)
            : (city.stampColor(darkMode: colorScheme == .dark) ?? DS.Palette.accent)
        let textColor: Color = highContrast ? (colorScheme == .dark ? .white : .black) : .primary

        VStack(spacing: DS.Space.s) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: sealSize))
                .foregroundColor(accent)
            // Serif like the full stamp; shrinks rather than breaking a name mid-word
            Text(city.name.uppercased())
                .font(.system(.caption, design: .serif).weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundColor(textColor)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Space.l)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                .fill(highContrast && colorScheme == .dark ? Color.black : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                .stroke(accent, lineWidth: highContrast ? 3 : 1.5)
        )
        .rotationEffect(.degrees(highContrast ? 0 : -2))
    }
}

/// A city not stamped yet: an empty dashed outline with the name, so a page of
/// mostly locked cities reads as blank pages waiting for ink, not a wall of gray boxes.
struct LockedStampView: View {
    let cityName: String
    let isHighContrast: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let fgColor: Color = isHighContrast ? (colorScheme == .dark ? .white : .black) : .secondary

        VStack(spacing: DS.Space.xs) {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundColor(fgColor.opacity(isHighContrast ? 1.0 : 0.5))
            // Shrinks to fit rather than breaking a name mid-word ("COPEN-HAGEN")
            Text(cityName.uppercased())
                .font(.system(.caption, design: .serif).weight(.semibold))
                .foregroundColor(fgColor.opacity(isHighContrast ? 1.0 : 0.8))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Space.l)
        // High contrast keeps a solid border; otherwise a light dashed one
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                .strokeBorder(
                    isHighContrast ? fgColor : Color.primary.opacity(0.15),
                    style: StrokeStyle(lineWidth: isHighContrast ? 2 : 1, dash: isHighContrast ? [] : [4, 3])
                )
        )
    }
}

struct ZoomedStampView: View {
    let city: CityLocation.City
    let passedHighContrast: Bool
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let adaptiveBg = passedHighContrast ? (colorScheme == .dark ? Color.black : Color.white) : Color(.systemBackground)
        let adaptiveFg = passedHighContrast ? (colorScheme == .dark ? Color.white : Color.black) : DS.Palette.accent

        NavigationStack {
            ZStack {
                adaptiveBg.ignoresSafeArea()
                
                VStack {
                    Spacer()
                    PassportStampView(
                        cityName: city.name,
                        dateCompleted: "OFFICIAL",
                        funFact: city.details.funFact,
                        isHighContrast: passedHighContrast
                    )
                    .padding(DS.Space.l)
                    Spacer()
                }
            }
            .navigationTitle(city.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                        .fontWeight(passedHighContrast ? .black : .bold)
                        .foregroundColor(adaptiveFg)
                }
            }
            .toolbarBackground(adaptiveBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
