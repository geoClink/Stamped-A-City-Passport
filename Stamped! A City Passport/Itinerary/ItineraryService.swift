//
//  File.swift
//  Stamped
//
//  Created by George Clinkscales on 2/10/26.

import SwiftUI
import Foundation
import Combine

// MARK: - 1. AI GENERATION SCHEMA
struct AICuratedContent: Codable {
    var activity: String
    var icon: String
    var food: String
}

// Short persistence model for saving generated itineraries to disk.
struct PersistedItineraryStep: Codable {
    let id: String
    let timeSlot: String
    let buildingID: String
    let curatedActivity: String
    let icon: String
    let foodSuggestion: String
    let isFinalStop: Bool
}

enum ItineraryPersistence {
    private static var baseDir: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    private static func fileURL(cityRaw: String, day: Int) -> URL? {
        guard let base = baseDir else { return nil }
        let folder = base.appendingPathComponent("itineraries", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("\(cityRaw)-day\(day).json")
    }

    static func exists(cityRaw: String, day: Int) -> Bool {
        guard let url = fileURL(cityRaw: cityRaw, day: day) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    static func save(cityRaw: String, day: Int, steps: [PersistedItineraryStep]) throws {
        guard let url = fileURL(cityRaw: cityRaw, day: day) else { throw NSError(domain: "ItineraryPersistence", code: 1) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(steps)
        try data.write(to: url, options: .atomic)
        print("ItineraryPersistence: saved \(steps.count) steps to \(url.path)")
    }

    static func load(cityRaw: String, day: Int) throws -> [PersistedItineraryStep]? {
        guard let url = fileURL(cityRaw: cityRaw, day: day) else { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let arr = try decoder.decode([PersistedItineraryStep].self, from: data)
        print("ItineraryPersistence: loaded \(arr.count) steps from \(url.path)")
        return arr
    }
}

// Debouncer actor to batch rapid saves for the same city/day.
actor ItinerarySaveDebouncer {
    static let shared = ItinerarySaveDebouncer()
    private var pending: [String: Task<Void, Never>] = [:]

    func scheduleSave(cityRaw: String, day: Int, steps: [PersistedItineraryStep], delay: TimeInterval = 1.0) {
        let key = "\(cityRaw)-\(day)"
        // cancel any existing pending save for this key
        pending[key]?.cancel()

        let task = Task.detached { @MainActor in
            // Sleep for debounce interval (cancellable)
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                // cancelled
                return
            }

            do {
                try ItineraryPersistence.save(cityRaw: cityRaw, day: day, steps: steps)
            } catch {
                print("ItinerarySaveDebouncer: failed saving \(cityRaw)-day\(day): \(error)")
            }
            // remove pending entry
            await self.clear(key: key)
        }

        pending[key] = task
    }

    private func clear(key: String) {
        pending[key] = nil
    }
}

// MARK: - 2. VIEW MODEL
@MainActor
class ItineraryStep: Identifiable, ObservableObject {
    static var debugForceMockAI: Bool {
        UserDefaults.standard.bool(forKey: "debug_force_mock_ai")
    }

    let id = UUID()
    let timeSlot: String
    let building: Building

    @Published var curatedActivity: String
    @Published var icon: String
    @Published var foodSuggestion: String
    @Published var isGenerating: Bool = false

    var isFinalStop: Bool = false

    // Called after this step finishes updating its AI content
    // Parent view-model can set this to trigger persistence of the day's itinerary
    var onUpdated: (() -> Void)? = nil

    var timeContextIcon: String {
        if isFinalStop { return "sunset.fill" }

        let time = timeSlot.uppercased()
        if time.contains("09:00") { return "sunrise.fill" }
        if time.contains("12:00") || time.contains("03:00") { return "sun.max.fill" }
        return "mappin.and.ellipse"
    }

    init(timeSlot: String, building: Building, isFinal: Bool = false) {
        self.building = building
        self.timeSlot = timeSlot
        self.isFinalStop = isFinal
        self.curatedActivity = "Analyzing architecture at \(building.address)..."
        self.icon = "building.columns"
        self.foodSuggestion = building.foodSpots.first ?? "Nearby Dining"
    }

    func generateAIContent(previousZip: String? = nil) async {
        self.isGenerating = true

        var distanceHint = "Explore this historic area."
        if let prev = previousZip {
            distanceHint = (prev == building.address) ? "Short walk from previous stop." : "Short transit to a new area."
        }

        #if canImport(FoundationModels)
        if #available(iOS 18.0, *) {
            if let aiResponse = await tryRunAppleIntelligence(time: self.timeSlot, hint: distanceHint) {
                self.curatedActivity = aiResponse.activity
                self.icon = aiResponse.icon
                self.foodSuggestion = aiResponse.food
                self.isGenerating = false
                // notify parent that content updated
                self.onUpdated?()
                return
            }
        }
        #endif

        // Debug: short-circuit AI generation if mock toggle is on
        if Self.debugForceMockAI {
            self.curatedActivity = "\(distanceHint) Admire the \(building.buildingStyle) details at \(building.address)."
            self.icon = "mappin.and.ellipse"
            self.foodSuggestion = building.foodSpots.randomElement() ?? "Local Favorite"
            self.isGenerating = false
            // notify parent that content updated
            self.onUpdated?()
            return
        }

        try? await Task.sleep(nanoseconds: 600_000_000)
        self.curatedActivity = "\(distanceHint) Admire the \(building.buildingStyle) details at \(building.address)."
        self.icon = "mappin.and.ellipse"
        self.foodSuggestion = building.foodSpots.randomElement() ?? "Local Favorite"
        self.isGenerating = false
        // notify parent that content updated
        self.onUpdated?()
    }
}

// MARK: - 3. AI ISOLATION EXTENSION
#if canImport(FoundationModels)
import FoundationModels

extension ItineraryStep {
    @available(iOS 18.0, *)
    private func tryRunAppleIntelligence(time: String, hint: String) async -> AICuratedContent? {
        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession()
                // Construct a structured JSON prompt asking the model to return ONLY JSON with three fields
                let context: [String: Any] = [
                    "name": building.name,
                    "address": building.address,
                    "time": time,
                    "hint": hint,
                    "foodSpots": building.foodSpots,
                    "style": building.buildingStyle
                ]
                // Render context as compact JSON for the prompt
                let ctxData = try JSONSerialization.data(withJSONObject: context, options: [])
                let ctxString = String(data: ctxData, encoding: .utf8) ?? "{}"

                let prompt = """
                You are an assistant that returns a JSON object only. Given the following context JSON, produce a JSON object with exactly these keys:
                {
                  "activity": "A 1-2 sentence visitor guide tailored to the time and hint",
                  "icon": "A single SF Symbol name (e.g. \"sparkles\")",
                  "food": "A short food suggestion (pick from provided foodSpots when possible)"
                }

                Context: \(ctxString)

                Return only valid JSON and nothing else.
                """

                let response = try await session.respond(to: prompt)
                var content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

                // Helper: remove common code fences and surrounding markdown
                func stripCodeFences(_ s: String) -> String {
                    var t = s
                    // remove ```json or ```
                    t = t.replacingOccurrences(of: "```json", with: "")
                    t = t.replacingOccurrences(of: "```", with: "")
                    // remove leading/trailing markdown fences or html pre tags
                    t = t.replacingOccurrences(of: "<pre>", with: "")
                    t = t.replacingOccurrences(of: "</pre>", with: "")
                    return t.trimmingCharacters(in: .whitespacesAndNewlines)
                }

                content = stripCodeFences(content)

                // Try to find a JSON object substring { ... }
                func extractJSONObjectString(_ s: String) -> String? {
                    guard let first = s.firstIndex(of: "{") else { return nil }
                    guard let last = s.lastIndex(of: "}") else { return nil }
                    // ensure first comes before last
                    if first <= last {
                        let sub = String(s[first...last])
                        return sub
                    }
                    return nil
                }

                // Attempt to decode: try extracted JSON substring first, then full content
                if let jsonString = extractJSONObjectString(content), let data = jsonString.data(using: .utf8) {
                    // Try strict decode
                    if let decoded = try? JSONDecoder().decode(AICuratedContent.self, from: data) {
                        return decoded
                    }
                    // Try loose decode via JSONSerialization to extract fields
                    if let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        let activity = (obj["activity"] as? String) ?? (obj["text"] as? String) ?? content
                        let icon = (obj["icon"] as? String) ?? "sparkles"
                        let food = (obj["food"] as? String) ?? building.foodSpots.first ?? "Dining"
                        return AICuratedContent(activity: activity, icon: icon, food: food)
                    }
                }

                // If we get here, no JSON parse succeeded — fall back to plain-text cleaning
                // Remove accidental JSON-like artifacts so UI doesn't display raw JSON
                func cleanFallback(_ s: String) -> String {
                    var t = s
                    // remove braces and quotes at ends if present
                    t = t.replacingOccurrences(of: "\\n", with: " ")
                    // strip common JSON characters that might confuse presentation
                    t = t.replacingOccurrences(of: "{", with: "")
                    t = t.replacingOccurrences(of: "}", with: "")
                    t = t.replacingOccurrences(of: "\"", with: "")
                    t = t.replacingOccurrences(of: "\\", with: "")
                    return t.trimmingCharacters(in: .whitespacesAndNewlines)
                }

                let cleaned = cleanFallback(content)

                // Heuristic: detect low-quality or model-meta content (mentions of Apple/FoundationModels, assistant/system text, raw JSON remnants)
                func isLowQuality(_ text: String) -> Bool {
                    let lowKeywords = ["apple", "foundationmodels", "foundation models", "language model", "assistant", "system", "model", "openai", "anthropic", "claude"]
                    let lower = text.lowercased()
                    // if it contains obvious low-keywords or leftover braces/brackets, mark as low-quality
                    if lower.contains("{") || lower.contains("}") || lower.contains("[") || lower.contains("]") { return true }
                    for k in lowKeywords { if lower.contains(k) { return true } }
                    // also mark as low-quality if it's very short or excessively long JSON-like
                    if lower.count < 20 { return true }
                    if lower.count > 2000 { return true }
                    return false
                }

                var activityCandidate = cleaned
                var iconCandidate = "sparkles"
                var foodCandidate = building.foodSpots.first ?? "Dining"

                if isLowQuality(activityCandidate) {
                    // Build a concise, human-friendly fallback from building data
                    let foodHint = building.foodSpots.isEmpty ? "Nearby dining available." : "Nearby: \(building.foodSpots.joined(separator: ", "))"
                    let style = building.buildingStyle.isEmpty ? "interesting site" : building.buildingStyle
                    activityCandidate = "Visit \(building.name), a \(style) at \(building.address). Allow about 45 minutes to explore. \(foodHint)"
                }

                // Ensure icon and food are sensible strings
                if iconCandidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { iconCandidate = "sparkles" }
                if foodCandidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { foodCandidate = building.foodSpots.first ?? "Dining" }

                return AICuratedContent(activity: activityCandidate, icon: iconCandidate, food: foodCandidate)
            } catch { return nil }
        }
        return nil
    }
}
#endif

