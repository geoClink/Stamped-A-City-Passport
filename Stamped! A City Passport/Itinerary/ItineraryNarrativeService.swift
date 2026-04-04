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

    // MARK: - Generate Day Narrative
    func generateDayNarrative(dayNumber: Int, buildings: [Building]) async {
        // Fresh session per call — no context bleed
        let session = LanguageModelSession(model: .default)
        let buildingNames = buildings.map { $0.name }.joined(separator: ", ")
        let styles = Set(buildings.map { $0.buildingStyle }).joined(separator: ", ")

        let prompt = """
        Write 2 sentences introducing Day \(dayNumber) of an architectural tour.
        Stops: \(buildingNames). Styles: \(styles).
        Travel guide tone. No bullet points.
        """

        do {
            let response = try await session.respond(to: prompt)
            let content = response.content
            objectWillChange.send()
            dayNarratives[dayNumber] = content
            print("✅ Day \(dayNumber) narrative: \(content.prefix(60))...")
        } catch {
            print("Apple Intelligence day narrative error: \(error)")
        }
    }

    // MARK: - Generate Stop Description
    func generateStopDescription(building: Building) async {
        // Fresh session per stop — prevents context overflow and echo
        let session = LanguageModelSession(model: .default)

        let prompt = """
        One sentence, max 15 words. Why visit \(building.name)? Built \(building.yearBuilt), \(building.buildingStyle) style. Be specific.
        """

        do {
            let response = try await session.respond(to: prompt)
            let content = response.content
            let bid = building.id
            objectWillChange.send()
            stopDescriptions[bid] = content
            print("✅ \(building.name): \(content.prefix(60))...")
        } catch {
            print("Apple Intelligence stop description error: \(error)")
        }
    }

    // MARK: - Generate Everything
    func generateAll(itinerary: [[PlannedStop]], buildings: [Building]) async {
        // Prevent double execution
        guard !isGenerating else {
            print("⚠️ generateAll called while already generating — skipping")
            return
        }

        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else {
            print("❌ Apple Intelligence not available: \(availability)")
            return
        }

        print("✅ Apple Intelligence starting generation")
        objectWillChange.send()
        isGenerating = true

        for (dayIndex, stops) in itinerary.enumerated() {
            let dayBuildings = stops.compactMap { stop in
                buildings.first { $0.id == stop.buildingID }
            }
            print("📅 Day \(dayIndex + 1) — \(dayBuildings.count) buildings")
            await generateDayNarrative(dayNumber: dayIndex + 1, buildings: dayBuildings)

            for building in dayBuildings {
                // Skip if already generated (handles city revisits)
                guard stopDescriptions[building.id] == nil else { continue }
                print("🏛️ \(building.name)")
                await generateStopDescription(building: building)
            }
        }

        objectWillChange.send()
        isGenerating = false
        print("✅ Done. Narratives: \(dayNarratives.count), Descriptions: \(stopDescriptions.count)")
    }
}
