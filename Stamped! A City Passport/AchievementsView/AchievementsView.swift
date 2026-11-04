import SwiftUI

struct AchievementsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var progress = GlobalProgressManager.shared
    @StateObject private var cityVM = CityViewModel()

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("high_contrast_mode") private var isHighContrast = false
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

    // Fewer, wider cards at accessibility sizes so titles don't break mid-word
    private var columns: [GridItem] {
        #if os(macOS)
        // Mac: as many columns as the window has room for, so a wider window shows more cards
        return [GridItem(.adaptive(minimum: 180), spacing: DS.Space.m)]
        #else
        let count: Int
        if dynamicTypeSize.isAccessibilitySize {
            count = sizeClass == .regular ? 2 : 1
        } else {
            count = sizeClass == .regular ? 4 : 2
        }
        return Array(repeating: GridItem(.flexible(), spacing: DS.Space.m), count: count)
        #endif
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Space.xl) {
                    progressHeader
                    categoryPicker
                    achievementGrid
                }
                .dsPageMargin()
                .padding(.bottom, DS.Space.section)
            }
            .background(DS.Palette.pageBackground)
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            #if !os(macOS)
            // On the Mac this is its own window, closed with the window's close button
            .toolbar {
                ToolbarItem(placement: .closeSheet) {
                    Button("Done") { dismiss() }
                        .closesWithCommandW()
                        .fontWeight(.semibold)
                        .foregroundStyle(isHighContrast ? Color.primary : DS.Palette.accent)
                }
            }
            #endif
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: DS.Space.m) {
            HStack(alignment: .lastTextBaseline, spacing: DS.Space.xs) {
                Text("\(earnedCount)")
                    .font(.system(.largeTitle, design: .serif))
                    .fontWeight(.bold)
                    .foregroundStyle(isHighContrast ? Color.primary : DS.Palette.accent)
                Text("/ \(Achievement.allAchievements.count)")
                    .font(.title2)
                    .foregroundStyle(isHighContrast ? .primary : .secondary)
                Spacer(minLength: DS.Space.s)
                if !dynamicTypeSize.isAccessibilitySize {
                    achievementsLabel
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            // Moves under the count at accessibility sizes so the row doesn't clip
            if dynamicTypeSize.isAccessibilitySize {
                achievementsLabel
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(UIColor.tertiarySystemFill))
                        .frame(height: 8)
                    Capsule()
                        .fill(isHighContrast ? Color.primary : DS.Palette.accent)
                        .frame(width: geo.size.width * CGFloat(earnedCount) / CGFloat(Achievement.allAchievements.count), height: 8)
                        .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.8), value: earnedCount)
                }
            }
            .frame(height: 8)
        }
        .dsCard(isHighContrast: isHighContrast)
        // One element: "Achievements, 3 of 30" instead of "3", "/ 30" and the bar
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Achievements")
        .accessibilityValue(Text("\(earnedCount) of \(Achievement.allAchievements.count)"))
    }

    private var achievementsLabel: some View {
        Text("achievements")
            .font(.subheadline)
            .foregroundStyle(isHighContrast ? .primary : .secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Space.s) {
                ForEach(Achievement.Category.allCases) { category in
                    let isSelected = selectedCategory == category
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = category
                        }
                    } label: {
                        HStack(spacing: DS.Space.xs) {
                            Image(systemName: category.systemIcon)
                                .font(.caption)
                                .accessibilityHidden(true)
                            Text(category.localizedName)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, DS.Space.m)
                        .padding(.vertical, DS.Space.s)
                        .background(
                            Capsule().fill(
                                isSelected
                                ? (isHighContrast ? Color.primary : DS.Palette.accent)
                                : (isHighContrast ? Color(UIColor.systemBackground) : DS.Palette.cardBackground)
                            )
                        )
                        .overlay(
                            Capsule().stroke(isHighContrast && !isSelected ? Color.primary : Color.clear, lineWidth: 1.5)
                        )
                        .foregroundStyle(isSelected ? (isHighContrast ? Color(UIColor.systemBackground) : .white) : .primary)
                    }
                    // The filled chip is the chosen filter; say so, not just show it
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 1)
        }
    }

    // MARK: - Grid

    private var achievementGrid: some View {
        LazyVGrid(columns: columns, spacing: DS.Space.m) {
            ForEach(displayed) { achievement in
                let earned = achievement.isEarned(manager: progress, cities: cities)
                AchievementCard(achievement: achievement, earned: earned, isHighContrast: isHighContrast)
            }
        }
    }
}

// MARK: - Achievement Card

private struct AchievementCard: View {
    let achievement: Achievement
    let earned: Bool
    var isHighContrast = false

    @ScaledMetric(relativeTo: .title3) private var badgeSize: CGFloat = 44
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // Each badge keeps its own color once earned; locked badges stay gray
    private var badgeColor: Color {
        isHighContrast ? .primary : (earned ? achievement.color : .secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack {
                ZStack {
                    Circle()
                        .fill(earned && !isHighContrast ? achievement.color.opacity(0.15) : Color(UIColor.tertiarySystemFill))
                        .frame(width: badgeSize, height: badgeSize)
                    Image(systemName: earned ? achievement.icon : "lock.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(badgeColor)
                }
                Spacer()
                if earned {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(isHighContrast ? Color.primary : DS.Palette.gold)
                }
            }
            // The badge and check are read as "Earned" / "Locked" below
            .accessibilityHidden(true)

            Text(achievement.localizedTitle)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(earned || isHighContrast ? .primary : .secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(achievement.localizedDescription)
                .font(.caption)
                .foregroundStyle(isHighContrast ? .primary : .secondary)
                // Three lines: German and French goals run longer than English.
                // No limit at accessibility sizes, where the card is a full-width row.
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)

            Text(achievement.category.localizedName.localizedUppercase)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isHighContrast ? Color.primary : (earned ? achievement.color : Color(UIColor.tertiaryLabel)))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .dsCard(padding: DS.Space.m, isHighContrast: isHighContrast)
        // Dimming would undo high contrast, so locked cards only fade in standard mode
        .opacity(earned || isHighContrast ? 1.0 : 0.85)  // quiet, but the goal text stays readable
        .accessibilityElement(children: .combine)
        .accessibilityValue(earned ? Text("Earned") : Text("Locked"))
    }
}
