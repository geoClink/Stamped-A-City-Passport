//
//  CityItineraryView.swift
//  Stamped! A City Passport
//

import SwiftUI

// MARK: - Root View

struct CityItineraryView: View {
    let city: CityLocation.City
    @StateObject private var service = ItineraryService()
    @State private var dayCount = 3
    @AppStorage("high_contrast_mode") var manualHighContrast = false
    @Environment(\.colorSchemeContrast) var systemContrast
    var isHighContrast: Bool { manualHighContrast || systemContrast == .increased }
    var brandColor: Color { isHighContrast ? .primary : Color.adventureOrange }

    var body: some View {
        VStack(spacing: 0) {
            dayPicker
            Group {
                switch service.state {
                case .idle, .loading:
                    ItineraryLoadingView(brandColor: brandColor)
                case .error(let message):
                    ItineraryErrorView(message: message, brandColor: brandColor) {
                        service.clearCache(for: city.rawValue)
                        service.generateItinerary(for: city.rawValue, days: dayCount)
                    }
                case .loaded:
                    if #available(iOS 26.0, *) {
                        CityItineraryIntelligenceView(city: city, service: service, brandColor: brandColor)
                    } else {
                        CityItineraryBasicView(city: city, service: service, brandColor: brandColor)
                    }
                }
            }
        }
        .onAppear {
            service.generateItinerary(for: city.rawValue, days: dayCount)
        }
        .onChange(of: dayCount) { _, newCount in
            service.clearCache(for: city.rawValue)
            service.generateItinerary(for: city.rawValue, days: newCount)
        }
    }

    private var dayPicker: some View {
        HStack(spacing: 10) {
            Text("Days")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Picker("Days", selection: $dayCount) {
                ForEach(1...7, id: \.self) { n in Text("\(n)").tag(n) }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Apple Intelligence Version (iOS 26+)

@available(iOS 26.0, *)
struct CityItineraryIntelligenceView: View {
    let city: CityLocation.City
    @ObservedObject var service: ItineraryService
    let brandColor: Color
    @StateObject private var narrativeService = ItineraryNarrativeService()
    @StateObject private var mealService = MealRecommendationService()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("ARCHITECTURAL ITINERARY")
                    .font(.system(.caption, design: .default))
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .kerning(1.2)
                Spacer()
                if narrativeService.isGenerating {
                    HStack(spacing: 5) {
                        ProgressView().scaleEffect(0.6)
                        Text("Apple Intelligence")
                            .font(.caption2)
                            .foregroundColor(brandColor)
                    }
                } else if narrativeService.generationFailed {
                    Label("AI unavailable", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 25)
            .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(service.itinerary.enumerated()), id: \.offset) { dayIndex, stops in
                    ItineraryDaySection(
                        dayIndex: dayIndex,
                        stops: stops,
                        service: service,
                        narrativeService: narrativeService,
                        mealService: mealService,
                        isLast: dayIndex == service.itinerary.count - 1,
                        brandColor: brandColor
                    )
                }
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .onChange(of: service.itinerary) { _, newItinerary in
            guard !newItinerary.isEmpty else { return }
            Task {
                await narrativeService.generateAll(
                    itinerary: newItinerary,
                    buildings: service.buildings,
                    cityKey: city.rawValue
                )
                await mealService.generateMeals(
                    for: newItinerary,
                    buildings: service.buildings,
                    cityKey: city.rawValue
                )
            }
        }
        .onAppear {
            guard !service.itinerary.isEmpty else { return }
            Task {
                await narrativeService.generateAll(
                    itinerary: service.itinerary,
                    buildings: service.buildings,
                    cityKey: city.rawValue
                )
                await mealService.generateMeals(
                    for: service.itinerary,
                    buildings: service.buildings,
                    cityKey: city.rawValue
                )
            }
        }
    }
}

// MARK: - Basic Fallback Version

struct CityItineraryBasicView: View {
    let city: CityLocation.City
    @ObservedObject var service: ItineraryService
    let brandColor: Color
    @StateObject private var mealService = MealRecommendationService()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ARCHITECTURAL ITINERARY")
                .font(.system(.caption, design: .default))
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .kerning(1.2)
                .padding(.horizontal, 25)
                .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(service.itinerary.enumerated()), id: \.offset) { dayIndex, stops in
                    BasicDaySection(
                        dayIndex: dayIndex,
                        stops: stops,
                        service: service,
                        mealService: mealService,
                        brandColor: brandColor,
                        isLast: dayIndex == service.itinerary.count - 1
                    )
                }
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .onAppear {
            guard !service.itinerary.isEmpty else { return }
            Task {
                await mealService.generateMeals(
                    for: service.itinerary,
                    buildings: service.buildings,
                    cityKey: city.rawValue
                )
            }
        }
        .onChange(of: service.itinerary) { _, newItinerary in
            guard !newItinerary.isEmpty else { return }
            Task {
                await mealService.generateMeals(
                    for: newItinerary,
                    buildings: service.buildings,
                    cityKey: city.rawValue
                )
            }
        }
    }
}

