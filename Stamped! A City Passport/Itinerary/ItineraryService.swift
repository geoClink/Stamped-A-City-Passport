//
//  File.swift
//  Stamped
//
//  Created by George Clinkscales on 2/10/26.

//import SwiftUI
//import Foundation
//import Combine
//
//// MARK: - Persistence Models
//
//struct PersistedItineraryStep: Codable {
//    let timeSlot: String
//    let buildingID: String
//    let curatedActivity: String
//    let icon: String
//    let foodSuggestion: String
//    let isFinalStop: Bool
//}
//
//struct PersistedItinerary: Codable {
//    let cityID: String
//    let day: Int
//    let steps: [PersistedItineraryStep]
//}
//
//// MARK: - 2. VIEW MODEL
//@MainActor
//class ItineraryStep: Identifiable, ObservableObject {
//    let id = UUID()
//    let timeSlot: String
//    let building: Building
//
//    @Published var curatedActivity: String
//    @Published var icon: String
//    @Published var foodSuggestion: String
//    @Published var isGenerating: Bool = false
//
//    var isFinalStop: Bool = false
//
//    var timeContextIcon: String {
//        if isFinalStop { return "sunset.fill" }
//
//        let time = timeSlot.uppercased()
//        if time.contains("09:00") { return "sunrise.fill" }
//        if time.contains("12:00") || time.contains("03:00") { return "sun.max.fill" }
//        return "mappin.and.ellipse"
//    }
//
//    init(timeSlot: String, building: Building, curatedActivity: String? = nil, icon: String = "building.columns", foodSuggestion: String? = nil, isFinal: Bool = false) {
//        self.building = building
//        self.timeSlot = timeSlot
//        self.isFinalStop = isFinal
//        self.curatedActivity = curatedActivity ?? "Explore the unique architecture and atmosphere at \(building.address)."
//        self.icon = icon
//        self.foodSuggestion = foodSuggestion ?? building.foodSpots.first ?? "Nearby Dining"
//    }
//}
//
//// MARK: - 4. THE MAIN VIEW
//struct CityItineraryView: View {
//    let city: CityLocation.City
//    @State private var selectedDay: Int = 1
//    @State private var itinerary: [ItineraryStep] = []
//
//    @AppStorage("high_contrast_mode") var manualHighContrast = false
//    @AppStorage("debug_force_mock_ai") var debugForceMockAI: Bool = false
//    @Environment(\.colorSchemeContrast) private var systemContrast
//
//    private var isHighContrast: Bool {
//        manualHighContrast || systemContrast == .increased
//    }
//
//    private var itineraryFileURL: URL {
//        let fileName = "itinerary_\(city.id)_day\(selectedDay).json"
//        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
//        let dir = appSupportDir.appendingPathComponent("Itineraries", isDirectory: true)
//        if !FileManager.default.fileExists(atPath: dir.path) {
//            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
//        }
//        return dir.appendingPathComponent(fileName)
//    }
//
//    var body: some View {
//         VStack(alignment: .leading, spacing: 0) {
//             headerSection
//             dayPicker
//             
//             ScrollView(.horizontal, showsIndicators: false) {
//                 HStack(spacing: 20) {
//                     ForEach(itinerary) { step in
//                         ItineraryCard(step: step)
//                             .id("\(selectedDay)-\(step.building.id)")
//                     }
//                 }
//                 .padding(.horizontal, 25)
//             }
//             
//             Spacer()
//         }
//         .onAppear {
//             Task {
//                 await loadOrGenerateItinerary()
//             }
//         }
//    }
//    
//    private var headerSection: some View {
//        HStack(alignment: .top) {
//            VStack(alignment: .leading, spacing: 4) {
//                Text("AI CURATED EXPLORATION")
//                    .font(.system(size: 10, weight: .black)).tracking(2)
//                    .foregroundColor(isHighContrast ? .primary : .orange)
//                
//                Text(city.name)
//                    .font(.system(size: 34, weight: .bold, design: .serif))
//                    .fontWeight(isHighContrast ? .black : .bold)
//            }
//            
//            Spacer()
//            
//            // Debug: Mock AI toggle for Simulator testing (no effect here)
//            Button(action: {
//                debugForceMockAI.toggle()
//            }) {
//                Text(debugForceMockAI ? "Mock AI: ON" : "Mock AI: OFF")
//                    .font(.system(size: 12, weight: .semibold))
//                    .padding(6)
//                    .background(debugForceMockAI ? Color.green.opacity(0.15) : Color.gray.opacity(0.08))
//                    .cornerRadius(8)
//            }
//            
//            Button(action: {
//                Task {
//                    await regenerateItinerary()
//                }
//            }) {
//                if #available(iOS 17.0, *) {
//                    Image(systemName: "arrow.clockwise.circle.fill")
//                        .font(.system(size: 30))
//                        .foregroundColor(isHighContrast ? .primary : Color.adventureOrange.opacity(0.8))
//                } else {
//                    Image(systemName: "arrow.clockwise.circle")
//                        .font(.system(size: 30, weight: .bold))
//                        .foregroundColor(isHighContrast ? .primary : .orange)
//                }
//            }
//        }
//        .padding(.horizontal, 25)
//        .padding(.vertical, 20)
//    }
//    
//    private var dayPicker: some View {
//        HStack(spacing: 0) {
//            ForEach(1...3, id: \.self) { day in
//                Button(action: {
//                    selectedDay = day
//                    Task {
//                        await loadOrGenerateItinerary()
//                    }
//                }) {
//                    Text("DAY \(day)")
//                        .font(.system(size: 12, weight: .black))
//                        .frame(maxWidth: .infinity)
//                        .padding(.vertical, 12)
//                        .background(selectedDay == day ? (isHighContrast ? .primary : .orange) : Color.clear)
//                        .foregroundColor(selectedDay == day ? (isHighContrast ? Color(UIColor.systemBackground) : .white) : .primary)
//                }
//                .overlay(
//                    HStack {
//                        if day < 3 && isHighContrast {
//                            Spacer()
//                            Rectangle().fill(Color.primary).frame(width: 2)
//                        }
//                    }
//                )
//            }
//        }
//        .background(isHighContrast ? Color(UIColor.systemBackground) : Color.orange.opacity(0.1))
//        .cornerRadius(isHighContrast ? 4 : 12)
//        .overlay(
//            RoundedRectangle(cornerRadius: isHighContrast ? 4 : 12)
//                .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 3)
//        )
//        .padding(.horizontal, 25)
//        .padding(.bottom, 30)
//    }
//
//    // Helper: find a Building by id across enum-keyed `data` only (safe, compile-time API).
//    private func buildingByID(_ id: String) -> Building? {
//        return BuildingRegistry.getBuilding(by: id)
//    }
//    
//    // Helper: Get all buildings for current city and day
//    private func buildingsForCity() -> [Building] {
//        BuildingRegistry.getBuildings(for: city, day: selectedDay)
//    }
//
//    // MARK: - Persistence
//    
//    private func saveItinerary(_ steps: [ItineraryStep]) {
//        let persistedSteps = steps.map { step in
//            PersistedItineraryStep(timeSlot: step.timeSlot,
//                                   buildingID: step.building.id,
//                                   curatedActivity: step.curatedActivity,
//                                   icon: step.icon,
//                                   foodSuggestion: step.foodSuggestion,
//                                   isFinalStop: step.isFinalStop)
//        }
//        
//        let persisted = PersistedItinerary(cityID: city.id, day: selectedDay, steps: persistedSteps)
//        
//        do {
//            let data = try JSONEncoder().encode(persisted)
//            try data.write(to: itineraryFileURL, options: [.atomic])
//        } catch {
//            print("Failed to save itinerary: \(error)")
//        }
//    }
//    
//    private func loadSavedItinerary() -> [ItineraryStep]? {
//        guard FileManager.default.fileExists(atPath: itineraryFileURL.path),
//              let data = try? Data(contentsOf: itineraryFileURL) else {
//            return nil
//        }
//        do {
//            let decoded = try JSONDecoder().decode(PersistedItinerary.self, from: data)
//            guard decoded.cityID == city.id, decoded.day == selectedDay else {
//                return nil
//            }
//            
//            // Map persisted steps to ItineraryStep objects
//            var steps: [ItineraryStep] = []
//            for pStep in decoded.steps {
//                if let building = buildingByID(pStep.buildingID) {
//                    let step = ItineraryStep(timeSlot: pStep.timeSlot,
//                                             building: building,
//                                             curatedActivity: pStep.curatedActivity,
//                                             icon: pStep.icon,
//                                             foodSuggestion: pStep.foodSuggestion,
//                                             isFinal: pStep.isFinalStop)
//                    steps.append(step)
//                }
//            }
//            return steps.isEmpty ? nil : steps
//        } catch {
//            print("Failed to load itinerary: \(error)")
//            return nil
//        }
//    }
//    
//    // MARK: - Itinerary Generation
//    
//    private func generateItinerary() async -> [ItineraryStep] {
//        let buildings = buildingsForCity()
//        guard !buildings.isEmpty else {
//            return []
//        }
//        
//        // Use ItineraryPlanner to cluster buildings into 3 days
//        // ItineraryPlanner.planMultiDay returns [[PlannedStop]]
//        let multiDayClusters = ItineraryPlanner.planMultiDay(buildings: buildings, days: 3)
//        guard selectedDay-1 < multiDayClusters.count else {
//            return []
//        }
//        
//        let dayStops = multiDayClusters[selectedDay - 1]
//        
//        var steps: [ItineraryStep] = []
//        
//        for (index, stop) in dayStops.enumerated() {
//            // Look up the Building instance by stop.buildingID
//            guard let building = buildingByID(stop.buildingID) else {
//                // If building not found, skip this stop
//                continue
//            }
//            let timeHour = 9 + index * 2
//            let timeLabel = String(format: "%02d:00", timeHour)
//            let isFinal = (index == dayStops.count - 1)
//            
//            let curatedDescription: String
//            
//            if debugForceMockAI {
//                // Use a fixed mock description
//                curatedDescription = "Enjoy a delightful stop at \(building.name), rich with local flavor."
//            }
//            else {
//                // Use FoundationModels if available and iOS 26+, else fallback
//                #if canImport(FoundationModels)
//                if #available(iOS 26.0, *) {
//                    // TODO: Placeholder async call to FoundationModels generate description
//                    // Since direct usage is stubbed out, we fallback for now
//                    curatedDescription = "Experience the charm and history of \(building.name) during your visit."
//                } else {
//                    curatedDescription = "Discover the charm of \(building.name), a fine example of \(building.buildingStyle) style."
//                }
//                #else
//                curatedDescription = "Discover the charm of \(building.name), a fine example of \(building.buildingStyle) style."
//                #endif
//            }
//            
//            let step = ItineraryStep(timeSlot: timeLabel,
//                                     building: building,
//                                     curatedActivity: curatedDescription,
//                                     icon: "building.columns",
//                                     foodSuggestion: building.foodSpots.first ?? "Nearby Dining",
//                                     isFinal: isFinal)
//            steps.append(step)
//        }
//        
//        return steps
//    }
//    
//    private func loadOrGenerateItinerary() async {
//        if let saved = loadSavedItinerary() {
//            itinerary = saved
//        } else {
//            let generated = await generateItinerary()
//            itinerary = generated
//            saveItinerary(generated)
//        }
//    }
//    
//    private func regenerateItinerary() async {
//        // Remove saved file if exists
//        if FileManager.default.fileExists(atPath: itineraryFileURL.path) {
//            try? FileManager.default.removeItem(at: itineraryFileURL)
//        }
//        let generated = await generateItinerary()
//        itinerary = generated
//        saveItinerary(generated)
//    }
//
//    // MARK: - 5. THE CARD VIEW
//    struct ItineraryCard: View {
//        @ObservedObject var step: ItineraryStep
//        
//        @AppStorage("high_contrast_mode") var manualHighContrast = false
//        @Environment(\.colorSchemeContrast) private var systemContrast
//        private var isHighContrast: Bool { manualHighContrast || systemContrast == .increased }
//        private var brandColor: Color { isHighContrast ? .primary : .orange }
//        @Environment(\.colorScheme) var colorScheme
//
//        var body: some View {
//            ZStack {
//                VStack(alignment: .leading, spacing: 16) {
//                    HStack {
//                        Text(step.timeSlot)
//                            .font(.caption.bold().monospaced())
//                            .foregroundColor(brandColor)
//                        Spacer()
//                        Image(systemName: step.timeContextIcon)
//                            .symbolRenderingMode(isHighContrast ? .monochrome : .multicolor)
//                            .font(.system(size: 18, weight: .semibold))
//                            .foregroundColor(isHighContrast ? .primary : .orange)
//                    }
//                    
//                    VStack(alignment: .leading, spacing: 2) {
//                        Text(step.building.name)
//                            .font(.headline)
//                            .fontWeight(isHighContrast ? .black : .bold)
//                            .lineLimit(2)
//                        Text(step.building.buildingStyle.uppercased())
//                            .font(.system(size: 9, weight: .heavy))
//                            .foregroundColor(isHighContrast ? .primary : .secondary)
//                    }
//                    
//                    Text(step.curatedActivity)
//                        .font(.subheadline)
//                        .fontWeight(isHighContrast ? .medium : .regular)
//                        .foregroundColor(.primary)
//                        .lineSpacing(3)
//                        .fixedSize(horizontal: false, vertical: true)
//                    
//                    Spacer(minLength: 10)
//                    
//                    Divider()
//                        .background(isHighContrast ? Color.primary : Color.gray.opacity(0.2))
//                    
//                    HStack {
//                        VStack(alignment: .leading, spacing: 4) {
//                            Text("RECOMMENDED REFUEL")
//                                .font(.system(size: 9, weight: .black))
//                                .foregroundColor(isHighContrast ? .primary : .secondary)
//                            Text(step.foodSuggestion)
//                                .font(.subheadline.bold())
//                                .lineLimit(5)
//                        }
//                        Spacer()
//                        
//                        Button(action: {
//                            // No dynamic regeneration; button does nothing now
//                        }) {
//                            Image(systemName: "fork.knife")
//                                .font(.system(size: 14, weight: .bold))
//                                .foregroundColor((isHighContrast && colorScheme != .dark) ? .white : (isHighContrast ? .primary : .orange))
//                                .padding(10)
//                                .background(
//                                    isHighContrast
//                                    ? (colorScheme == .dark ? Color.white.opacity(0.2) : Color.black)
//                                    : Color.orange.opacity(0.1)
//                                )
//                                .clipShape(
//                                    RoundedRectangle(cornerRadius: isHighContrast ? 4 : 20)
//                                )
//                        }
//                    }
//                }
//                .padding(24)
//                .redacted(reason: [])
//            }
//            .frame(width: 280)
//            .frame(minHeight: 420, maxHeight: .infinity, alignment: .top)
//            .background(isHighContrast ? Color(UIColor.systemBackground) : Color(UIColor.secondarySystemGroupedBackground))
//            .cornerRadius(isHighContrast ? 4 : 24)
//            .overlay(
//                RoundedRectangle(cornerRadius: isHighContrast ? 4 : 24)
//                    .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 3)
//            )
//            .shadow(color: .black.opacity(isHighContrast ? 0 : 0.06), radius: 12, x: 0, y: 6)
//        }
//    }
//}
