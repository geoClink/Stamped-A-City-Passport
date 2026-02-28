//
//  SwiftUIView.swift
//  Stamped
//
//  Created by George Clinkscales on 2/1/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class CityDetailViewModel: ObservableObject {
    let city: CityLocation.City
    
    // MARK: - Published Properties
    @Published var selectedHomeCurrency: String = UserDefaults.standard.string(forKey: "user_home_currency") ?? "USD" {
        didSet { UserDefaults.standard.set(selectedHomeCurrency, forKey: "user_home_currency") }
    }
    @Published var userBaseAmount: String = "1"
    @Published var isSwapped: Bool = false
    @Published var completionDate: String = ""
    
    // MARK: - Private Dependencies
    private var progressManager = GlobalProgressManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private let offlineRates: [String: Double] = [
        "USD": 1.0, "EUR": 0.83, "GBP": 0.74, "JPY": 156.40,
        "CAD": 1.38, "AUD": 1.49, "MXN": 17.85, "CHF": 0.86,
        "CNY": 6.95, "HKD": 7.78, "INR": 89.40, "KRW": 1425.0,
        "SGD": 1.31, "THB": 34.20, "NZD": 1.68, "IDR": 16250.0,
        "AED": 3.67, "SAR": 3.75, "ILS": 3.58, "EGP": 48.20,
        "ZAR": 19.10, "KES": 152.00, "MAD": 9.95, "TRY": 34.80,
        "BRL": 5.35, "ARS": 1150.0, "PEN": 3.72, "CLP": 912.0, "CZK": 22.40
    ]

    // MARK: - Computed Properties
    var currencyText: String { city.buildings.first?.currency ?? "N/A" }
    var progress: Double { progressManager.getMastery(for: city.buildings).progress }
    var isCompleted: Bool { progress >= 1.0 }

    // MARK: - Initialization
    init(city: CityLocation.City) {
        self.city = city
        loadInitialProgress()
        
        progressManager.$visitedIDs
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateCompletionStatus()
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Mastery & Progress
    func getMastery(isHighContrast: Bool) -> (tier: String, color: Color, progress: Double, count: Int) {
        let base = progressManager.getMastery(for: city.buildings)
        // If high contrast is on, we ignore the tier color (Gold/Silver) for better legibility
        let displayColor = isHighContrast ? .primary : base.color
        return (base.tier, displayColor, base.progress, base.count)
    }

    func toggleVisited(for building: Building) {
        let isMarkingAsVisited = !progressManager.visitedIDs.contains(building.id)
        progressManager.toggleVisit(for: building.id, in: city.buildings)
        if isMarkingAsVisited { HapticManager.shared.trigger(.impact) }
    }

    func handleCompletion() {
        guard isCompleted else { return }
        let dateString = Date().formatted(date: .abbreviated, time: .omitted)
        self.completionDate = dateString
        UserDefaults.standard.set(dateString, forKey: "date_completed_\(city.name)")
    }

    // MARK: - Currency Conversion
    func convertAmount(_ amount: String) -> String {
        let sanitized = amount.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(sanitized),
              let homeRate = offlineRates[selectedHomeCurrency],
              let localRate = offlineRates[city.details.currencyCode] else { return "0.00" }
        
        let convertedValue = isSwapped ? (value / localRate) * homeRate : (value / homeRate) * localRate
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: convertedValue)) ?? "0.00"
    }

    // MARK: - Reset Logic
    enum ResetType { case none, quiz, passport, photos, everything }

    func resetProgress(for type: ResetType) {
        switch type {
        case .passport:
            resetTravelProgress()
        case .photos:
            resetCityPhotos()
        case .everything:
            resetTravelProgress()
            resetCityPhotos()
        default:
            break
        }
        self.objectWillChange.send()
    }

    private func resetTravelProgress() {
        for building in city.buildings {
            progressManager.visitedIDs.remove(building.id)
        }
        UserDefaults.standard.removeObject(forKey: "date_completed_\(city.name)")
        self.completionDate = ""
    }

    private func resetCityPhotos() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for landmark in city.buildings {
            let fileURL = documentsURL.appendingPathComponent("\(landmark.id).jpg")
            try? FileManager.default.removeItem(at: fileURL)
            progressManager.userImages[landmark.id] = nil
        }
    }

    func getConfirmationMessage(for type: ResetType) -> String {
        switch type {
        case .quiz: return "This will reset your high score for \(city.name)."
        case .passport: return "This will remove all visited landmarks and your stamp for this city."
        case .photos: return "This will delete all custom landmark photos and revert to originals."
        case .everything: return "This will wipe your scores, photos, and progress for \(city.name)."
        default: return ""
        }
    }

    private func loadInitialProgress() {
        self.completionDate = UserDefaults.standard.string(forKey: "date_completed_\(city.name)") ?? ""
    }

    private func updateCompletionStatus() {
        if !isCompleted {
            self.completionDate = ""
            UserDefaults.standard.removeObject(forKey: "date_completed_\(city.name)")
        }
    }
}