// MARK: - Loading View

struct ItineraryLoadingView: View {
    let brandColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ARCHITECTURAL ITINERARY")
                .font(.system(.caption, design: .default))
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .kerning(1.2)
                .padding(.horizontal, 25)
                .padding(.bottom, 10)

            VStack(spacing: 16) {
                ProgressView().scaleEffect(0.9)
                Text("Planning your itinerary...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Error View

struct ItineraryErrorView: View {
    let message: String
    let brandColor: Color
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ARCHITECTURAL ITINERARY")
                .font(.system(.caption, design: .default))
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .kerning(1.2)
                .padding(.horizontal, 25)
                .padding(.bottom, 10)

            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                Text("Couldn't load itinerary")
                    .font(.subheadline).fontWeight(.semibold)
                Text(message)
                    .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                Button(action: onRetry) {
                    Text("Try Again")
                        .font(.caption).fontWeight(.semibold).foregroundColor(.white)
                        .padding(.horizontal, 20).padding(.vertical, 8)
                        .background(brandColor).cornerRadius(20)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Basic Day Section

struct BasicDaySection: View {
    let dayIndex: Int
    let stops: [PlannedStop]
    let service: ItineraryService
    @ObservedObject var mealService: MealRecommendationService
    let brandColor: Color
    let isLast: Bool

    @State private var isExpanded: Bool

    init(dayIndex: Int, stops: [PlannedStop], service: ItineraryService, mealService: MealRecommendationService, brandColor: Color, isLast: Bool) {
        self.dayIndex = dayIndex
        self.stops = stops
        self.service = service
        self.mealService = mealService
        self.brandColor = brandColor
        self.isLast = isLast
        _isExpanded = State(initialValue: dayIndex == 0)
    }

    var buildings: [Building] { stops.compactMap { service.building(for: $0) } }

    var architectSpotlight: String? {
        var counts: [String: Int] = [:]
        for b in buildings {
            let architects = b.architect
                .components(separatedBy: CharacterSet(charactersIn: "/&"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0.count > 3 }
            for a in architects { counts[a, default: 0] += 1 }
        }
        if let top = counts.max(by: { $0.value < $1.value }), top.value >= 2 {
            return "\(top.value) stops by \(top.key)"
        }
        return nil
    }

    var dominantEra: String {
        let years = buildings.map { $0.yearBuilt }
        guard !years.isEmpty, let avg = Optional(years.reduce(0, +) / years.count) else { return "" }
        switch avg {
        case ..<1400: return "Medieval"
        case 1400..<1600: return "Renaissance"
        case 1600..<1750: return "Baroque"
        case 1750..<1830: return "Neoclassical"
        case 1830..<1900: return "Victorian"
        case 1900..<1940: return "Art Deco"
        case 1940..<1970: return "Modernist"
        case 1970..<2000: return "Postmodern"
        default: return "Contemporary"
        }
    }

    var totalDayMins: Int {
        stops.reduce(0) { $0 + $1.visitDurationMins + $1.travelMinsFromPrev }
    }

    // Midday stop by arrival offset
    var lunchStop: Building? {
        let midStop = stops.min(by: { abs($0.arrivalOffsetMins - 180) < abs($1.arrivalOffsetMins - 180) })
        return midStop.flatMap { service.building(for: $0) }
    }

    var dayMeals: DayMeals? { mealService.mealsByDay[dayIndex + 1] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isExpanded.toggle() }
                HapticManager.shared.trigger(.selection)
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(isExpanded ? brandColor : brandColor.opacity(0.3))
                            .frame(width: 40, height: 40)
                        Text("\(dayIndex + 1)")
                            .font(.headline).fontWeight(.bold).foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Day \(dayIndex + 1)")
                            .font(.headline).fontWeight(.bold).foregroundColor(.primary)
                        HStack(spacing: 6) {
                            Text("\(stops.count) stops").font(.caption).foregroundColor(.secondary)
                            Text("·").font(.caption).foregroundColor(.secondary)
                            Text("\(totalDayMins / 60)h \(totalDayMins % 60)m").font(.caption).foregroundColor(.secondary)
                            if !dominantEra.isEmpty {
                                Text("·").font(.caption).foregroundColor(.secondary)
                                Text(dominantEra).font(.caption).fontWeight(.medium).foregroundColor(brandColor)
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                HStack(spacing: 8) {
                    if let spotlight = architectSpotlight {
                        InfoPill(icon: "pencil.and.ruler.fill", text: spotlight, brandColor: brandColor)
                    }
                    InfoPill(icon: "clock.fill", text: "Starts 9:00 AM", brandColor: brandColor)
                }
                .padding(.horizontal, 16).padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))

                TimelineBar(stops: stops, service: service, brandColor: brandColor)
                    .padding(.horizontal, 16).padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                Divider().padding(.leading, 16)

                ForEach(stops, id: \.id) { stop in
                    if let building = service.building(for: stop) {
                        BasicStopRow(
                            stop: stop,
                            building: building,
                            arrivalTime: service.formattedArrivalTime(offsetMins: stop.arrivalOffsetMins),
                            brandColor: brandColor,
                            isLast: stop.id == stops.last?.id,
                            isLunchStop: building.id == lunchStop?.id
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                LiveMealsRow(dayMeals: dayMeals, isLoading: mealService.isLoading, brandColor: brandColor)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }

        if !isLast { Divider() }
    }
}

// MARK: - Info Pill

struct InfoPill: View {
    let icon: String
    let text: String
    let brandColor: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9, weight: .semibold)).foregroundColor(brandColor)
            Text(text).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(brandColor.opacity(0.08)).cornerRadius(8)
    }
}

// MARK: - Basic Stop Row

struct BasicStopRow: View {
    let stop: PlannedStop
    let building: Building
    let arrivalTime: String
    let brandColor: Color
    let isLast: Bool
    let isLunchStop: Bool

    var buildingTypeIcon: String {
        let use = building.newUse.lowercased()
        if use.contains("museum") { return "photo.on.rectangle" }
        if use.contains("church") || use.contains("cathedral") || use.contains("mosque") { return "building.columns.fill" }
        if use.contains("palace") || use.contains("castle") { return "crown.fill" }
        if use.contains("theatre") || use.contains("theater") || use.contains("opera") { return "music.mic" }
        if use.contains("hotel") { return "bed.double.fill" }
        if use.contains("library") { return "books.vertical.fill" }
        if use.contains("office") || use.contains("commercial") { return "briefcase.fill" }
        return "building.2.fill"
    }

    var shortDescription: String {
        let use = building.newUse.isEmpty ? building.oldUse : building.newUse
        if building.yearBuilt < 100 { return "\(use) · Ancient" }
        if building.yearBuilt < 1000 { return "\(use) · \(building.yearBuilt) AD" }
        return "\(use) · \(building.yearBuilt)"
    }

    var mapsURL: URL? {
        guard let lat = building.latitude, let lon = building.longitude else { return nil }
        let encoded = building.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "maps://?daddr=\(lat),\(lon)&q=\(encoded)&dirflg=w")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(arrivalTime)
                        .font(.caption).fontWeight(.bold).foregroundColor(brandColor).frame(width: 56, alignment: .leading)
                    Text("\(stop.visitDurationMins)m")
                        .font(.system(size: 10)).foregroundColor(.secondary).frame(width: 56, alignment: .leading)
                }
                .padding(.top, 3)

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(brandColor.opacity(0.1)).frame(width: 32, height: 32)
                    Image(systemName: buildingTypeIcon)
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(brandColor)
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(building.name).font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                        if isLunchStop {
                            Image(systemName: "fork.knife").font(.system(size: 9)).foregroundColor(brandColor)
                        }
                    }
                    Text(shortDescription).font(.caption).foregroundColor(.secondary)
                    Text(building.buildingStyle).font(.caption2).foregroundColor(.secondary.opacity(0.7)).italic()
                    if stop.travelMinsFromPrev > 0 {
                        Label(
                            stop.requiresTransit ? "\(stop.travelMinsFromPrev) min · transit recommended" : "\(stop.travelMinsFromPrev) min walk",
                            systemImage: stop.requiresTransit ? "tram.fill" : "figure.walk"
                        )
                        .font(.caption2)
                        .foregroundColor(stop.requiresTransit ? .orange : .secondary)
                        .padding(.top, 2)
                    }
                }

                Spacer()

                if let url = mapsURL {
                    Link(destination: url) {
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(brandColor.opacity(0.7))
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            if !isLast { Divider().padding(.leading, 86) }
        }
    }
}

// MARK: - Timeline Bar

struct TimelineBar: View {
    let stops: [PlannedStop]
    let service: ItineraryService
    let brandColor: Color

