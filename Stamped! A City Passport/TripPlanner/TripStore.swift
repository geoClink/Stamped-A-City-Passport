//
//  TripStore.swift
//  Stamped! A City Passport
//
//  Saves the user's planned trips on this device and in iCloud.
//  Follows the same pattern as GlobalProgressManager's custom places:
//  JSON data in the app-group UserDefaults plus iCloud key-value storage,
//  and the latest saved list wins when another device changes it.
//

import Foundation
import Combine
import SwiftUI // for Array.move(fromOffsets:toOffset:), the helper behind .onMove

@MainActor
final class TripStore: ObservableObject {
    static let shared = TripStore()

    /// Every trip, in the order they were created.
    @Published private(set) var trips: [Trip] = [] {
        didSet { save() }
    }

    private let tripsKey = "GlobalTripsKey"
    private let defaults: UserDefaults
    /// nil in unit tests, so tests never touch the real iCloud store.
    private let iCloud: NSUbiquitousKeyValueStore?

    private convenience init() {
        self.init(
            defaults: UserDefaults(suiteName: "group.stamped.passport") ?? .standard,
            iCloud: .default
        )
    }

    /// Tests pass their own UserDefaults suite and no iCloud store.
    init(defaults: UserDefaults, iCloud: NSUbiquitousKeyValueStore?) {
        self.defaults = defaults
        self.iCloud = iCloud

        // Saved as JSON data, since UserDefaults and iCloud can't store custom structs directly
        if let data = defaults.data(forKey: tripsKey),
           let saved = try? JSONDecoder().decode([Trip].self, from: data) {
            self.trips = saved
        }

        guard let iCloud else { return }

        // Pull latest from iCloud then merge into local
        iCloud.synchronize()
        mergeFromICloud()

        // React to changes pushed from another device
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloud,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.mergeFromICloud() }
        }
    }

    // MARK: - iCloud Merge

    /// People delete and reorder as well as add, so the latest saved list wins
    /// (same rule as the wishlist and custom places).
    private func mergeFromICloud() {
        if let data = iCloud?.data(forKey: tripsKey),
           let cloudTrips = try? JSONDecoder().decode([Trip].self, from: data),
           cloudTrips != trips {
            trips = cloudTrips
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(trips) else { return }
        defaults.set(data, forKey: tripsKey)
        iCloud?.set(data, forKey: tripsKey)
    }

    // MARK: - Reading

    func trips(in cityName: String) -> [Trip] {
        trips.filter { $0.cityName == cityName }
    }

    func trip(withID tripID: String) -> Trip? {
        trips.first { $0.id == tripID }
    }

    // MARK: - Trips

    /// Creates a trip with one empty day and returns it.
    @discardableResult
    func createTrip(name: String, cityName: String, startDate: Date? = nil) -> Trip {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trip = Trip(
            name: trimmed.isEmpty ? "\(cityName) Trip" : trimmed,
            cityName: cityName,
            startDate: startDate
        )
        trips.append(trip)
        return trip
    }

    func deleteTrip(_ tripID: String) {
        trips.removeAll { $0.id == tripID }
    }

    func renameTrip(_ tripID: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        updateTrip(tripID) { $0.name = trimmed }
    }

    func setStartDate(_ date: Date?, for tripID: String) {
        updateTrip(tripID) { $0.startDate = date }
    }

    // MARK: - Days

    /// Adds an empty day to the end of the trip and returns its id.
    @discardableResult
    func addDay(to tripID: String) -> String? {
        let day = TripDay()
        var added = false
        updateTrip(tripID) {
            $0.days.append(day)
            added = true
        }
        return added ? day.id : nil
    }

    /// Removes a day and its stops. A trip always keeps at least one day.
    func removeDay(_ dayID: String, from tripID: String) {
        updateTrip(tripID) { trip in
            guard trip.days.count > 1 else { return }
            trip.days.removeAll { $0.id == dayID }
        }
    }

    // MARK: - Stops

    /// Adds a landmark or saved place to the end of a day and returns the new stop's id.
    @discardableResult
    func addStop(_ kind: TripStop.Kind, toDay dayID: String, in tripID: String) -> String? {
        let stop = TripStop(kind: kind)
        var added = false
        updateDay(dayID, in: tripID) {
            $0.stops.append(stop)
            added = true
        }
        return added ? stop.id : nil
    }

    func removeStop(_ stopID: String, fromDay dayID: String, in tripID: String) {
        updateDay(dayID, in: tripID) { $0.stops.removeAll { $0.id == stopID } }
    }

    /// Reorders stops inside one day. The arguments match SwiftUI's `.onMove`.
    func moveStops(inDay dayID: String, in tripID: String, fromOffsets source: IndexSet, toOffset destination: Int) {
        updateDay(dayID, in: tripID) { $0.stops.move(fromOffsets: source, toOffset: destination) }
    }

    /// Moves a stop to another day (or another spot in the same day).
    /// With no `index` the stop goes to the end of the destination day.
    func moveStop(_ stopID: String, toDay destinationDayID: String, at index: Int? = nil, in tripID: String) {
        updateTrip(tripID) { trip in
            guard let fromDay = trip.days.firstIndex(where: { $0.stops.contains { $0.id == stopID } }),
                  let toDay = trip.days.firstIndex(where: { $0.id == destinationDayID }),
                  let fromIndex = trip.days[fromDay].stops.firstIndex(where: { $0.id == stopID })
            else { return }

            let stop = trip.days[fromDay].stops.remove(at: fromIndex)
            let destinationCount = trip.days[toDay].stops.count
            // Clamp so a stale index from the UI can't crash the insert
            let insertAt = min(max(index ?? destinationCount, 0), destinationCount)
            trip.days[toDay].stops.insert(stop, at: insertAt)
        }
    }

    /// Replaces a day's stops with the same stops in a new order (used by "Optimize route").
    func reorderStops(_ orderedStopIDs: [String], inDay dayID: String, in tripID: String) {
        updateDay(dayID, in: tripID) { day in
            let byID = Dictionary(uniqueKeysWithValues: day.stops.map { ($0.id, $0) })
            let reordered = orderedStopIDs.compactMap { byID[$0] }
            // Only apply it if it's the exact same set of stops, so nothing gets lost
            guard reordered.count == day.stops.count else { return }
            day.stops = reordered
        }
    }

    // MARK: - Helpers

    /// Edits one trip in place. Changing `trips` once means one save per change.
    private func updateTrip(_ tripID: String, _ change: (inout Trip) -> Void) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        var trip = trips[index]
        change(&trip)
        if trip != trips[index] {
            trips[index] = trip
        }
    }

    private func updateDay(_ dayID: String, in tripID: String, _ change: (inout TripDay) -> Void) {
        updateTrip(tripID) { trip in
            guard let dayIndex = trip.days.firstIndex(where: { $0.id == dayID }) else { return }
            change(&trip.days[dayIndex])
        }
    }
}
