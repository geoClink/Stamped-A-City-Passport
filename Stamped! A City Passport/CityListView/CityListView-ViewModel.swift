//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import Foundation
import SwiftUI

// MARK: - MODELS

struct MixedSearchResult: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let city: CityLocation.City
    let isLandmark: Bool
}


// MARK: - VIEW MODEL EXTENSION

/// Everything search can find, lowercased once. Searching used to lowercase (and re-sort)
/// all 1,800+ landmarks on every keystroke, which made typing lag.
private struct SearchIndex {
    struct Place {
        let city: CityLocation.City
        let subtitle: String
        let names: [String]        // name, country and nicknames, lowercased
        let exactNames: Set<String> // name and nicknames: an exact match goes first
    }
    struct Landmark {
        let city: CityLocation.City
        let title: String
        let subtitle: String
        let text: [String]          // name and architect, lowercased
    }

    let places: [Place]
    let landmarks: [Landmark]

    static let shared: SearchIndex = {
        var places: [Place] = []
        var landmarks: [Landmark] = []
        for city in CityLocation.City.allCases {
            let ownNames = ([city.name] + city.searchAliases).map { $0.lowercased() }
            places.append(Place(
                city: city,
                subtitle: city.details.nickname,
                // The country in English and in the app's language, so "Deutschland" finds Berlin too
                names: ownNames + [city.country.rawValue.lowercased(), city.country.localizedName.lowercased()],
                exactNames: Set(ownNames)
            ))
            for building in city.buildings {
                landmarks.append(Landmark(
                    city: city,
                    title: building.name,
                    subtitle: building.knownArchitect.map { "Designed by \($0)" } ?? city.name,
                    text: [building.name.lowercased()] + (building.knownArchitect.map { [$0.lowercased()] } ?? [])
                ))
            }
        }
        return SearchIndex(places: places, landmarks: landmarks)
    }()
}

extension CityViewModel {
    func filteredResults(query: String) -> [MixedSearchResult] {
        let lowerQuery = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !lowerQuery.isEmpty else { return [] }
        let index = SearchIndex.shared

        var exact: [MixedSearchResult] = []
        var others: [MixedSearchResult] = []
        var seenTitles: Set<String> = []

        // Cities and campuses: an exact name or nickname ("UGA", "Ole Miss") goes first,
        // ahead of results that only contain the letters ("Portugal" for "uga")
        for place in index.places where place.names.contains(where: { $0.contains(lowerQuery) }) {
            guard seenTitles.insert(place.city.name).inserted else { continue }
            let result = MixedSearchResult(title: place.city.name, subtitle: place.subtitle, city: place.city, isLandmark: false)
            if place.exactNames.contains(lowerQuery) {
                exact.append(result)
            } else {
                others.append(result)
            }
        }
        for landmark in index.landmarks where landmark.text.contains(where: { $0.contains(lowerQuery) }) {
            guard seenTitles.insert(landmark.title).inserted else { continue }
            others.append(MixedSearchResult(title: landmark.title, subtitle: landmark.subtitle, city: landmark.city, isLandmark: true))
        }
        return exact + others
    }
}

// MARK: - CITY LIST VIEW COMPONENTS

extension CityListView {
    
    // MARK: - Logic & Helpers