    // Sorted chronologically — same order as the arrow navigation
    private var sorted: [Building] {
        stops.compactMap { service.building(for: $0) }
             .sorted { $0.yearBuilt < $1.yearBuilt }
    }

    @State private var selectedIndex: Int = 0

    private var selected: Building? {
        guard !sorted.isEmpty, sorted.indices.contains(selectedIndex) else { return nil }
        return sorted[selectedIndex]
    }

    private var yearRange: (min: Int, max: Int) {
        let years = sorted.map { $0.yearBuilt }
        return (years.min() ?? 0, years.max() ?? 2025)
    }

    private func position(for year: Int, in width: CGFloat) -> CGFloat {
        let range = yearRange
        let span = max(range.max - range.min, 1)
        return CGFloat(year - range.min) / CGFloat(span) * width
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TIMELINE")
                .font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).kerning(1.0)

            // Dot track — dots are visual indicators; tapping still works where spacing allows
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)

                    ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, building in
                        let x = position(for: building.yearBuilt, in: geo.size.width)
                        let isSelected = idx == selectedIndex

                        Button {
                            HapticManager.shared.trigger(.selection)
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                selectedIndex = idx
                            }
                        } label: {
                            Circle()
                                .fill(isSelected ? brandColor : brandColor.opacity(0.55))
                                .frame(width: isSelected ? 12 : 8, height: isSelected ? 12 : 8)
                                // Expand the tap area to 28pt so clustered dots are still hittable
                                .contentShape(Rectangle().size(CGSize(width: 28, height: 28))
                                    .offset(x: -10, y: -10))
                        }
                        .buttonStyle(.plain)
                        .offset(x: x - (isSelected ? 6 : 4), y: isSelected ? -4 : -2)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
                        .accessibilityLabel("\(building.yearBuilt), \(building.name)")
                        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .frame(height: 4).padding(.top, 6)
            }
            .frame(height: 16)

            HStack {
                Text(String(yearRange.min)).font(.system(size: 9)).foregroundColor(.secondary)
                Spacer()
                Text(String(yearRange.max)).font(.system(size: 9)).foregroundColor(.secondary)
            }

            // Callout + prev/next navigation
            if let building = selected {
                HStack(spacing: 8) {
                    // Prev
                    Button {
                        HapticManager.shared.trigger(.selection)
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedIndex = max(0, selectedIndex - 1)
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(selectedIndex == 0 ? .secondary.opacity(0.4) : brandColor)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.primary.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedIndex == 0)
                    .accessibilityLabel("Previous building")

                    // Building info
                    HStack(spacing: 6) {
                        Circle().fill(brandColor).frame(width: 6, height: 6)
                        Text("\(building.yearBuilt) · \(building.name)")
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(selectedIndex + 1) of \(sorted.count)")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(brandColor.opacity(0.1)))

                    // Next
                    Button {
                        HapticManager.shared.trigger(.selection)
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedIndex = min(sorted.count - 1, selectedIndex + 1)
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(selectedIndex == sorted.count - 1 ? .secondary.opacity(0.4) : brandColor)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.primary.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedIndex == sorted.count - 1)
                    .accessibilityLabel("Next building")
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            // Pre-select the first building so the callout is visible immediately
            selectedIndex = 0
        }
    }
}

