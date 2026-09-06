//
//  ItineraryNarrativeService.swift
//  Stamped! A City Passport
//

import Foundation
import FoundationModels
import Combine
 
@available(iOS 26.0, *)
@MainActor
final class ItineraryNarrativeService: ObservableObject {
    @Published var dayNarratives: [Int: String] = [:]
    @Published var stopDescriptions: [String: String] = [:]
    @Published var isGenerating = false
    @Published var generationFailed = false
 
    private var currentCityKey: String = ""
 
    // MARK: - Cache keys
    private func narrativeCacheKey(_ city: String) -> String {
        "narratives_\(city.lowercased().replacingOccurrences(of: " ", with: "_"))"
    }
    private func descriptionCacheKey(_ city: String) -> String {
        "descriptions_\(city.lowercased().replacingOccurrences(of: " ", with: "_"))"
    }
 
    // MARK: - Load from cache
    private func loadCache(for city: String) -> Bool {
        let nKey = narrativeCacheKey(city)
        let dKey = descriptionCacheKey(city)
 
        guard let nData = UserDefaults.standard.data(forKey: nKey),
              let dData = UserDefaults.standard.data(forKey: dKey),
              let narratives = try? JSONDecoder().decode([Int: String].self, from: nData),
              let descriptions = try? JSONDecoder().decode([String: String].self, from: dData),
              !narratives.isEmpty
        else { return false }
 
        dayNarratives = narratives
        stopDescriptions = descriptions
        print("✅ Loaded narratives from cache for \(city)")
        return true
    }
 
    // MARK: - Save to cache
    private func saveCache(for city: String) {
        if let nData = try? JSONEncoder().encode(dayNarratives) {
            UserDefaults.standard.set(nData, forKey: narrativeCacheKey(city))
        }
        if let dData = try? JSONEncoder().encode(stopDescriptions) {
            UserDefaults.standard.set(dData, forKey: descriptionCacheKey(city))
        }
        print("✅ Cached narratives for \(city)")
    }
 
    // MARK: - Clear cache
    func clearCache(for city: String) {
        UserDefaults.standard.removeObject(forKey: narrativeCacheKey(city))
        UserDefaults.standard.removeObject(forKey: descriptionCacheKey(city))
        dayNarratives = [:]
        stopDescriptions = [:]
        currentCityKey = ""
    }
 
    // MARK: - Generate Day Narrative (streaming)
    private func generateDayNarrative(dayNumber: Int, buildings: [Building]) async {
        let session = LanguageModelSession(model: .default)
        let buildingNames = buildings.map { $0.name }.joined(separator: ", ")
        let styles = Set(buildings.map { $0.buildingStyle }).joined(separator: ", ")

        let prompt = """
        Write 2 sentences introducing Day \(dayNumber) of an architectural tour.
        Stops: \(buildingNames). Styles: \(styles).
        Travel guide tone. No bullet points.
        """

        do {
            // Stream the response so text appears word-by-word in the UI
            dayNarratives[dayNumber] = ""
            for try await partial in session.streamResponse(to: prompt) {
                dayNarratives[dayNumber] = partial.content
            }
            print("✅ Day \(dayNumber) narrative ready")
        } catch {
            print("⚠️ Day \(dayNumber) narrative error: \(error)")
        }
    }

    // MARK: - Generate Stop Description (streaming)
    private func generateStopDescription(building: Building) async {
        guard stopDescriptions[building.id] == nil else { return }

        let session = LanguageModelSession(model: .default)
        let prompt = """
        One sentence, max 15 words. Why visit \(building.name)? Built \(building.yearBuilt), \(building.buildingStyle) style. Be specific.
        """

        do {
            stopDescriptions[building.id] = ""
            for try await partial in session.streamResponse(to: prompt) {
                stopDescriptions[building.id] = partial.content
            }
        } catch {
            print("⚠️ Stop description error for \(building.name): \(error)")
        }
    }
 
    // MARK: - Generate Everything
    func generateAll(itinerary: [[PlannedStop]], buildings: [Building], cityKey: String) async {
        // Bulletproof double-call prevention
        guard !isGenerating else {
            print("⚠️ Already generating — skipping duplicate call")
            return
        }
 
        // Same city already loaded in memory — skip
        if currentCityKey == cityKey && !dayNarratives.isEmpty {
            print("✅ Narratives already in memory for \(cityKey)")
            return
        }
 
        // Try loading from cache
        if loadCache(for: cityKey) {
            currentCityKey = cityKey
            return
        }
 
        // Check Apple Intelligence availability
        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else {
            print("❌ Apple Intelligence not available: \(availability)")
            objectWillChange.send()
            generationFailed = true
            return
        }
 
        // Reset and start
        currentCityKey = cityKey
        generationFailed = false
        dayNarratives = [:]
        stopDescriptions = [:]
        objectWillChange.send()
        isGenerating = true
 
        print("✅ Starting Apple Intelligence generation for \(cityKey)")
 
        for (dayIndex, stops) in itinerary.enumerated() {
            let dayBuildings = stops.compactMap { stop in
                buildings.first { $0.id == stop.buildingID }
            }
            await generateDayNarrative(dayNumber: dayIndex + 1, buildings: dayBuildings)
            for building in dayBuildings {
                await generateStopDescription(building: building)
            }
        }
 
        saveCache(for: cityKey)
 
        objectWillChange.send()
        isGenerating = false
        print("✅ Done — \(dayNarratives.count) narratives, \(stopDescriptions.count) descriptions")
    }
}
