//
//  CollegeListStore.swift
//  Stamped! A City Passport
//
//  "My College List": the campuses a prospective student is considering,
//  in the order they put them. Saved on this device and in iCloud the same
//  way TripStore saves trips: the app-group UserDefaults plus iCloud
//  key-value storage, and the latest saved list wins when another device
//  changes it (people remove and reorder schools as well as add them).
//
//  Campuses are saved by `CityLocation.City.rawValue` ("Duke University"),
//  as a plain string array, so a name an older or newer app doesn't know
//  is kept in the saved list and just not shown.
//

import Foundation
import Combine
import SwiftUI // for Array.move(fromOffsets:toOffset:), the helper behind .onMove

@MainActor
final class CollegeListStore: ObservableObject {
    static let shared = CollegeListStore()

    /// The saved campus names, in the user's order.
    @Published private(set) var campusNames: [String] = [] {
        didSet { save() }
    }

    private let listKey = "GlobalCollegeListKey"
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

        if let saved = defaults.array(forKey: listKey) as? [String] {
            self.campusNames = saved
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

    /// The latest saved list wins (same rule as trips and the wishlist).
    private func mergeFromICloud() {
        if let cloudNames = iCloud?.array(forKey: listKey) as? [String],
           cloudNames != campusNames {
            campusNames = cloudNames
        }
    }

    private func save() {
        defaults.set(campusNames, forKey: listKey)
        iCloud?.set(campusNames, forKey: listKey)
    }

    // MARK: - Reading

    /// The saved campuses this app knows, in the user's order.
    var campuses: [CityLocation.City] {
        campusNames.compactMap { CityLocation.City(rawValue: $0) }.filter(\.isCampus)
    }

    var isEmpty: Bool { campuses.isEmpty }

    func contains(_ campus: CityLocation.City) -> Bool {
        campusNames.contains(campus.rawValue)
    }

    // MARK: - Changing

    /// Adds a campus to the end of the list. Cities that aren't campuses, and
    /// campuses already on the list, are ignored.
    func add(_ campus: CityLocation.City) {
        guard campus.isCampus, !contains(campus) else { return }
        campusNames.append(campus.rawValue)
    }

    func remove(_ campus: CityLocation.City) {
        campusNames.removeAll { $0 == campus.rawValue }
    }

    /// Adds the campus if it isn't on the list, removes it if it is.
    func toggle(_ campus: CityLocation.City) {
        if contains(campus) {
            remove(campus)
        } else {
            add(campus)
        }
    }

    /// Removes campuses by their position in `campuses` (matches SwiftUI's `.onDelete`).
    func remove(atOffsets offsets: IndexSet) {
        let shown = campuses
        let names = Set(offsets.filter { shown.indices.contains($0) }.map { shown[$0].rawValue })
        campusNames.removeAll { names.contains($0) }
    }

    /// Reorders campuses by their position in `campuses` (matches SwiftUI's `.onMove`).
    /// Saved names this app doesn't know stay at the end.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var shown = campuses.map(\.rawValue)
        shown.move(fromOffsets: source, toOffset: destination)
        let hidden = campusNames.filter { !shown.contains($0) }
        campusNames = shown + hidden
    }
}
