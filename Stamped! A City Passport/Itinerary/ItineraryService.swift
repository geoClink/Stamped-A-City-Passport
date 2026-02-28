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

// MARK: - 2. VIEW MODEL
@MainActor
class ItineraryStep: Identifiable, ObservableObject {
    let id = UUID()
    let timeSlot: String
    let building: Building
    
    @Published var curatedActivity: String
    @Published var icon: String
    @Published var foodSuggestion: String
    @Published var isGenerating: Bool = false
    
    var isFinalStop: Bool = false

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
                return
            }
        }
        #endif
        
        try? await Task.sleep(nanoseconds: 600_000_000)
        self.curatedActivity = "\(distanceHint) Admire the \(building.buildingStyle) details at \(building.address)."
        self.icon = "mappin.and.ellipse"
        self.foodSuggestion = building.foodSpots.randomElement() ?? "Local Favorite"
        self.isGenerating = false
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
                let mealType = time.contains("09:00") ? "breakfast" : "lunch or dinner"
                let prompt = "Building: \(building.name). Location: \(hint). Time: \(time). Food: \(building.foodSpots.joined(separator: ", ")). Task: 2-sentence visitor guide. Pick the best \(mealType)."
                
                let response = try await session.respond(to: prompt)
                return AICuratedContent(activity: response.content, icon: "sparkles", food: building.foodSpots.randomElement() ?? "Dining")
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
    
        @AppStorage("high_contrast_mode") var manualHighContrast = false
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
            .refreshable { await loadFromRegistry() }
            
            Spacer()
        }
        .task(id: selectedDay) {
            await loadFromRegistry()
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
            
            Button(action: {
                HapticManager.shared.trigger(.selection)
                Task { await loadFromRegistry() }
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

    private func loadFromRegistry() async {
        isRefreshingAll = true
        let buildings = BuildingRegistry.getBuildings(for: city, day: selectedDay)
        
        let steps = buildings.enumerated().map { index, b in
            let time = ["09:00 AM", "12:00 PM", "03:00 PM", "07:00 PM"][min(index, 3)]
            let isFinal = (index == buildings.count - 1)
            return ItineraryStep(timeSlot: time, building: b, isFinal: isFinal)
        }
        
        self.itinerary = steps
        
        for i in 0..<itinerary.count {
            let prevZip = i > 0 ? itinerary[i-1].building.address : nil
            await itinerary[i].generateAIContent(previousZip: prevZip)
        }
        isRefreshingAll = false
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
