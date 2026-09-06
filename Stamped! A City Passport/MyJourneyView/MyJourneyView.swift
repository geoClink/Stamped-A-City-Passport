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

    private var allBuildings: [Building] { cityVM.allCities.flatMap { $0.buildings } }
    private var visitedIDs: Set<String> { progress.visitedIDs }

    // MARK: - Computed stats

    private var totalStamped: Int { visitedIDs.count }
    private var totalBuildings: Int { allBuildings.count }
    private var completionPercent: Int {
        guard totalBuildings > 0 else { return 0 }
        return Int((Double(totalStamped) / Double(totalBuildings)) * 100)
    }

    private var citiesStarted: Int {
        cityVM.allCities.filter { city in
            city.buildings.contains { visitedIDs.contains($0.id) }
        }.count
    }

    private var citiesCompleted: Int {
        cityVM.allCities.filter { city in
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
            counts[building.architect, default: 0] += 1
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
                VStack(spacing: 24) {
                    heroCard
                    statsGrid
                    if let arch = favoriteArchitect { architectCard(arch) }
                    if let date = firstStampDate { milestonesCard(firstStamp: date) }
                }
                .padding()
                .padding(.bottom, 32)
            }
            .background(Color(UIColor.systemGroupedBackground))
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
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.adventureOrange.opacity(0.15), lineWidth: 16)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: totalBuildings > 0 ? CGFloat(totalStamped) / CGFloat(totalBuildings) : 0)
                    .stroke(Color.adventureOrange, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 1.0), value: totalStamped)

                VStack(spacing: 2) {
                    Text("\(totalStamped)")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.black)
                        .foregroundColor(.primary)
                    Text("stamps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 4) {
                Text("\(completionPercent)% of the world explored")
                    .font(.headline)
                Text("\(totalBuildings - totalStamped) buildings left to discover")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(totalStamped) stamps, \(completionPercent) percent of the world explored")
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(value: "\(citiesStarted)", label: "Cities Visited", icon: "building.2.fill", color: .blue)
            statCard(value: "\(citiesCompleted)", label: "Cities Mastered", icon: "checkmark.seal.fill", color: .adventureOrange)
            statCard(value: "\(countriesVisited)", label: "Countries", icon: "globe", color: .green)
            statCard(value: "\(daysActive)", label: "Days Active", icon: "calendar.badge.clock", color: .purple)
        }
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.system(.title, design: .rounded))
                .fontWeight(.black)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Architect card

    private func architectCard(_ arch: (name: String, count: Int)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("FAVOURITE ARCHITECT", systemImage: "person.crop.circle.fill")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .kerning(0.8)

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.adventureOrange.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: "pencil.and.ruler.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.adventureOrange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(arch.name)
                        .font(.headline.bold())
                    Text("\(arch.count) building\(arch.count == 1 ? "" : "s") stamped")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Milestones card

    private func milestonesCard(firstStamp: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("MILESTONES", systemImage: "flag.checkered")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .kerning(0.8)

            milestoneRow(
                icon: "1.circle.fill",
                color: .yellow,
                title: "First Stamp",
                value: firstStamp.formatted(date: .abbreviated, time: .omitted)
            )

            if citiesCompleted > 0 {
                milestoneRow(
                    icon: "checkmark.seal.fill",
                    color: .adventureOrange,
                    title: "Cities Mastered",
                    value: "\(citiesCompleted)"
                )
            }

            milestoneRow(
                icon: "building.columns.fill",
                color: .blue,
                title: "Total Stamps",
                value: "\(totalStamped) of \(totalBuildings)"
            )
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private func milestoneRow(icon: String, color: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 28)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
        }
    }
}
