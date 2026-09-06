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

extension CityViewModel {
    func filteredResults(query: String) -> [MixedSearchResult] {
        guard !query.isEmpty else { return [] }
        let lowerQuery = query.lowercased()
        var results: [MixedSearchResult] = []
        
        for city in allCities {
            // 1. Still check City Names
            if city.name.lowercased().contains(lowerQuery) {
                results.append(MixedSearchResult(title: city.name, subtitle: city.details.nickname, city: city, isLandmark: false))
            }
            
            for building in city.buildings {
                let architectMatch = building.architect.lowercased().contains(lowerQuery)
                let buildingMatch = building.name.lowercased().contains(lowerQuery)
                
                if buildingMatch || architectMatch {
                    results.append(MixedSearchResult(
                        title: building.name,
                        subtitle: "Designed by \(building.architect)",
                        city: city,
                        isLandmark: true
                    ))
                }
            }
        }
        return results.reduce(into: [MixedSearchResult]()) { current, next in
            if !current.contains(where: { $0.title == next.title }) {
                current.append(next)
            }
        }
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
    
    // MARK: - Main Content
    
    var mainListContent: some View {
        
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
                                        .accessibleSecondary(isHighContrast: isHighContrast)
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
            passportFloatingButton
                .background(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color(UIColor.systemBackground).opacity(0.8), location: 0.4),
                            .init(color: Color(UIColor.systemBackground), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
        }
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
        let isMastered = viewModel.isCountryMastered(country)
        
        return Group {
            if isIPad {
                Section {
                    ForEach(cities) { city in
                        cityRowWrapper(city: city)
                    }
                } header: {
                    CountryHeaderLabel(country: country, isMastered: isMastered, isHighContrast: isHighContrast)
                        .padding(.vertical, 8)
                }
            } else {
                let isExpanded = Binding {
                    expandedCountries[country, default: false]
                } set: { newValue in
                    if newValue { HapticManager.shared.trigger(.selection) }
                    expandedCountries[country] = newValue
                }

                Section {
                    DisclosureGroup(isExpanded: isExpanded) {
                        ForEach(cities) { city in
                            cityRowWrapper(city: city)
                        }
                    } label: {
                        CountryHeaderLabel(country: country, isMastered: isMastered, isHighContrast: isHighContrast)
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
        Group {
            if viewModel.masteredCount == 0 {
                ZeroProgressHeader(isHighContrast: isHighContrast)
            } else {
                ProgressHeaderView(viewModel: viewModel, isHighContrast: isHighContrast) {
                    HapticManager.shared.trigger(.selection)
                    showingPassport = true
                }
            }
        }
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
    
    var sidebarToolbar: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    HapticManager.shared.trigger(.selection)
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(isHighContrast ? Color.primary : Color.adventureOrange)
                }
                .accessibilityLabel("Settings")
            }

            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    HapticManager.shared.trigger(.selection)
                    showingMyJourney = true
                } label: {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(isHighContrast ? Color.primary : Color.adventureOrange)
                }
                .accessibilityLabel("My Journey")
                .accessibilityHint("Shows your overall stamp stats and progress")
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                ControlGroup {
                    Button(action: collapseAll) {
                        Label("Collapse All", systemImage: "rectangle.stack.badge.minus")
                    }
                    
                    Button {
                        HapticManager.shared.trigger(.selection)
                        withAnimation { hasSeenPassportHint = false }
                    } label: {
                        Label("Tutorial", systemImage: "questionmark.circle")
                    }
                }
                .controlGroupStyle(.navigation) // iPad specific: provides a subtle button container
                .foregroundStyle(isHighContrast ? Color.primary : Color.adventureOrange)
            }
        }
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

    var passportFloatingButton: some View {
        Button(action: {
            HapticManager.shared.trigger(.selection)
            showingPassport = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: viewModel.masteredCount > 0 ? "book.pages.fill" : "book.closed.fill")
                Text("My Passport").fontWeight(.bold)
                Text("\(viewModel.masteredCount)")
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
        }
    }
}

// MARK: - SUPPORTING VIEWS

struct CountryHeaderLabel: View {
    let country: CityLocation.Country
    let isMastered: Bool
    let isHighContrast: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isMastered {
                Text(country.congratsMessage)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(isHighContrast ? .primary : .adventureOrange)
                    .tracking(1)
            }
            
            HStack(alignment: .center, spacing: 8) {
                Text(country.rawValue.uppercased())
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
                Text("COUNTRY MASTER")
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

    var body: some View {
        VStack(spacing: 20) {
            // MARK: - Iconic Seal
            ZStack {
                Circle()
                    .fill(accent.opacity(isHighContrast ? 0 : 0.1))
                    .frame(width: 80, height: 80)
                
                Circle()
                    .strokeBorder(accent.opacity(0.2), lineWidth: 2)
                    .frame(width: 68, height: 68)
                
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 32))
                    .foregroundColor(accent)
            }
            .padding(.top, 4)

            // MARK: - Text Content
            VStack(spacing: 8) {
                Text("YOUR ODYSSEY AWAITS")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .tracking(3)
                    .foregroundColor(accessibleSecondary)
                
                Text("Unlock your first badge")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
            }

            // MARK: - Body Text
            Text("Master a city by visiting all of its landmarks to earn your first official ink-pressed stamp.")
                .font(.subheadline)
                .foregroundColor(accessibleSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 10)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(cardBG)
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(
                    accent.opacity(isHighContrast ? 1 : 0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
        )
        .shadow(color: Color.black.opacity(isHighContrast ? 0 : 0.06), radius: 20, y: 10)
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
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isHighContrast ? Color(UIColor.systemBackground) : Color(UIColor.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
            }
            .overlay {
                if isHighContrast {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
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

    private func milestoneRow(icon: String, title: String, detail: String) -> some View {
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
