//viewModel.city.details.languageInfo//
//  SwiftUIView.swift
//  Stamped
//
//  Created by George Clinkscales on 2/1/26.
//

import Foundation
import SwiftUI
import Combine
import Network

@MainActor
class CityDetailViewModel: ObservableObject {
    enum CurrencyMode: String {
        case live = "Live"
        case cached = "Cached"
        case offline = "Offline"
    }
    let city: CityLocation.City

    // MARK: - Published Properties
    @Published var selectedHomeCurrency: String = UserDefaults.standard.string(forKey: "user_home_currency") ?? "USD" {
        didSet { UserDefaults.standard.set(selectedHomeCurrency, forKey: "user_home_currency") }
    }
    @Published var userBaseAmount: String = "1"
    @Published var isSwapped: Bool = false
    @Published var completionDate: String = ""
    @Published var currencyStatusText: String = "" // single source of truth for UI status
    @Published var isFetchingRates: Bool = false
    @Published var currencyMode: CurrencyMode = .offline
    @Published var currencyUpdatedDate: Date? = nil
    @Published var currencyProvider: String? = nil

    // New: one-shot completion event flag (observed by the view to present celebration)
    @Published var didJustComplete: Bool = false

    // Current effective rates (starts as offlineRates)
    private var currentRates: [String: Double] = [:]

    // Track previous completion state so we only fire the event on the transition
    private var previouslyCompleted: Bool = false

    // MARK: - Private Dependencies
    private var progressManager = GlobalProgressManager.shared
    private var cancellables = Set<AnyCancellable>()

