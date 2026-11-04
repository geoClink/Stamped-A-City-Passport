//
//  CollegeListStore.swift
//  Stamped! A City Passport
//
//  "My College List": the campuses a prospective student is considering,
//  in the order they put them. Saved on this device and in iCloud the same
//  way TripStore saves trips: the app-group UserDefaults plus iCloud
//  key-value storage. Since 2.10 another device's changes are merged school
//  by school (see ICloudListMerge): a school added on either device is kept,
//  a removal sticks, and the order from the latest reorder wins.
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

    /// When each campus was last added or removed (and the last reorder), for merging.
    private var changes: ListChangeLog = [:]

    private let listKey = "GlobalCollegeListKey"
    private let changesKey = "GlobalCollegeListChangesKey"
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
        // Lists saved before 2.10 have no log yet; they're simply kept
        changes = ICloudListMerge.decodeLog(defaults.data(forKey: changesKey))

        guard let iCloud else { return }

        // Pull latest from iCloud then merge into local
        iCloud.synchronize()
        mergeFromICloud()

        // React to changes pushed from another device
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloud,
            queue: .main
        ) { [weak self] notification in
            let accountChanged = ICloudListMerge.isAccountChange(notification)
            Task { @MainActor [weak self] in self?.mergeFromICloud(accountChanged: accountChanged) }
        }
    }

    // MARK: - iCloud Merge

    private func mergeFromICloud(accountChanged: Bool = false) {
        guard let iCloud else { return }
        mergeCloud(
            names: iCloud.array(forKey: listKey) as? [String],
            changesData: iCloud.data(forKey: changesKey),
            accountChanged: accountChanged
        )
    }

    /// Merges iCloud's list into this device's, then saves the result back so
    /// iCloud gets any schools only this device had. Not private so tests can
    /// pass iCloud's data in. Same steps as TripStore.mergeCloud.
    func mergeCloud(names cloudNames: [String]?, changesData: Data?, accountChanged: Bool = false) {
        let cloudChanges = ICloudListMerge.decodeLog(changesData)

        guard let cloudNames else {
            // Nothing in iCloud yet: share this device's list
            if !campusNames.isEmpty || !changes.isEmpty { save() }
            return
        }

        if accountChanged {
            changes = cloudChanges
            campusNames = cloudNames
            return
        }

        let merged = ICloudListMerge.merge(
            local: campusNames, localLog: changes,
            cloud: cloudNames, cloudLog: cloudChanges,
            id: { $0 }
        )
        changes = merged.log
        if merged.items != campusNames {
            campusNames = merged.items // saves via didSet
        } else if merged.items != cloudNames || merged.log != cloudChanges {
            save()
        }
    }

    private func save() {
        let changesData = ICloudListMerge.encodeLog(changes)
        defaults.set(campusNames, forKey: listKey)
        defaults.set(changesData, forKey: changesKey)
        iCloud?.set(campusNames, forKey: listKey)
        iCloud?.set(changesData, forKey: changesKey)
    }

    /// Notes a change before `campusNames` is set, so the save that follows includes it.
    private func recordChange(_ itemID: String, removed: Bool = false) {
        changes = ICloudListMerge.recording(itemID, removed: removed, in: changes)
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
        recordChange(campus.rawValue)
        campusNames.append(campus.rawValue)
    }

    func remove(_ campus: CityLocation.City) {
        guard contains(campus) else { return }
        recordChange(campus.rawValue, removed: true)
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
        for name in names {
            recordChange(name, removed: true)
        }
        campusNames.removeAll { names.contains($0) }
    }

    /// Reorders campuses by their position in `campuses` (matches SwiftUI's `.onMove`).
    /// Saved names this app doesn't know stay at the end.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var shown = campuses.map(\.rawValue)
        shown.move(fromOffsets: source, toOffset: destination)
        let hidden = campusNames.filter { !shown.contains($0) }
        recordChange(ICloudListMerge.orderID)
        campusNames = shown + hidden
    }
}