// MARK: - 4. THE MAIN VIEW
struct CityItineraryView: View {
    let city: CityLocation.City
    @State private var selectedDay: Int = 1
    @State private var itinerary: [ItineraryStep] = []
    @State private var isRefreshingAll = false
    @State private var hasSavedItinerary: Bool = false
    @State private var showSavedToast: Bool = false

        @AppStorage("high_contrast_mode") var manualHighContrast = false
        @AppStorage("debug_force_mock_ai") var debugForceMockAI: Bool = false
        @Environment(\.colorSchemeContrast) private var systemContrast

        private var isHighContrast: Bool {
            manualHighContrast || systemContrast == .increased
        }
    
    var body: some View {
         VStack(alignment: .leading, spacing: 0) {
             headerSection
             dayPicker
             
             ScrollView(.horizontal, showsIndicators: false) {
                 HStack(spacing: 20) {
                     ForEach(itinerary) { step in
                         ItineraryCard(step: step)
                             .id("\(selectedDay)-\(step.building.id)")
                     }
                 }
                 .padding(.horizontal, 25)
             }
             .refreshable { await loadFromRegistry(userInitiated: true) }
             
             Spacer()
         }
         .task(id: selectedDay) {
             await loadFromRegistry(userInitiated: false)
         }
         .overlay(alignment: .top) {
             if showSavedToast {
                 Text("Saved")
                     .font(.caption.bold())
                     .padding(.horizontal, 12)
                     .padding(.vertical, 8)
                     .background(.ultraThinMaterial)
                     .cornerRadius(12)
                     .shadow(radius: 8)
                     .padding(.top, 44)
                     .transition(.move(edge: .top).combined(with: .opacity))
             }
         }
    }
    
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI CURATED EXPLORATION")
                    .font(.system(size: 10, weight: .black)).tracking(2)
                    .foregroundColor(isHighContrast ? .primary : .orange)
                
