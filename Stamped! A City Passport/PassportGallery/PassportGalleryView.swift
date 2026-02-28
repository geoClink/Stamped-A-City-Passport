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
    
    // MARK: - Platform Detection & Adaptive Colors
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    
    private var brandColor: Color {
        if highContrast {
            return colorScheme == .dark ? .white : .black
        }
        return Color.adventureOrange
    }
    
    private var brandGradient: LinearGradient {
        LinearGradient(
            colors: [brandColor, highContrast ? brandColor : Color.orange.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Group {
            if isIPad {
                NavigationSplitView {
                    sidebarList
                        .navigationTitle("Countries")
                        .background(brandColor.opacity(highContrast ? 0 : 0.03))
                } detail: {
                    if let country = selectedCountry {
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
                        VStack(spacing: 25) {
                            passportHeader
                            countryGridSection
                        }
                        .padding()
                    }
                    .navigationTitle("Your Passport")
                    .navigationBarTitleDisplayMode(.inline)
                    .background(highContrast ? (colorScheme == .dark ? .black : .white) : Color.adventureOrange.opacity(0.02))
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { dismiss() }
                                .fontWeight(highContrast ? .black : .bold)
                                .foregroundColor(brandColor)
                        }
                    }
                }
            }
        }
        .accentColor(brandColor)
        .sheet(item: $selectedCity) { city in
            ZoomedStampView(city: city, passedHighContrast: highContrast)
        }
    }
}

// MARK: - iPad Sidebar & Page Views
private extension PassportGalleryView {
    var sidebarList: some View {
        List(sortedCountries, id: \.self, selection: $selectedCountry) { country in
            NavigationLink(value: country) {
                HStack {
                    Text(country.rawValue.uppercased())
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(highContrast ? .black : .bold)
                    Spacer()
                    if isCountryComplete(country) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(brandColor)
                    }
                }
            }
            .listRowBackground(selectedCountry == country ? brandColor.opacity(0.1) : Color.clear)
        }
    }
    
    func passportPage(for country: CityLocation.Country) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("JOURNEY LOG")
                            .font(.caption2.bold())
                            .foregroundColor(highContrast ? brandColor : Color.adventureOrange)
                            .tracking(2)
                        
                        Text(country.rawValue.uppercased())
                            .font(.system(size: 48, weight: .black, design: .serif))
                            .foregroundColor(brandColor)
                    }
                    Spacer()
                    if isCountryComplete(country) {
                        Image(systemName: "trophy.circle.fill")
                            .font(.system(size: 70))
                            .foregroundColor(brandColor)
                    }
                }
                
                Rectangle()
                    .fill(brandColor)
                    .frame(height: 4)
                    .cornerRadius(2)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], spacing: 30) {
                    let countryCities = groupedCities[country] ?? []
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
            .padding(40)
        }
        .background(highContrast ? (colorScheme == .dark ? (Color.black) : (Color.white)) : Color(.systemBackground))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .fontWeight(highContrast ? .black : .bold)
                    .foregroundColor(brandColor)
            }
        }
    }
    
    var emptyBookState: some View {
        VStack(spacing: 20) {
            Image(systemName: "map.fill")
                .font(.system(size: 80))
                .foregroundStyle(brandGradient)
            Text("Select a country to view your stamps")
                .font(.title2.bold())
                .foregroundColor(highContrast ? brandColor : .secondary)
        }
    }
}

// MARK: - iPhone Header & Sections
private extension PassportGalleryView {
    var passportHeader: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("EXPLORATION PROGRESS")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(highContrast ? brandColor : .white.opacity(0.8))
                    
                    Text("\(completedCount) Cities Stamped")
                        .font(.title2.bold())
                        .foregroundColor(highContrast ? brandColor : .white)
                }
                Spacer()
                Image(systemName: "globe.americas.fill")
                    .font(.largeTitle)
                    .foregroundColor(highContrast ? brandColor : .white.opacity(0.5))
            }
            
            ProgressView(value: Double(completedCount), total: Double(cities.count))
                .tint(highContrast ? brandColor : .white)
                .background(highContrast ? brandColor.opacity(0.2) : Color.black.opacity(0.1))
                .scaleEffect(x: 1, y: 2.5)
                .cornerRadius(4)
        }
        .padding(20)
        .background(highContrast ? (colorScheme == .dark ? Color.black : Color.white) : Color.adventureOrange)
        .cornerRadius(20)
        .shadow(color: brandColor.opacity(0.3), radius: 10, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(brandColor, lineWidth: 2)
        )
    }

    var countryGridSection: some View {
        ForEach(sortedCountries, id: \.self) { country in
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text(country.rawValue.uppercased())
                        .font(.headline.bold())
                        .foregroundColor(brandColor)
                    
                    Rectangle()
                        .fill(brandColor.opacity(0.3))
                        .frame(height: 1)
                }
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    let countryCities = groupedCities[country] ?? []
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
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Logic Helpers
extension PassportGalleryView {
    var groupedCities: [CityLocation.Country: [CityLocation.City]] {
        Dictionary(grouping: cities, by: { $0.country })
    }
    
    var sortedCountries: [CityLocation.Country] {
        groupedCities.keys.sorted { $0.rawValue < $1.rawValue }
    }
    
    var completedCount: Int {
        cities.filter { isCityCompleted($0) }.count
    }
    
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
    
    var body: some View {
        let accent: Color = highContrast ? (colorScheme == .dark ? .white : .black) : Color.adventureOrange
        let textColor: Color = highContrast ? (colorScheme == .dark ? .white : .black) : .primary

        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundColor(accent)
            Text(city.name.uppercased())
                .font(.caption.bold())
                .multilineTextAlignment(.center)
                .foregroundColor(textColor)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(highContrast && colorScheme == .dark ? Color.black : Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accent, lineWidth: highContrast ? 3 : 1.5)
        )
        .rotationEffect(.degrees(highContrast ? 0 : -2))
    }
}

struct LockedStampView: View {
    let cityName: String
    let isHighContrast: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let fgColor: Color = isHighContrast ? (colorScheme == .dark ? .white : .black) : .secondary
        let bgColor: Color = isHighContrast ? (colorScheme == .dark ? .black : .white) : Color(.systemGroupedBackground)

        VStack {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundColor(fgColor.opacity(isHighContrast ? 1.0 : 0.4))
            Text(cityName.uppercased())
                .font(.caption.bold())
                .foregroundColor(fgColor.opacity(isHighContrast ? 1.0 : 0.6))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(bgColor))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHighContrast ? fgColor : Color.clear, lineWidth: 2)
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
        let adaptiveFg = passedHighContrast ? (colorScheme == .dark ? Color.white : Color.black) : Color.adventureOrange

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
                    .padding()
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