    // Network path monitor to observe connectivity changes
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "nw-monitor")

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
        self.currentRates = offlineRates
        loadInitialProgress()

        // Set an initial status based on current path (if available)
        if pathMonitor.currentPath.status == .satisfied {
            self.currencyStatusText = NSLocalizedString("checking.rates", comment: "Short status shown while fetching currency rates")
        } else {
            let offlineDate = DateComponents(calendar: Calendar.current, year: 2026, month: 3).date ?? Date()
            // Mirror previous offline placeholder but don't show Live
            self.updateCurrencyStatusText(date: offlineDate, mode: "Offline")
        }

        print("[CityDetailViewModel] Initialized for city:", city.name)

        // Observe progress changes to update UI and detect the completion transition
        progressManager.$visitedIDs
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                // Update any UI state that depends on progress
                self.updateCompletionStatus()
                self.objectWillChange.send()

                // Detect a one-shot completion event (transition from not-complete -> complete)
                self.detectCompletionTransition()
            }
            .store(in: &cancellables)

        // Start path monitor to react to connectivity changes immediately
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if path.status == .satisfied {
                    Task {
                        await self.fetchLiveRatesIfPossible()
                    }
                } else {
                    self.useCachedOrOfflineRates(status: "Offline")
                }
            }
        }
        pathMonitor.start(queue: pathQueue)

        // Try to fetch live rates at init
        Task {
            await fetchLiveRatesIfPossible()
        }
    }

    deinit {
        pathMonitor.cancel()
    }

    // MARK: - Completion detection
    private func detectCompletionTransition() {
        let currentlyCompleted = self.isCompleted
        if currentlyCompleted && !previouslyCompleted {
            // Just completed
            previouslyCompleted = true
            // Persist completion date and expose a one-shot flag for the view
            handleCompletion()
            self.didJustComplete = true
            print("[CityDetailViewModel] Detected completion for city: \(city.name)")
        } else if !currentlyCompleted {
            // Reset flag so we can fire again if user resets progress and completes again
            previouslyCompleted = false
            self.didJustComplete = false
        }
    }

    // MARK: - Public Methods

    public func refreshRates() async {
        // allow callers (UI) to trigger a refresh; avoid overlapping fetches
        guard !isFetchingRates else { return }
        await fetchLiveRatesIfPossible()
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
    // Available offline currencies (keys of the offlineRates map)
    var availableCurrencies: [String] {
        return Array(currentRates.keys).sorted()
    }
    
    func convertAmount(_ amount: String) -> String {
        // Parse user input in a locale-aware way
        let inputFormatter = NumberFormatter()
        inputFormatter.numberStyle = .decimal
        inputFormatter.locale = Locale.current

        // Try direct parse first; fall back to replacing commas with dots for legacy inputs
        var numericValue: Double?
        if let number = inputFormatter.number(from: amount) {
            numericValue = number.doubleValue
        } else {
            let fallback = amount.replacingOccurrences(of: ",", with: ".")
            numericValue = Double(fallback)
        }

        guard let value = numericValue,
              let homeRate = currentRates[selectedHomeCurrency],
              let localRate = currentRates[city.details.currencyCode] else { return "--" }

        // Convert: if not swapped => home -> local, if swapped => local -> home
        let convertedValue = isSwapped ? (value / localRate) * homeRate : (value / homeRate) * localRate

        // Decide output currency code to format properly
        let outputCurrencyCode = isSwapped ? selectedHomeCurrency : city.details.currencyCode
        let fractionDigits = decimalFractionDigits(for: outputCurrencyCode)

        let outputFormatter = NumberFormatter()
        outputFormatter.numberStyle = .currency
        outputFormatter.currencyCode = outputCurrencyCode
        outputFormatter.minimumFractionDigits = fractionDigits
        outputFormatter.maximumFractionDigits = fractionDigits
        outputFormatter.locale = Locale.current
        outputFormatter.usesGroupingSeparator = true

        return outputFormatter.string(from: NSNumber(value: convertedValue)) ?? "--"
    }

    // Helper to pick fraction digits for a currency (common currencies only; fallback 2)
    private func decimalFractionDigits(for currencyCode: String) -> Int {
        let zeroFraction: Set<String> = ["JPY", "KRW"]
        let threeFraction: Set<String> = ["BHD", "IQD", "JOD", "KWD", "OMR", "TND"]
        if zeroFraction.contains(currencyCode) { return 0 }
        if threeFraction.contains(currencyCode) { return 3 }
        return 2
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
    
    // MARK: - Live Rates Fetching
    
    private struct RatesResponse: Codable {
        let rates: [String: Double]
    }
    
    // frankfurter.app — free, no API key, reliable
    private let ratesURL = URL(string: "https://api.frankfurter.app/latest?from=USD")!

    private func fetchLiveRatesIfPossible() async {
        guard !isFetchingRates else { return }

        // Serve from cache if less than 1 hour old
        if let cachedDate = UserDefaults.standard.object(forKey: "currency_rates_date") as? Date,
           Date().timeIntervalSince(cachedDate) < 3600,
           let cachedRates = loadCachedRates() {
            self.currentRates = cachedRates
            self.updateCurrencyStatusText(date: cachedDate, mode: "Cached")
            return
        }

        guard pathMonitor.currentPath.status == .satisfied else {
            useCachedOrOfflineRates(status: "Offline")
            return
        }

        isFetchingRates = true
        DispatchQueue.main.async { self.currencyStatusText = NSLocalizedString("checking.rates", comment: "Short status shown while fetching currency rates") }
        defer { isFetchingRates = false }

        var request = URLRequest(url: ratesURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(RatesResponse.self, from: data)
            // USD isn't in the response (it's the base), so add it manually
            var rates = response.rates
            rates["USD"] = 1.0
            self.currentRates = rates
            self.saveRatesToCache(rates: rates)
            self.updateCurrencyStatusText(date: Date(), mode: "Live")
            print("[Currency] Live rates fetched from frankfurter.app")
        } catch {
            print("[Currency] Live fetch failed:", error.localizedDescription)
            useCachedOrOfflineRates(status: "Cached")
        }
    }
    
    private func useCachedOrOfflineRates(status: String) {
        if let cachedRates = loadCachedRates(),
           let cachedDate = UserDefaults.standard.object(forKey: "currency_rates_date") as? Date {
            print("[Currency API] Using cached rates from", cachedDate)
            DispatchQueue.main.async {
                self.currentRates = cachedRates
                self.updateCurrencyStatusText(date: cachedDate, mode: "Cached")
            }
        } else {
            print("[Currency API] Using offline fallback rates.")
            DispatchQueue.main.async {
                self.currentRates = self.offlineRates
                // Use fixed offline date of March 2026 for initial text
                let offlineDate = DateComponents(calendar: Calendar.current, year: 2026, month: 3).date ?? Date()
                self.updateCurrencyStatusText(date: offlineDate, mode: "Offline")
            }
        }
    }
    
    private func saveRatesToCache(rates: [String: Double]) {
        if let encoded = try? JSONEncoder().encode(rates) {
            UserDefaults.standard.set(encoded, forKey: "cached_currency_rates")
            UserDefaults.standard.set(Date(), forKey: "currency_rates_date")
        }
    }
    
    private func loadCachedRates() -> [String: Double]? {
        guard let data = UserDefaults.standard.data(forKey: "cached_currency_rates") else { return nil }
        return try? JSONDecoder().decode([String: Double].self, from: data)
    }
    
    private func updateCurrencyStatusText(date: Date, mode: String) {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        // For very recent updates, show a friendly 'just now' instead of '0 seconds ago'
        let dateText: String
        if mode == "Offline" {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "LLLL yyyy"
            dateText = dateFormatter.string(from: date)
        } else if interval < 60 {
            // less than a minute
            dateText = "just now"
        } else {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            dateText = formatter.localizedString(for: date, relativeTo: now)
        }

        // Localize mode label and full status text
        let modeKey: String
        switch mode.lowercased() {
        case "live": modeKey = "mode.live"
        case "cached": modeKey = "mode.cached"
        default: modeKey = "mode.offline"
        }
        let localizedMode = NSLocalizedString(modeKey, comment: "Currency rate mode label (Live/Cached/Offline)")
        let format = NSLocalizedString("rates.updated", comment: "Status template: Rates updated <when> (<mode>)")
        self.currencyStatusText = String(format: format, dateText, localizedMode)

        // Update compact enum for UI indicators
        switch mode.lowercased() {
        case "live": self.currencyMode = .live
        case "cached": self.currencyMode = .cached
        default: self.currencyMode = .offline
        }
        // Update provider and timestamp for modal/details
        self.currencyUpdatedDate = date
        self.currencyProvider = ratesURL.host ?? "api.frankfurter.app"
    }
}