                Text(city.name)
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .fontWeight(isHighContrast ? .black : .bold)
            }
            
            Spacer()
            
            // Debug: Mock AI toggle for Simulator testing
            Button(action: {
                HapticManager.shared.trigger(.selection)
                debugForceMockAI.toggle()
            }) {
                Text(debugForceMockAI ? "Mock AI: ON" : "Mock AI: OFF")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(6)
                    .background(debugForceMockAI ? Color.green.opacity(0.15) : Color.gray.opacity(0.08))
                    .cornerRadius(8)
            }
            
            Button(action: {
                HapticManager.shared.trigger(.selection)
                Task { await loadFromRegistry(userInitiated: true) }
            }) {
                if #available(iOS 17.0, *) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 30))
                        .symbolEffect(.bounce, value: isRefreshingAll)
                        .foregroundColor(isHighContrast ? .primary : Color.adventureOrange.opacity(0.8))
                } else {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(isHighContrast ? .primary : .orange)
                }
            }
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 20)
    }
    
    private var dayPicker: some View {
        HStack(spacing: 0) {
            ForEach(1...3, id: \.self) { day in
                Button(action: {
                    HapticManager.shared.trigger(.selection)
                    withAnimation(.spring(response: 0.3)) {
                        selectedDay = day
                    }
                }) {
                    Text("DAY \(day)")
                        .font(.system(size: 12, weight: .black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedDay == day ? (isHighContrast ? .primary : .orange) : Color.clear)
                        .foregroundColor(selectedDay == day ? (isHighContrast ? Color(UIColor.systemBackground) : .white) : .primary)
                }
                .overlay(
                    HStack {
                        if day < 3 && isHighContrast {
                            Spacer()
                            Rectangle().fill(Color.primary).frame(width: 2)
                        }
                    }
                )
            }
        }
        .background(isHighContrast ? Color(UIColor.systemBackground) : Color.orange.opacity(0.1))
        .cornerRadius(isHighContrast ? 4 : 12)
        .overlay(
            RoundedRectangle(cornerRadius: isHighContrast ? 4 : 12)
                .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 3)
        )
        .padding(.horizontal, 25)
        .padding(.bottom, 30)
    }

    // Helper: find a Building by id across enum-keyed `data` only (safe, compile-time API).
    private func buildingByID(_ id: String) -> Building? {
        for (_, list) in BuildingRegistry.data {
            if let found = list.first(where: { $0.id == id }) { return found }
        }
        return nil
    }

    private func loadFromRegistry(userInitiated: Bool = false) async {
        isRefreshingAll = true

        // If this is NOT a user-initiated refresh, prefer any saved itinerary for the selected day.
        if !userInitiated {
            if ItineraryPersistence.exists(cityRaw: city.id, day: selectedDay) {
                do {
                    if let saved = try ItineraryPersistence.load(cityRaw: city.id, day: selectedDay) {
                        var converted: [ItineraryStep] = []
                        for s in saved {
                            if let b = buildingByID(s.buildingID) {
                                let step = ItineraryStep(timeSlot: s.timeSlot, building: b, isFinal: s.isFinalStop)
                                step.curatedActivity = s.curatedActivity
                                step.icon = s.icon
                                step.foodSuggestion = s.foodSuggestion
                                // saved steps are already final; mark them as not generating
                                step.isGenerating = false
                                converted.append(step)
                            }
                        }
                        // Show saved itinerary and avoid regenerating
                        await MainActor.run {
                            self.itinerary = converted
                            self.hasSavedItinerary = true
                            self.isRefreshingAll = false
                        }
                        return
                    }
                } catch {
                    print("Failed loading saved itinerary for day \(selectedDay): \(error)")
                    // fall through to regenerate
                }
            }
        }

        // No saved itinerary found (or user requested a refresh) -> generate new steps
        // Use the full set of buildings for the city so the planner can partition into multi-day clusters
        let allBuildings = BuildingRegistry.data[city] ?? []

        // Use the on-device multi-day planner to partition the city's buildings into 3 sensible days
        let multiPlanned = ItineraryPlanner.planMultiDay(buildings: allBuildings, days: 3, startOffsetMin: 0, visitDurationMin: 45)

        // select the planned stops for the current selected day (1-based index)
        let dayIndex = max(0, min(multiPlanned.count - 1, selectedDay - 1))
        let plannedForDay = multiPlanned.count > dayIndex ? multiPlanned[dayIndex] : []

        var steps: [ItineraryStep] = []
        // map planned stops back to building objects and set a simple timeSlot label
        for (i, p) in plannedForDay.enumerated() {
            if let b = buildingByID(p.buildingID) {
                // derive a human-readable timeSlot from arrival offset (simple 24h formatting)
                let hours = 9 + (p.arrivalOffsetMins / 60)
                let mins = p.arrivalOffsetMins % 60
                let timeLabel = String(format: "%02d:%02d", hours, mins)
                let isFinal = (i == plannedForDay.count - 1)
                let step = ItineraryStep(timeSlot: timeLabel, building: b, isFinal: isFinal)
                steps.append(step)
            }
        }

        // Set per-step update handlers so each completed AI generation triggers a save of the current day
        let dayCopy = selectedDay
        let cityID = city.id
        for step in steps {
            step.onUpdated = {
                // Capture current snapshot of steps and persist without referencing the view instance
                let persist = steps.map { s in
                    PersistedItineraryStep(
                        id: s.id.uuidString,
                        timeSlot: s.timeSlot,
                        buildingID: s.building.id,
                        curatedActivity: s.curatedActivity,
                        icon: s.icon,
                        foodSuggestion: s.foodSuggestion,
                        isFinalStop: s.isFinalStop
                    )
                }
                Task {
                    // Await the actor-isolated save method properly
                    await ItinerarySaveDebouncer.shared.scheduleSave(cityRaw: cityID, day: dayCopy, steps: persist)
                    print("CityItineraryView: onUpdated scheduled save for day \(dayCopy) city \(cityID)")
                    // After scheduling a save, mark this day as saved so future non-user loads won't overwrite it
                    await MainActor.run {
                        if dayCopy == selectedDay {
                            hasSavedItinerary = true
                            showSavedToast = true
                            // hide toast after 1.8s
                            Task { try? await Task.sleep(nanoseconds: 1_800_000_000); await MainActor.run { showSavedToast = false } }
                        }
                    }
                }
            }
        }

        // Present generated base steps immediately
        await MainActor.run { self.itinerary = steps }

        // Generate AI content for each step (asynchronously) — each step will persist itself when done via onUpdated
        for i in 0..<steps.count {
            let prevZip = i > 0 ? steps[i-1].building.address : nil
            await steps[i].generateAIContent(previousZip: prevZip)
        }

        isRefreshingAll = false
    }

    // Persist the provided ItineraryStep array for the given day.
    private func persistSteps(_ steps: [ItineraryStep], day: Int) async {
        let persist = steps.map { step in
            PersistedItineraryStep(
                id: step.id.uuidString,
                timeSlot: step.timeSlot,
                buildingID: step.building.id,
                curatedActivity: step.curatedActivity,
                icon: step.icon,
                foodSuggestion: step.foodSuggestion,
                isFinalStop: step.isFinalStop
            )
        }

        do {
            try ItineraryPersistence.save(cityRaw: city.id, day: day, steps: persist)
            print("persistSteps: saved day \(day) for city \(city.id) to disk")
            // mark saved for UI if we're on the same day
            if day == selectedDay {
                hasSavedItinerary = true
                showSavedToast = true
                Task { try? await Task.sleep(nanoseconds: 1_800_000_000); await MainActor.run { showSavedToast = false } }
            }
        } catch {
            print("Failed saving itinerary for day \(day): \(error)")
        }
    }

    // MARK: - 5. THE CARD VIEW
    struct ItineraryCard: View {
        @ObservedObject var step: ItineraryStep
        
        @AppStorage("high_contrast_mode") var manualHighContrast = false
        @Environment(\.colorSchemeContrast) private var systemContrast
        private var isHighContrast: Bool { manualHighContrast || systemContrast == .increased }
        private var brandColor: Color { isHighContrast ? .primary : .orange }
        @Environment(\.colorScheme) var colorScheme

        var body: some View {
            ZStack {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(step.timeSlot)
                            .font(.caption.bold().monospaced())
                            .foregroundColor(brandColor)
                        Spacer()
                        Image(systemName: step.timeContextIcon)
                            .symbolRenderingMode(isHighContrast ? .monochrome : .multicolor)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isHighContrast ? .primary : .orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.building.name)
                            .font(.headline)
                            .fontWeight(isHighContrast ? .black : .bold)
                            .lineLimit(2)
                        Text(step.building.buildingStyle.uppercased())
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(isHighContrast ? .primary : .secondary)
                    }
                    
                    Text(step.curatedActivity)
                        .font(.subheadline)
                        .fontWeight(isHighContrast ? .medium : .regular)
                        .foregroundColor(.primary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer(minLength: 10)
                    
                    Divider()
                        .background(isHighContrast ? Color.primary : Color.gray.opacity(0.2))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("RECOMMENDED REFUEL")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(isHighContrast ? .primary : .secondary)
                            Text(step.foodSuggestion)
                                .font(.subheadline.bold())
                                .lineLimit(5)
                        }
                        Spacer()
                        
                        Button(action: {
                            HapticManager.shared.trigger(.selection)
                            Task { await step.generateAIContent() }
                        }) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor((isHighContrast && colorScheme != .dark) ? .white : (isHighContrast ? .primary : .orange))
                                .padding(10)
                                .background(
                                    isHighContrast
                                    ? (colorScheme == .dark ? Color.white.opacity(0.2) : Color.black)
                                    : Color.orange.opacity(0.1)
                                )
                                .clipShape(
                                    RoundedRectangle(cornerRadius: isHighContrast ? 4 : 20)
                                )
                        }
                    }
                }
                .padding(24)
                .redacted(reason: step.isGenerating ? .placeholder : [])
                
                if step.isGenerating { AILoadingView() }
            }
            .frame(width: 280)
            .frame(minHeight: 420, maxHeight: .infinity, alignment: .top)
            .background(isHighContrast ? Color(UIColor.systemBackground) : Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(isHighContrast ? 4 : 24)
            .overlay(
                RoundedRectangle(cornerRadius: isHighContrast ? 4 : 24)
                    .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 3)
            )
            .shadow(color: .black.opacity(isHighContrast ? 0 : 0.06), radius: 12, x: 0, y: 6)
        }
    }
    // MARK: - 6. COMPATIBLE LOADING VIEW
    struct AILoadingView: View {
        @State private var isAnimating = false
        var body: some View {
            ZStack {
                VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.title).foregroundColor(.orange)
                        .scaleEffect(isAnimating ? 1.2 : 0.9)
                    Text("AI is thinking...").font(.system(size: 12)).foregroundColor(.secondary)
                }
            }
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { isAnimating = true }
            }
        }
    }

    struct VisualEffectBlur: UIViewRepresentable {
        var blurStyle: UIBlurEffect.Style
        func makeUIView(context: Context) -> UIVisualEffectView { UIVisualEffectView(effect: UIBlurEffect(style: blurStyle)) }
        func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
    }
}