// MARK: - Live Meals Row

struct LiveMealsRow: View {
    let dayMeals: DayMeals?
    let isLoading: Bool
    let brandColor: Color

    var body: some View {
        if isLoading && dayMeals == nil {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.6)
                Text("Finding nearby restaurants...")
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        } else if let meals = dayMeals {
            VStack(alignment: .leading, spacing: 0) {
                Divider().padding(.leading, 16)
                VStack(alignment: .leading, spacing: 10) {
                    Label("Eat & Drink", systemImage: "fork.knife.circle.fill")
                        .font(.caption).fontWeight(.semibold).foregroundColor(brandColor)
                    MealTypeRow(label: "Breakfast", meals: meals.breakfast, brandColor: brandColor)
                    MealTypeRow(label: "Lunch", meals: meals.lunch, brandColor: brandColor)
                    MealTypeRow(label: "Dinner", meals: meals.dinner, brandColor: brandColor)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
        }
    }
}

private struct MealTypeRow: View {
    let label: String
    let meals: [MealRecommendation]
    let brandColor: Color

    var body: some View {
        if !meals.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .kerning(0.5)
                ForEach(meals.prefix(2)) { meal in
                    if let url = meal.mapsURL {
                        Link(destination: url) {
                            HStack(spacing: 6) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 11)).foregroundColor(brandColor.opacity(0.7))
                                Text(meal.name)
                                    .font(.caption).foregroundColor(.primary)
                                Text("·").font(.caption).foregroundColor(.secondary)
                                Text(meal.category)
                                    .font(.caption2).foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 9)).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Day Section (iOS 26+)

@available(iOS 26.0, *)
struct ItineraryDaySection: View {
    let dayIndex: Int
    let stops: [PlannedStop]
    let service: ItineraryService
    @ObservedObject var narrativeService: ItineraryNarrativeService
    @ObservedObject var mealService: MealRecommendationService
    let isLast: Bool
    let brandColor: Color

