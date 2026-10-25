//
//  MyJourneyView.swift
//  Stamped! A City Passport
//
//  Global stats screen — total stamps, cities, architects, and activity history.
//

import SwiftUI

struct MyJourneyView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var progress = GlobalProgressManager.shared

    // CityViewModel provides the full city + building catalogue
    @StateObject private var cityVM = CityViewModel()

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("high_contrast_mode") private var isHighContrast = false
    @ScaledMetric(relativeTo: .largeTitle) private var ringSize: CGFloat = 140
    @ScaledMetric(relativeTo: .title2) private var architectIconSize: CGFloat = 56
    @ScaledMetric(relativeTo: .title3) private var milestoneIconWidth: CGFloat = 28

    private var allBuildings: [Building] { cityVM.allCities.flatMap { $0.buildings } }
    private var visitedIDs: Set<String> { progress.visitedIDs }

    // MARK: - Computed stats

    private var totalStamped: Int { visitedIDs.count }
    private var totalBuildings: Int { allBuildings.count }
    private var completionPercent: Int {
        guard totalBuildings > 0 else { return 0 }
        return Int((Double(totalStamped) / Double(totalBuildings)) * 100)
    }

    // Real cities only, so campuses don't count as "cities" (they have their own collection)
    private var citiesStarted: Int {
        CityLocation.City.cityCases.filter { city in
            city.buildings.contains { visitedIDs.contains($0.id) }
        }.count
    }

    private var citiesCompleted: Int {
        CityLocation.City.cityCases.filter { city in
            city.buildings.allSatisfy { visitedIDs.contains($0.id) }
        }.count
    }

    private var countriesVisited: Int {
        var countries = Set<String>()
        for group in cityVM.groupedByContinent {
            for countryGroup in group.countries {
                let hasVisit = countryGroup.cities.contains { city in
                    city.buildings.contains { visitedIDs.contains($0.id) }
                }
                if hasVisit { countries.insert(countryGroup.id.rawValue) }
            }
        }
        return countries.count
    }

    private var favoriteArchitect: (name: String, count: Int)? {
        var counts: [String: Int] = [:]
        for building in allBuildings where visitedIDs.contains(building.id) {
            guard let architect = building.knownArchitect else { continue }
            counts[architect, default: 0] += 1
        }
        guard let top = counts.max(by: { $0.value < $1.value }) else { return nil }
        return (top.key, top.value)
    }

    private var firstStampDate: Date? { progress.visitDates.values.min() }

    private var daysActive: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(progress.visitDates.values.map { calendar.startOfDay(for: $0) })
        return uniqueDays.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Space.xl) {
                    heroCard
                    statsGrid
                    if let arch = favoriteArchitect { architectCard(arch) }
                    if let date = firstStampDate { milestonesCard(firstStamp: date) }
                }
                .dsPageMargin()
                .padding(.top, DS.Space.l)
                .padding(.bottom, DS.Space.section)
            }
            .background(DS.Palette.pageBackground)
            .navigationTitle("My Journey")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        // Grows with Dynamic Type but stays inside a phone's width
        let ring = min(ringSize, 220)
        return VStack(spacing: DS.Space.l) {
            ZStack {
                Circle()
                    .stroke(isHighContrast ? Color.primary.opacity(0.25) : DS.Palette.accent.opacity(0.15), lineWidth: 16)
                    .frame(width: ring, height: ring)

                Circle()
                    .trim(from: 0, to: totalBuildings > 0 ? CGFloat(totalStamped) / CGFloat(totalBuildings) : 0)
                    .stroke(isHighContrast ? Color.primary : DS.Palette.accent, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .frame(width: ring, height: ring)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 1.0), value: totalStamped)

                VStack(spacing: 2) {
                    Text("\(totalStamped)")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.black)
                        .foregroundColor(.primary)
                    Text("stamps")
                        .font(.caption)
                        .foregroundColor(isHighContrast ? .primary : .secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, DS.Space.l + DS.Space.s)
                .frame(width: ring)
            }

            VStack(spacing: DS.Space.xs) {
                Text("\(completionPercent)% of the world explored")
                    .font(.headline)
                Text("\(totalBuildings - totalStamped) buildings left to discover")
                    .font(.caption)
                    .foregroundColor(isHighContrast ? .primary : .secondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Space.xl)
        .padding(.horizontal, DS.Space.l)
        // Hero surface: the card's colors at the large radius
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous)
                .fill(isHighContrast ? Color(UIColor.systemBackground) : DS.Palette.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous)
                .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(totalStamped) stamps, \(completionPercent) percent of the world explored")
    }

    // MARK: - Stats grid

    // One column at accessibility sizes so labels don't break mid-word
    private var statColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: DS.Space.m), count: count)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: statColumns, spacing: DS.Space.m) {
            statCard(value: "\(citiesStarted)", label: "Cities Visited", icon: "building.2.fill", color: DS.Palette.accent)
            statCard(value: "\(citiesCompleted)", label: "Cities Mastered", icon: "checkmark.seal.fill", color: DS.Palette.gold)
            statCard(value: "\(countriesVisited)", label: "Countries", icon: "globe", color: DS.Palette.accent)
            statCard(value: "\(daysActive)", label: "Days Active", icon: "calendar.badge.clock", color: DS.Palette.accent)
        }
    }

    private func statCard(value: String, label: LocalizedStringKey, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundColor(isHighContrast ? .primary : color)
            Text(value)
                .font(.system(.title, design: .rounded))
                .fontWeight(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundColor(isHighContrast ? .primary : .secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .dsCard(isHighContrast: isHighContrast)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(label) + Text(verbatim: ": \(value)"))
    }

    // MARK: - Architect card

    private func architectCard(_ arch: (name: String, count: Int)) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader("FAVOURITE ARCHITECT", systemImage: "person.crop.circle.fill", isHighContrast: isHighContrast)

            // Icon above the name at accessibility sizes so long names keep their width
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.m))
                : AnyLayout(HStackLayout(spacing: DS.Space.l))
            layout {
                ZStack {
                    Circle()
                        .fill(isHighContrast ? Color.clear : DS.Palette.accent.opacity(0.12))
                        .frame(width: architectIconSize, height: architectIconSize)
                    Image(systemName: "pencil.and.ruler.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(isHighContrast ? .primary : DS.Palette.accent)
                }

                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text(arch.name)
                        .font(.headline.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    // Two keys rather than a ternary: a ternary of literals becomes a String, which Text doesn't translate
                    Group {
                        if arch.count == 1 {
                            Text("1 building stamped")
                        } else {
                            Text("\(arch.count) buildings stamped")
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(isHighContrast ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .dsCard(isHighContrast: isHighContrast)
    }

    // MARK: - Milestones card

    private func milestonesCard(firstStamp: Date) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader("MILESTONES", systemImage: "flag.checkered", isHighContrast: isHighContrast)

            milestoneRow(
                icon: "1.circle.fill",
                color: DS.Palette.accent,
                title: "First Stamp",
                value: firstStamp.formatted(date: .abbreviated, time: .omitted)
            )

            if citiesCompleted > 0 {
                milestoneRow(
                    icon: "checkmark.seal.fill",
                    color: DS.Palette.gold,
                    title: "Cities Mastered",
                    value: "\(citiesCompleted)"
                )
            }

            milestoneRow(
                icon: "building.columns.fill",
                color: DS.Palette.accent,
                title: "Total Stamps",
                value: String(format: NSLocalizedString("%lld of %lld", comment: "My Journey: stamps out of all buildings"),
                              totalStamped, totalBuildings)
            )
        }
        .dsCard(isHighContrast: isHighContrast)
    }

    private func milestoneRow(icon: String, color: Color, title: LocalizedStringKey, value: String) -> some View {
        HStack(spacing: DS.Space.m) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isHighContrast ? .primary : color)
                .frame(width: milestoneIconWidth)
            // Value moves under the title at accessibility sizes
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.xs))
                : AnyLayout(HStackLayout(spacing: DS.Space.m))
            layout {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: DS.Space.s)
                }
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundColor(isHighContrast ? .primary : .secondary)
            }
        }
    }
}