    var todaysDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date()).uppercased()
    }
    
    var emptySearchContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "mappin.slash.circle.fill")
                .font(.system(size: 40))
                .accessibleSecondary(isHighContrast: isHighContrast).opacity(0.6)
            Text("No Cities Found")
                .font(.headline)
            Text("Try searching for a different country or city.")
                .font(.subheadline)
                .accessibleSecondary(isHighContrast: isHighContrast)
                 .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .listRowBackground(Color.clear)
    }
    
    func cityCountrySection(country: CityLocation.Country, cities: [CityLocation.City]) -> some View {
        let isExpanded = Binding {
            expandedCountries[country, default: false]
        } set: { newValue in
            if newValue { HapticManager.shared.trigger(.selection) }
            expandedCountries[country] = newValue
        }
        return citySection(
            cities: cities,
            isExpanded: isExpanded,
            header: CountryHeaderLabel(country: country, isMastered: viewModel.isCountryMastered(country), isHighContrast: isHighContrast)
        )
    }

    /// A conference or country group inside "Campus Architecture": it opens and closes
    /// separately from the same country's cities.
    func campusGroupSection(_ group: CampusGroup) -> some View {
        let isExpanded = Binding {
            expandedCampusGroups[group.id, default: false]
        } set: { newValue in
            if newValue { HapticManager.shared.trigger(.selection) }
            expandedCampusGroups[group.id] = newValue
        }
        let isMastered = viewModel.isCampusGroupMastered(group)
        let header: CountryHeaderLabel
        switch group.kind {
        case .country:
            header = CountryHeaderLabel(title: group.title,
                                        congratsMessage: group.campuses.first?.country.congratsMessage ?? "CONGRATULATIONS!",
                                        masterBadge: "COUNTRY MASTER", isMastered: isMastered, isHighContrast: isHighContrast)
        case .conference:
            header = CountryHeaderLabel(title: group.title, congratsMessage: "CONGRATULATIONS!", masterBadge: "CONFERENCE MASTER",
                                        isMastered: isMastered, isHighContrast: isHighContrast)
        }
        return citySection(cities: group.campuses, isExpanded: isExpanded, header: header)
    }

    /// On iPad every group is shown open with a section header; on iPhone it is a disclosure group.
    private func citySection(cities: [CityLocation.City], isExpanded: Binding<Bool>, header: CountryHeaderLabel) -> some View {
        Group {
            if isIPad {
                Section {
                    ForEach(cities) { city in
                        cityRowWrapper(city: city)
                    }
                } header: {
                    header.padding(.vertical, 8)
                }
            } else {
                Section {
                    DisclosureGroup(isExpanded: isExpanded) {
                        ForEach(cities) { city in
                            cityRowWrapper(city: city)
                        }
                    } label: {
                        header
                    }
                }
            }
        }
    }

    private func cityRowWrapper(city: CityLocation.City) -> some View {
        ZStack {
            NavigationLink(value: city) { EmptyView() }.opacity(0)
            CityRow(city: city,
                        isCompleted: viewModel.isCityCompleted(city),
                        isHighContrast: isHighContrast)
        }
        .onTapGesture {
            HapticManager.shared.trigger(.selection)
            selectedCity = city
        }
    }

    var headerSection: some View {
        // One gap everywhere on home: between these blocks and between the list sections
        VStack(spacing: DS.Space.m) {
            quickActions
            collegeListCard
            // The welcome banner stays until the first stamp of any kind, city or campus
            if viewModel.masteredCount + viewModel.masteredCampusCount == 0 {
                ZeroProgressHeader(isHighContrast: isHighContrast)
            } else {
                ProgressHeaderView(viewModel: viewModel, isHighContrast: isHighContrast) {
                    HapticManager.shared.trigger(.selection)
                    showingPassport = true
                }
            }
        }
    }

    /// My Journey, Achievements, World Map and My Trips, each with its name under the icon.
    /// (They used to be four unlabeled icons in the top bar.)
    private var quickActions: some View {
        // Four across, or two by two at the largest text sizes so the labels aren't cut off.
        // A plain Grid: a lazy grid inside a List row keeps its old column widths when text size changes.
        let tiles: [AnyView] = [
            AnyView(quickAction("My Journey", systemImage: "chart.bar.fill") { showingMyJourney = true }),
            AnyView(quickAction("Achievements", systemImage: "trophy.fill") { showingAchievements = true }),
            AnyView(quickAction("World Map", systemImage: "globe") { showingWorldMap = true }),
            AnyView(quickAction("My Trips", systemImage: "suitcase.fill", hint: "Your trips, including New Trip Anywhere") { showingMyTrips = true }),
        ]
        let perRow = dynamicTypeSize.isAccessibilitySize ? 2 : 4
        return Grid(horizontalSpacing: DS.Space.m, verticalSpacing: DS.Space.m) {
            ForEach(Array(stride(from: 0, to: tiles.count, by: perRow)), id: \.self) { start in
                GridRow {
                    ForEach(start..<min(start + perRow, tiles.count), id: \.self) { index in
                        tiles[index]
                    }
                }
            }
        }
    }

    private func quickAction(_ title: LocalizedStringKey, systemImage: String, hint: LocalizedStringKey? = nil,
                             action: @escaping () -> Void) -> some View {
        // Not a Button: inside a List row, every Button in the row fires on any tap,
        // so tapping World Map opened all four screens. A tap gesture on each tile doesn't.
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(brandColor)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: 64)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(isHighContrast ? Color(UIColor.systemBackground) : Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .onTapGesture {
            HapticManager.shared.trigger(.selection)
            action()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
        .accessibilityHint(hint.map { Text($0) } ?? Text(""))
        // Four across stops fitting at the largest text sizes, so these stop growing at XXXL
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    var welcomePlaceholder: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(isHighContrast ? .secondary : Color.adventureOrange.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "map.fill")
                    .font(.system(size: 60))
                    .foregroundColor(isHighContrast ? .primary : Color.adventureOrange.opacity(0.8))
            }
            
            VStack(spacing: 8) {
                Text("Start Exploring")
                    .font(.title2.bold())
                Text("Select a city from the sidebar to view its landmarks and earn your passport stamp.")
                    .font(.body)
                    .accessibleSecondary(isHighContrast: isHighContrast)
                     .multilineTextAlignment(.center)
                     .padding(.horizontal, 40)
            }
        }
    }

    // MARK: - Toolbars
    
    /// Only Settings stays up here; the other screens are labeled tiles at the top of the list.
    var sidebarToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                HapticManager.shared.trigger(.selection)
                showingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .foregroundStyle(isHighContrast ? Color.primary : Color.adventureOrange)
        }
    }
    
    /// Picks sheet or full screen for My Trips, so only one of them is ever shown.
    func myTripsPresented(fullScreen: Bool) -> Binding<Bool> {
        Binding(
            get: { showingMyTrips && isIPad == fullScreen },
            set: { showingMyTrips = $0 }
        )
    }

    var detailToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if isIPad && columnVisibility == .detailOnly {
                Button {
                    HapticManager.shared.trigger(.selection)
                    withAnimation(.spring()) { columnVisibility = .all }
                } label: {
                    Label("Show Sidebar", systemImage: "sidebar.left")
                }
            }
        }
    }

    // MARK: - Buttons & Overlays

    /// Every stamp in the passport: completed cities plus completed campuses
    private var passportStampCount: Int { viewModel.masteredCount + viewModel.masteredCampusCount }

    var passportFloatingButton: some View {
        Button(action: {
            HapticManager.shared.trigger(.selection)
            showingPassport = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: passportStampCount > 0 ? "book.pages.fill" : "book.closed.fill")
                Text("My Passport").fontWeight(.bold)
                Text("\(passportStampCount)")
                    .font(.caption2.bold())
                    .padding(6)
                    .background(isHighContrast ? Color(UIColor.systemBackground) : .white.opacity(0.2))
                    .foregroundColor(isHighContrast ? .primary : .white)
                    .clipShape(Circle())
            }
            .padding(.vertical, isIPad ? 18 : 14)
            .padding(.horizontal, isIPad ? 32 : 24)
            .background(isHighContrast ? Color.primary : Color.adventureOrange)
            .foregroundColor(isHighContrast ? Color(UIColor.systemBackground) : .white)
            .cornerRadius(isHighContrast ? 4 : 30)
            .overlay(
                RoundedRectangle(cornerRadius: isHighContrast ? 4 : 30)
                    .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
            )
        }
        #if os(macOS)
        // Without this the Mac draws its gray push-button bezel around the orange capsule
        .buttonStyle(.plain)
        #endif
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }
    @ViewBuilder
    var onboardingOverlay: some View {
        if !hasSeenPassportHint {
            PassportHintOverlayView(
                isHighContrast: isHighContrast,
                hasSeenHint: $hasSeenPassportHint,
                selectedCity: $selectedCity,
                viewModel: viewModel,
                expandedContinents: $expandedContinents,
                expandedCountries: $expandedCountries
            )
            .transition(.opacity.combined(with: .scale(scale: 1.1)))
        }
    }
    
    private func collapseAll() {
        HapticManager.shared.trigger(.impact)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            for key in expandedContinents.keys { expandedContinents[key] = false }
            for key in expandedCountries.keys { expandedCountries[key] = false }
            for key in expandedCampusGroups.keys { expandedCampusGroups[key] = false }
            isCampusSectionExpanded = false
        }
    }
}