    @State private var isExpanded: Bool

    init(dayIndex: Int, stops: [PlannedStop], service: ItineraryService, narrativeService: ItineraryNarrativeService, mealService: MealRecommendationService, isLast: Bool, brandColor: Color) {
        self.dayIndex = dayIndex
        self.stops = stops
        self.service = service
        self.narrativeService = narrativeService
        self.mealService = mealService
        self.isLast = isLast
        self.brandColor = brandColor
        _isExpanded = State(initialValue: dayIndex == 0)
    }

    var totalDayMins: Int {
        stops.reduce(0) { $0 + $1.visitDurationMins + $1.travelMinsFromPrev }
    }

    var architectSpotlight: String? {
        let buildings = stops.compactMap { service.building(for: $0) }
        var counts: [String: Int] = [:]
        for b in buildings {
            let architects = b.architect.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespaces) }
            for a in architects { if !a.isEmpty { counts[a, default: 0] += 1 } }
        }
        if let top = counts.max(by: { $0.value < $1.value }), top.value >= 2 {
            return "\(top.value) stops designed by \(top.key)"
        }
        return nil
    }

    var dayMeals: DayMeals? { mealService.mealsByDay[dayIndex + 1] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isExpanded.toggle() }
                HapticManager.shared.trigger(.selection)
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(isExpanded ? brandColor : brandColor.opacity(0.3))
                            .frame(width: 36, height: 36)
                        Text("\(dayIndex + 1)")
                            .font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Day \(dayIndex + 1)")
                            .font(.headline).fontWeight(.bold).foregroundColor(.primary)
                        HStack(spacing: 6) {
                            Text("\(stops.count) stops").font(.caption).foregroundColor(.secondary)
                            Text("·").font(.caption).foregroundColor(.secondary)
                            Text("\(totalDayMins / 60)h \(totalDayMins % 60)m").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                if let narrative = narrativeService.dayNarratives[dayIndex + 1] {
                    Text(narrative)
                        .font(.subheadline).foregroundColor(.primary.opacity(0.85))
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.tertiarySystemBackground)).cornerRadius(12)
                        .padding(.horizontal, 16).padding(.bottom, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else if narrativeService.isGenerating {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.tertiarySystemBackground)).frame(height: 60)
                        .padding(.horizontal, 16).padding(.bottom, 10)
                        .shimmering().transition(.opacity)
                }

                if let spotlight = architectSpotlight {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil.and.ruler.fill").font(.caption).foregroundColor(brandColor)
                        Text(spotlight).font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                TimelineBar(stops: stops, service: service, brandColor: brandColor)
                    .padding(.horizontal, 16).padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                Divider().padding(.leading, 66)

                ForEach(stops, id: \.id) { stop in
                    if let building = service.building(for: stop) {
                        ItineraryStopRow(
                            stop: stop,
                            building: building,
                            arrivalTime: service.formattedArrivalTime(offsetMins: stop.arrivalOffsetMins),
                            description: narrativeService.stopDescriptions[building.id],
                            isGenerating: narrativeService.isGenerating,
                            brandColor: brandColor,
                            isLast: stop.id == stops.last?.id
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                LiveMealsRow(dayMeals: dayMeals, isLoading: mealService.isLoading, brandColor: brandColor)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }

        if !isLast { Divider() }
    }
}

// MARK: - Stop Row (iOS 26+)

@available(iOS 26.0, *)
struct ItineraryStopRow: View {
    let stop: PlannedStop
    let building: Building
    let arrivalTime: String
    let description: String?
    let isGenerating: Bool
    let brandColor: Color
    let isLast: Bool

    var mapsURL: URL? {
        guard let lat = building.latitude, let lon = building.longitude else { return nil }
        let encoded = building.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "maps://?daddr=\(lat),\(lon)&q=\(encoded)&dirflg=w")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(arrivalTime)
                        .font(.caption).fontWeight(.semibold).foregroundColor(brandColor).frame(width: 52, alignment: .leading)
                    Text("\(stop.visitDurationMins)m")
                        .font(.system(size: 9)).foregroundColor(.secondary).frame(width: 52, alignment: .leading)
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(building.name).font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                    if let desc = description {
                        Text(desc).font(.caption).foregroundColor(.secondary)
                    } else if isGenerating {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.1)).frame(height: 12).frame(maxWidth: 200).shimmering()
                    }
                    if stop.travelMinsFromPrev > 0 {
                        Label(
                            stop.requiresTransit ? "\(stop.travelMinsFromPrev) min · transit recommended" : "\(stop.travelMinsFromPrev) min walk",
                            systemImage: stop.requiresTransit ? "tram.fill" : "figure.walk"
                        )
                        .font(.caption2)
                        .foregroundColor(stop.requiresTransit ? .orange : .secondary)
                        .padding(.top, 2)
                    }
                }

                Spacer()

                if let url = mapsURL {
                    Link(destination: url) {
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(brandColor.opacity(0.7))
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            if !isLast { Divider().padding(.leading, 82) }
        }
    }
}

// MARK: - Shimmer Effect

extension View {
    func shimmering() -> some View { self.modifier(ShimmerModifier()) }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .white.opacity(0.4), .clear]),
                    startPoint: .init(x: phase - 0.3, y: 0),
                    endPoint: .init(x: phase, y: 0)
                )
                .blendMode(.screen)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { phase = 1.3 }
            }
    }
}
