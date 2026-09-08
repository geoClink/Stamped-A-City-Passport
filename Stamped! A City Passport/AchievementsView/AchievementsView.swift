import SwiftUI

struct AchievementsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var progress = GlobalProgressManager.shared
    @StateObject private var cityVM = CityViewModel()

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedCategory: Achievement.Category = .all

    private var cities: [CityLocation.City] { cityVM.allCities }

    private var displayed: [Achievement] {
        let list = Achievement.allAchievements
        guard selectedCategory != .all else { return list }
        return list.filter { $0.category == selectedCategory }
    }

    private var earnedCount: Int {
        Achievement.allAchievements.filter { $0.isEarned(manager: progress, cities: cities) }.count
    }

    private var columns: [GridItem] {
        let count = sizeClass == .regular ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    progressHeader
                    categoryPicker
                    achievementGrid
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adventureOrange)
                }
            }
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 12) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(earnedCount)")
                    .font(.system(.largeTitle, design: .serif))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adventureOrange)
                Text("/ \(Achievement.allAchievements.count)")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("achievements")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(UIColor.tertiarySystemFill))
                        .frame(height: 8)
                    Capsule()
                        .fill(Color.adventureOrange)
                        .frame(width: geo.size.width * CGFloat(earnedCount) / CGFloat(Achievement.allAchievements.count), height: 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: earnedCount)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Achievement.Category.allCases) { category in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = category
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.systemIcon)
                                .font(.caption)
                            Text(category.rawValue)
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedCategory == category
                            ? Color.adventureOrange
                            : Color(UIColor.secondarySystemGroupedBackground)
                        )
                        .foregroundStyle(selectedCategory == category ? .white : .primary)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    // MARK: - Grid

    private var achievementGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(displayed) { achievement in
                let earned = achievement.isEarned(manager: progress, cities: cities)
                AchievementCard(achievement: achievement, earned: earned)
            }
        }
    }
}

// MARK: - Achievement Card

private struct AchievementCard: View {
    let achievement: Achievement
    let earned: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(earned ? achievement.color.opacity(0.15) : Color(UIColor.tertiarySystemFill))
                        .frame(width: 44, height: 44)
                    Image(systemName: earned ? achievement.icon : "lock.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(earned ? achievement.color : Color.secondary)
                }
                Spacer()
                if earned {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.green)
                }
            }

            Text(achievement.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(earned ? .primary : .secondary)
                .lineLimit(2)

            Text(achievement.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if earned {
                Text(achievement.category.rawValue.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(achievement.color)
            } else {
                Text(achievement.category.rawValue.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .opacity(earned ? 1.0 : 0.6)
    }
}