// MARK: - SUPPORTING VIEWS

struct CountryHeaderLabel: View {
    let title: String
    let congratsMessage: String
    let masterBadge: LocalizedStringKey
    let isMastered: Bool
    let isHighContrast: Bool
    @Environment(\.colorScheme) var colorScheme

    init(country: CityLocation.Country, isMastered: Bool, isHighContrast: Bool) {
        self.init(title: country.localizedName.localizedUppercase, congratsMessage: country.congratsMessage,
                  masterBadge: "COUNTRY MASTER", isMastered: isMastered, isHighContrast: isHighContrast)
    }

    /// Also used for the conference groups inside "Campus Architecture".
    init(title: String, congratsMessage: String, masterBadge: LocalizedStringKey, isMastered: Bool, isHighContrast: Bool) {
        self.title = title
        self.congratsMessage = congratsMessage
        self.masterBadge = masterBadge
        self.isMastered = isMastered
        self.isHighContrast = isHighContrast
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isMastered {
                Text(congratsMessage)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(isHighContrast ? .primary : .adventureOrange)
                    .tracking(1)
            }
            
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isHighContrast ? .black : .bold)
                    .foregroundColor(headerColor)
                
                if isMastered {
                    Image(systemName: "trophy.fill")
                        .font(.caption2)
                        .foregroundColor(isHighContrast ? .primary : Color.adventureOrange)
                }
            }
            
            if isMastered {
                Text(masterBadge)
                    .font(.system(size: 10, weight: .black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isHighContrast ? Color.primary : Color.adventureOrange.opacity(0.15))
                    .foregroundColor(isHighContrast ? Color(UIColor.systemBackground) : Color.adventureOrange)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isHighContrast ? .clear : Color.adventureOrange.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var headerColor: Color {
        // High contrast wins
        if isHighContrast { return .primary }
        // Mastered countries use primary color
        if isMastered { return .primary }
        // In dark mode, system .secondary may be low contrast; use a stronger primary-based color
        if colorScheme == .dark { return Color.primary.opacity(0.88) }
        // Light mode: use nearly full primary to ensure >=4.5:1 contrast against white backgrounds
        return Color.primary.opacity(0.95)
    }
}

struct ZeroProgressHeader: View {
    let isHighContrast: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    private var accent: Color { isHighContrast ? .primary : Color.adventureOrange }
    private var cardBG: Color {
        isHighContrast ? Color(UIColor.systemBackground) : Color(.secondarySystemGroupedBackground)
    }

    // Accessible secondary color: strong enough in light mode to meet contrast requirements,
    // slightly softer in dark mode, and full primary for high-contrast accessibility setting.
    private var accessibleSecondary: Color {
        if isHighContrast { return .primary }
        if colorScheme == .dark { return Color.primary.opacity(0.85) }
        return Color.primary.opacity(0.95)
    }

    /// A slim banner, not a full card: new users should see the cities and campuses
    /// right away, not a screen-sized welcome message.
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(isHighContrast ? 0 : 0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: "building.columns.fill")
                    .font(.title3)
                    .foregroundColor(accent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("YOUR ODYSSEY AWAITS")
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.bold)
                    .tracking(2)
                    .foregroundColor(accessibleSecondary)
                Text("Unlock your first badge")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("Pick a city or campus below, then stamp every landmark.")
                    .font(.footnote)
                    .foregroundColor(accessibleSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .strokeBorder(
                    accent.opacity(isHighContrast ? 1 : 0.4),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                )
        )
        .accessibilityElement(children: .combine)
    }
}

struct ProgressHeaderView: View {
    let viewModel: CityViewModel
    let isHighContrast: Bool
    let action: () -> Void
    
    private var progressRatio: Double {
        guard viewModel.totalCities > 0 else { return 0 }
        return Double(viewModel.masteredCount) / Double(viewModel.totalCities)
    }
    
    private var progressPercentage: Int {
        Int(progressRatio * 100)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WORLD EXPLORER")
                            .font(.system(.caption2, design: .rounded))
                            .fontWeight(.heavy)
                            .tracking(1.5)
                            .foregroundColor(isHighContrast ? .primary : Color.adventureOrange)
                        
                        Text("\(viewModel.masteredCount) of \(viewModel.totalCities) Cities Mastered")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    Text("\(progressPercentage)%")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.15))
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: isHighContrast ? [.primary] : [Color.adventureOrange, .orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(progressRatio))
                                .shadow(color: (isHighContrast ? Color.clear : Color.adventureOrange.opacity(0.4)), radius: 6, x: 0, y: 0)
                        }
                    }
                    .frame(height: 12)
                    
                    if progressPercentage < 100 {
                        HStack {
                            Text("Only: \(viewModel.totalCities - viewModel.masteredCount) more cities")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            // Campus stamps count in the passport too, so say so here
                            if viewModel.masteredCampusCount > 0 {
                                Text(viewModel.masteredCampusCount == 1
                                     ? NSLocalizedString("+ 1 campus", comment: "Home progress card: one completed campus next to the city count")
                                     : String(format: NSLocalizedString("+ %d campuses", comment: "Home progress card: completed campuses next to the city count"), viewModel.masteredCampusCount))
                                    .font(.caption2.bold())
                                    .foregroundColor(isHighContrast ? .primary : .adventureOrange)
                            }
                            Spacer()
                            Image(systemName: "flag.checkered")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                    } else {
                        Label("Global Master Achieved!", systemImage: "checkmark.seal.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(DS.Space.l)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(isHighContrast ? Color(UIColor.systemBackground) : Color(UIColor.secondarySystemGroupedBackground))
            }
            .overlay {
                if isHighContrast {
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .strokeBorder(.primary, lineWidth: 2)
                }
            }
        }
        .buttonStyle(ScaledButtonStyle())
    }
}
struct ScaledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct CityRow: View {
    let city: CityLocation.City
    let isCompleted: Bool
    let isHighContrast: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    @ScaledMetric(relativeTo: .body) private var stampSize: CGFloat = 44
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.adventureOrange.opacity(0.2) : Color.gray.opacity(0.1))
                
                Text(city.details.airportCode)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(isCompleted ? (isHighContrast ? .primary : Color.adventureOrange) : (isHighContrast ? .primary : (colorScheme == .dark ? Color.primary.opacity(0.85) : Color.primary.opacity(0.95))))
                    .padding(8)
            }
            .frame(minWidth: stampSize, minHeight: stampSize)
            .fixedSize()
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(city.name)
                    .font(.headline)
                Text(city.details.nickname)
                    .font(.caption)
                    .accessibleSecondary(isHighContrast: isHighContrast)
                    .italic()
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .hoverEffect(.highlight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(city.name), \(isCompleted ? "Completed" : "Not visited")")
        .accessibilityHint("Shows architectural details for \(city.name)")
    }
}

struct PassportHintOverlayView: View {
    let isHighContrast: Bool
    @Binding var hasSeenHint: Bool
    @Binding var selectedCity: CityLocation.City?
    @ObservedObject var viewModel: CityViewModel
    @Binding var expandedContinents: [CityLocation.Continent: Bool]
    @Binding var expandedCountries: [CityLocation.Country: Bool]
    
    @Environment(\.horizontalSizeClass) private var horizontalClass
    @Environment(\.verticalSizeClass) private var verticalClass
    
    var body: some View {
        GeometryReader { proxy in
            let isVertical = proxy.size.height > proxy.size.width
            let useWideLayout = horizontalClass == .regular && !isVertical
            
            let modalWidth: CGFloat = {
                if useWideLayout { return 950 }
                if horizontalClass == .regular { return 720 }
                return 550
            }()
            
            ZStack {
                backgroundDimmer
                
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        adaptiveLayout(useWideLayout: useWideLayout)
                    }
                    
                    stickyFooterButton
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(isHighContrast ? 0 : 40)
                .overlay(modalStroke)
                .padding(isHighContrast ? 0 : 20)
                .frame(maxWidth: modalWidth)
                .frame(maxHeight: isVertical ? .infinity : 850)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    @ViewBuilder
    private func adaptiveLayout(useWideLayout: Bool) -> some View {
        if useWideLayout {
            HStack(alignment: .center, spacing: 48) {
                stampView
                    .layoutPriority(1)
                
                VStack(alignment: .leading, spacing: 32) {
                    headerTextSection(isCentered: false)
                    milestoneList
                }
            }
            .padding(48)
        } else {
            VStack(spacing: 40) {
                stampView
                headerTextSection(isCentered: true)
                milestoneList
            }
            .padding(.horizontal, horizontalClass == .regular ? 80 : 24) // More padding for iPad
            .padding(.vertical, 40)
        }
    }

    private func headerTextSection(isCentered: Bool) -> some View {
        VStack(alignment: isCentered ? .center : .leading, spacing: 12) {
            Text("Unlock Your Collection")
                .font(.system(size: horizontalClass == .regular ? 36 : 24, weight: .black, design: .rounded))
                .multilineTextAlignment(isCentered ? .center : .leading)
            
            Text("Every city mastered is a stamp earned.")
                .font(horizontalClass == .regular ? .title2 : .subheadline)
                .foregroundColor(isHighContrast ? .primary : .secondary)
                .multilineTextAlignment(isCentered ? .center : .leading)
        }
    }
    
    private var stampView: some View {
        let isWide = horizontalClass == .regular
        return VStack(spacing: isWide ? 24 : 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: isWide ? 80 : 54))
                .foregroundColor(isHighContrast ? .primary : .adventureOrange)
                .modifier(PulseEffectModifier(isActive: true))

            VStack(spacing: 8) {
                Text("PASSPORT STAMPED")
                    .font(.system(size: isWide ? 14 : 11, weight: .black))
                    .tracking(2)
                    .foregroundColor(isHighContrast ? .primary : .adventureOrange)
                
                Text("SAN FRANCISCO")
                    .font(.system(isWide ? .title : .title2, design: .serif)).bold()
                
                Text("DATE: \(internalDate)")
                    .font(.system(size: isWide ? 14 : 12, weight: .bold, design: .monospaced))
                    .foregroundColor(isHighContrast ? .primary : .secondary)
            }

            VStack(spacing: 6) {
                Text("DID YOU KNOW?")
                    .font(.system(size: isWide ? 12 : 10, weight: .heavy))
                    .foregroundColor(isHighContrast ? .primary : .adventureOrange)
                
                Text("While originally intended only as a protective sealant, the bridge’s signature ‘International Orange’ was made permanent when the architect realized its vibrant hue served as a perfect, high-contrast beacon against the San Francisco fog.")
                    .font(.system(size: isWide ? 15 : 13, design: .serif)).italic()
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
        }
        .padding(isWide ? 44 : 30)
        .frame(width: isWide ? 400 : 300)
        .background(stampBackground)
        .rotationEffect(.degrees(isHighContrast ? 0 : -2.5))
    }

    private var stampBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24).fill(Color(UIColor.systemBackground))
            RoundedRectangle(cornerRadius: 24).strokeBorder(isHighContrast ? Color.primary : Color.adventureOrange.opacity(0.2), lineWidth: 1)
            RoundedRectangle(cornerRadius: 22).strokeBorder(isHighContrast ? Color.primary : Color.adventureOrange, style: StrokeStyle(lineWidth: isHighContrast ? 4 : 3, dash: isHighContrast ? [] : [8, 4])).padding(6)
        }
    }

    private var milestoneList: some View {
        VStack(alignment: .leading, spacing: 24) {
            milestoneRow(icon: "map.fill", title: "Visit Landmarks", detail: "Mark buildings as discovered to reach 100% completion.")
            milestoneRow(icon: "camera.fill", title: "Capture the View", detail: "Add personal photos to create a custom gallery.")
            milestoneRow(icon: "checkmark.seal.fill", title: "Collect the Stamp", detail: "Complete a city to earn its official Passport seal.")
            milestoneRow(icon: "graduationcap.fill", title: "Ace the Quiz", detail: "Score perfectly on the architecture test to show your expertise.")
            milestoneRow(icon: "sparkles", title: "Generate Itinerary", detail: "Instantly create a smart travel plan for any city.")
            milestoneRow(
                    icon: "dollarsign.circle.fill",
                    title: "Convert Currency",
                    detail: "Check exchange rates instantly within the Travel Dossier."
                )
        }
    }

    private var stickyFooterButton: some View {
        Button(action: dismissHint) {
            Text("Unlock My First Stamp")
                .font(.headline.bold())
                .foregroundColor(isHighContrast ? Color(UIColor.systemBackground) : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(isHighContrast ? Color.primary : Color.adventureOrange)
                .cornerRadius(20)
                .padding(.horizontal, horizontalClass == .regular ? 60 : 24)
                .padding(.vertical, 24)
        }
        .background(Color(UIColor.systemBackground).shadow(color: .black.opacity(0.08), radius: 10, y: -5))
    }

    private var internalDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date()).uppercased()
    }

    private func milestoneRow(icon: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 20) {
            ZStack {
                Circle().fill(isHighContrast ? Color.primary : Color.adventureOrange.opacity(0.1)).frame(width: 48, height: 48)
                Image(systemName: icon).font(.system(size: 20, weight: .bold))
                    .foregroundColor(isHighContrast ? Color(UIColor.systemBackground) : Color.adventureOrange)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline.bold())
                Text(detail).font(.footnote).accessibleSecondary(isHighContrast: isHighContrast)
                     .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private var backgroundDimmer: some View {
        Group {
            if isHighContrast { Color.black }
            else { Color.black.opacity(0.45).background(.ultraThinMaterial) }
        }
        .ignoresSafeArea()
        .onTapGesture { dismissHint() }
    }

    private var modalStroke: some View {
        RoundedRectangle(cornerRadius: isHighContrast ? 0 : 40)
            .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 4)
    }

    private func dismissHint() {
        HapticManager.shared.trigger(.heavy)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            hasSeenHint = true
            // Do not auto-select San Francisco on first-run. Instead, leave the detail pane showing the
            // ZeroProgressHeader / "Unlock your first badge" placeholder so users can begin there.
            selectedCity = nil
            // Keep continent and country expansion state unchanged so the sidebar remains as the user left it.
        }
    }
}

// Small helper modifier to apply an accessible 'secondary' color that adapts to dark mode and high-contrast
private struct AccessibleSecondary: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let isHighContrast: Bool
    func body(content: Content) -> some View {
        let c: Color
        if isHighContrast { c = .primary }
        else if colorScheme == .dark { c = Color.primary.opacity(0.85) }
        else { c = Color.primary.opacity(0.95) }
        return content.foregroundColor(c)
    }
}

private extension View {
    func accessibleSecondary(isHighContrast: Bool) -> some View {
        modifier(AccessibleSecondary(isHighContrast: isHighContrast))
    }
}
