//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/15/26.
//

import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif
import Combine
import WidgetKit

@MainActor
class GlobalProgressManager: ObservableObject {
    static let shared = GlobalProgressManager()

    // MARK: - Data Storage

    @Published var visitedIDs: Set<String> = [] {
        didSet { save() }
    }

    var visitDates: [String: Date] = [:]

    @Published var userImages: [String: UIImage] = [:]

    var buildingNotes: [String: String] = [:]

    /// Landmarks the user wants to visit on a future trip.
    @Published var wishlistIDs: Set<String> = [] {
        didSet { saveWishlist() }
    }
    /// When each landmark was last added to or removed from Want to Visit, for merging with other devices.
    private var wishlistChanges: ListChangeLog = [:]

    /// Places saved from Apple Maps search that aren't built-in landmarks.
    @Published var customPlaces: [CustomPlace] = [] {
        didSet { saveCustomPlaces() }
    }
    /// When each saved place was last added or removed, for merging with other devices.
    private var customPlaceChanges: ListChangeLog = [:]

    /// Campus traditions the user has done ("Rub John Harvard's foot"), by tradition id.
    @Published var completedTraditionIDs: Set<String> = [] {
        didSet { saveTraditions() }
    }

    private let saveKey = "GlobalVisitedBuildingsKey"
    private let wishlistKey = "GlobalWishlistKey"
    private let wishlistChangesKey = "GlobalWishlistChangesKey"
    private let traditionsKey = "GlobalCompletedTraditionsKey"
    private let customPlacesKey = "GlobalCustomPlacesKey"
    private let customPlaceChangesKey = "GlobalCustomPlacesChangesKey"
    private let visitDatesKey = "GlobalVisitDatesKey"
    private let buildingNotesKey = "BuildingNotesKey"
    private let defaults = UserDefaults(suiteName: "group.stamped.passport") ?? .standard
    private let iCloud = NSUbiquitousKeyValueStore.default

    private init() {
        if let savedData = defaults.array(forKey: saveKey) as? [String] {
            self.visitedIDs = Set(savedData)
        } else {
            self.visitedIDs = []
            save()
        }

        if let raw = defaults.dictionary(forKey: visitDatesKey) as? [String: Double] {
            self.visitDates = raw.mapValues { Date(timeIntervalSince1970: $0) }
        }

        if let notes = defaults.dictionary(forKey: buildingNotesKey) as? [String: String] {
            self.buildingNotes = notes
        }

        if let wishlist = defaults.array(forKey: wishlistKey) as? [String] {
            self.wishlistIDs = Set(wishlist)
        }
        wishlistChanges = ICloudListMerge.decodeLog(defaults.data(forKey: wishlistChangesKey))

        if let traditions = defaults.array(forKey: traditionsKey) as? [String] {
            self.completedTraditionIDs = Set(traditions)
        }

        // Saved as JSON data, since UserDefaults and iCloud can't store custom structs directly
        if let data = defaults.data(forKey: customPlacesKey),
           let places = try? JSONDecoder().decode([CustomPlace].self, from: data) {
            self.customPlaces = places
        }
        customPlaceChanges = ICloudListMerge.decodeLog(defaults.data(forKey: customPlaceChangesKey))

        loadImagesFromDisk()

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
        // visitedIDs: take the union — never remove stamps from a cloud merge
        if let cloudIDs = iCloud.array(forKey: saveKey) as? [String] {
            let merged = visitedIDs.union(Set(cloudIDs))
            if merged != visitedIDs {
                visitedIDs = merged  // triggers save() via didSet
            }
        }

        // visitDates: keep the earliest stamp date for each building
        if let raw = iCloud.dictionary(forKey: visitDatesKey) as? [String: Double] {
            var updated = false
            for (id, ts) in raw {
                let cloudDate = Date(timeIntervalSince1970: ts)
                if let local = visitDates[id] {
                    if cloudDate < local { visitDates[id] = cloudDate; updated = true }
                } else {
                    visitDates[id] = cloudDate; updated = true
                }
            }
            if updated { saveVisitDates() }
        }

        // traditions: like stamps, take the union so a completed tradition is never lost
        if let cloudTraditions = iCloud.array(forKey: traditionsKey) as? [String] {
            let merged = completedTraditionIDs.union(Set(cloudTraditions))
            if merged != completedTraditionIDs {
                completedTraditionIDs = merged
            }
        }

        // wishlist: merged landmark by landmark since 2.10, so hearts added on two
        // devices are both kept and an un-heart sticks (see ICloudListMerge)
        mergeWishlist(
            cloudIDs: iCloud.array(forKey: wishlistKey) as? [String],
            changesData: iCloud.data(forKey: wishlistChangesKey),
            accountChanged: accountChanged
        )

        // custom places: merged place by place since 2.10, so places saved on
        // two devices are both kept and a removal sticks (see ICloudListMerge)
        mergeCustomPlaces(
            placesData: iCloud.data(forKey: customPlacesKey),
            changesData: iCloud.data(forKey: customPlaceChangesKey),
            accountChanged: accountChanged
        )

        // buildingNotes: adopt cloud note only if there is no local note
        if let cloudNotes = iCloud.dictionary(forKey: buildingNotesKey) as? [String: String] {
            var updated = false
            for (id, note) in cloudNotes where buildingNotes[id] == nil {
                buildingNotes[id] = note; updated = true
            }
            if updated { defaults.set(buildingNotes, forKey: buildingNotesKey) }
        }
    }

    func saveNote(_ text: String, for buildingID: String) {
        objectWillChange.send()
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            buildingNotes.removeValue(forKey: buildingID)
        } else {
            buildingNotes[buildingID] = text
        }
        defaults.set(buildingNotes, forKey: buildingNotesKey)
        iCloud.set(buildingNotes, forKey: buildingNotesKey)
    }

    // MARK: - Persistent Image Logic
    
    private func loadImagesFromDisk() {
        let documents = getDocumentsDirectory()
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil)
            
            for url in fileURLs where url.pathExtension == "jpg" {
                // Extracts "BuildingName" from "BuildingName.jpg"
                let buildingID = url.deletingPathExtension().lastPathComponent
                
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    self.userImages[buildingID] = image
                }
            }
        } catch {
            print("Error scanning for saved images: \(error)")
        }
    }
    
    func saveImage(_ image: UIImage, for buildingID: String) {
        userImages[buildingID] = image
        
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        let url = getDocumentsDirectory().appendingPathComponent("\(buildingID).jpg")
        
        do {
            try data.write(to: url)
            print("Successfully saved image for \(buildingID) to disk.")
        } catch {
            print("Error writing image to disk: \(error)")
        }
    }

    func loadImage(for buildingID: String) -> UIImage? {
        if let cached = userImages[buildingID] { return cached }
        
        let url = getDocumentsDirectory().appendingPathComponent("\(buildingID).jpg")
        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            userImages[buildingID] = image
            return image
        }
        return nil
    }
    
    func deleteImage(for buildingID: String) {
        userImages.removeValue(forKey: buildingID)
        
        let url = getDocumentsDirectory().appendingPathComponent("\(buildingID).jpg")
        try? FileManager.default.removeItem(at: url)
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Core Progress Logic
    
    func toggleVisit(for buildingID: String, in cityBuildings: [Building]) {
        if visitedIDs.contains(buildingID) {
            visitedIDs.remove(buildingID)
        } else {
            visitedIDs.insert(buildingID)
            // Record first-stamp date; preserve it if the user un-stamps and re-stamps later
            if visitDates[buildingID] == nil {
                objectWillChange.send()
                visitDates[buildingID] = Date()
                saveVisitDates()
            }
            // This stamp finished the whole city or campus: a good moment to ask for a rating
            if Self.shouldAskForReview(cityBuildings: cityBuildings, visited: visitedIDs,
                                       lastAskedVersion: defaults.string(forKey: reviewAskedVersionKey),
                                       currentVersion: Self.appVersion) {
                defaults.set(Self.appVersion, forKey: reviewAskedVersionKey)
                reviewMoment = Date()
            }
            // A quiet moment after real use: never on top of a city's celebration
            let finishedCity = !cityBuildings.isEmpty && cityBuildings.allSatisfy { visitedIDs.contains($0.id) }
            if Self.shouldAskForTip(stampCount: visitedIDs.count, finishedCity: finishedCity,
                                    alreadyAsked: defaults.bool(forKey: tipAskedKey)) {
                defaults.set(true, forKey: tipAskedKey)
                tipMoment = Date()
            }
        }
    }

    // MARK: - Tip prompt

    /// Set once ever, on a stamp at or past `tipPromptStampCount`. TipPromptModifier shows the tip jar.
    @Published private(set) var tipMoment: Date?
    private let tipAskedKey = "tipPromptAsked"
    nonisolated static let tipPromptStampCount = 10

    nonisolated static func shouldAskForTip(stampCount: Int, finishedCity: Bool, alreadyAsked: Bool) -> Bool {
        !alreadyAsked && !finishedCity && stampCount >= tipPromptStampCount
    }

    // MARK: - Rating prompt

    /// Set when a stamp completes a city or campus; ReviewPromptModifier asks for an App Store
    /// rating when it changes. At most once per app version (Apple also limits it to 3 a year
    /// and decides itself whether to show the prompt).
    @Published private(set) var reviewMoment: Date?
    private let reviewAskedVersionKey = "reviewPromptAskedVersion"

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    /// True when every landmark of the city is now stamped and this version hasn't asked yet.
    nonisolated static func shouldAskForReview(cityBuildings: [Building], visited: Set<String>,
                                               lastAskedVersion: String?, currentVersion: String) -> Bool {
        guard !cityBuildings.isEmpty, lastAskedVersion != currentVersion else { return false }
        return cityBuildings.allSatisfy { visited.contains($0.id) }
    }

    private func saveVisitDates() {
        let raw = visitDates.mapValues { $0.timeIntervalSince1970 }
        defaults.set(raw, forKey: visitDatesKey)
        iCloud.set(raw, forKey: visitDatesKey)
    }

    func getMastery(for buildings: [Building]) -> (tier: String, color: Color, progress: Double, count: Int) {
        let total = buildings.count
        let visitedCount = buildings.filter { visitedIDs.contains($0.id) }.count
        
        guard total > 0 else { return ("Tourist", .blue, 0.0, 0) }
        let percentage = Double(visitedCount) / Double(total)
        
        switch percentage {
        case 0..<0.25: return ("Tourist", .blue, percentage, visitedCount)
        case 0.25..<0.50: return ("Explorer", .green, percentage, visitedCount)
        case 0.50..<0.75: return ("Urban Insider", .purple, percentage, visitedCount)
        case 0.75..<1.0: return ("Local Legend", Color.adventureOrange, percentage, visitedCount)
        case 1.0: return ("Master Collector", Color(red: 0.85, green: 0.65, blue: 0.13), 1.0, visitedCount)
        default: return ("Tourist", .blue, 0, visitedCount)
        }
    }
    
    func isCityComplete(_ city: CityLocation.City) -> Bool {
        let cityIDs = Set(city.buildings.map { $0.id })
        return cityIDs.isSubset(of: visitedIDs)
    }

    func isVisited(_ id: String) -> Bool {
        visitedIDs.contains(id)
    }

    // MARK: - Wishlist

    func isWishlisted(_ id: String) -> Bool {
        wishlistIDs.contains(id)
    }

    func toggleWishlist(_ id: String) {
        let removing = wishlistIDs.contains(id)
        // Logged before the set changes, so the save its didSet triggers includes it
        wishlistChanges = ICloudListMerge.recording(id, removed: removing, in: wishlistChanges)
        if removing {
            wishlistIDs.remove(id)
        } else {
            wishlistIDs.insert(id)
        }
    }

    /// Merges iCloud's Want to Visit list into this device's, then saves the result
    /// back so iCloud gets any hearts only this device had. Same steps as mergeCustomPlaces.
    private func mergeWishlist(cloudIDs: [String]?, changesData: Data?, accountChanged: Bool) {
        let cloudChanges = ICloudListMerge.decodeLog(changesData)

        guard let cloudIDs else {
            // Nothing in iCloud yet: share this device's list
            if !wishlistIDs.isEmpty || !wishlistChanges.isEmpty { saveWishlist() }
            return
        }

        if accountChanged {
            // A different iCloud account: use its list, don't mix the two people's
            wishlistChanges = cloudChanges
            wishlistIDs = Set(cloudIDs)
            return
        }

        let merged = Self.mergedWishlist(local: wishlistIDs, localLog: wishlistChanges,
                                         cloud: Set(cloudIDs), cloudLog: cloudChanges)
        wishlistChanges = merged.log
        if merged.ids != wishlistIDs {
            wishlistIDs = merged.ids // saves via didSet
        } else if merged.ids != Set(cloudIDs) || merged.log != cloudChanges {
            saveWishlist()
        }
    }

    /// The merge itself, with no iCloud or UserDefaults, so tests can check it directly.
    /// Want to Visit has no order, so items are sorted only to make the merge repeatable.
    nonisolated static func mergedWishlist(local: Set<String>, localLog: ListChangeLog,
                                           cloud: Set<String>, cloudLog: ListChangeLog)
        -> (ids: Set<String>, log: ListChangeLog) {
        let result = ICloudListMerge.merge(local: local.sorted(), localLog: localLog,
                                           cloud: cloud.sorted(), cloudLog: cloudLog,
                                           id: { $0 })
        return (Set(result.items), result.log)
    }

    // MARK: - Campus traditions

    func isTraditionDone(_ id: String) -> Bool {
        completedTraditionIDs.contains(id)
    }

    func toggleTradition(_ id: String) {
        if completedTraditionIDs.contains(id) {
            completedTraditionIDs.remove(id)
        } else {
            completedTraditionIDs.insert(id)
        }
    }

    private func saveTraditions() {
        let arr = Array(completedTraditionIDs)
        defaults.set(arr, forKey: traditionsKey)
        iCloud.set(arr, forKey: traditionsKey)
    }

    // MARK: - Custom places

    func customPlaces(in cityName: String) -> [CustomPlace] {
        customPlaces.filter { $0.cityName == cityName }
    }

    func hasCustomPlace(name: String, latitude: Double, longitude: Double) -> Bool {
        customPlaces.contains { $0.isSamePlace(name: name, latitude: latitude, longitude: longitude) }
    }

    /// Saves a place unless the same one is already on the list.
    func addCustomPlace(_ place: CustomPlace) {
        guard !hasCustomPlace(name: place.name, latitude: place.latitude, longitude: place.longitude) else { return }
        recordCustomPlaceChange(place.id)
        customPlaces.append(place)
    }

    func removeCustomPlace(_ id: String) {
        guard customPlaces.contains(where: { $0.id == id }) else { return }
        recordCustomPlaceChange(id, removed: true)
        customPlaces.removeAll { $0.id == id }
    }

    /// Merges iCloud's saved places into this device's, then saves the result
    /// back so iCloud gets any places only this device had. Same steps as
    /// TripStore.mergeCloud. Not private so tests can pass iCloud's data in.
    func mergeCustomPlaces(placesData: Data?, changesData: Data?, accountChanged: Bool = false) {
        let cloudPlaces = placesData.flatMap { try? JSONDecoder().decode([CustomPlace].self, from: $0) }
        let cloudChanges = ICloudListMerge.decodeLog(changesData)

        guard let cloudPlaces else {
            // Nothing in iCloud yet: share this device's places
            if !customPlaces.isEmpty || !customPlaceChanges.isEmpty { saveCustomPlaces() }
            return
        }

        if accountChanged {
            customPlaceChanges = cloudChanges
            customPlaces = cloudPlaces
            return
        }

        let merged = ICloudListMerge.merge(
            local: customPlaces, localLog: customPlaceChanges,
            cloud: cloudPlaces, cloudLog: cloudChanges,
            id: \.id
        )
        customPlaceChanges = merged.log
        if merged.items != customPlaces {
            customPlaces = merged.items // saves via didSet
        } else if merged.items != cloudPlaces || merged.log != cloudChanges {
            saveCustomPlaces()
        }
    }

    /// Notes a change before `customPlaces` is set, so the save that follows includes it.
    private func recordCustomPlaceChange(_ placeID: String, removed: Bool = false) {
        customPlaceChanges = ICloudListMerge.recording(placeID, removed: removed, in: customPlaceChanges)
    }

    private func saveCustomPlaces() {
        guard let data = try? JSONEncoder().encode(customPlaces) else { return }
        let changesData = ICloudListMerge.encodeLog(customPlaceChanges)
        defaults.set(data, forKey: customPlacesKey)
        defaults.set(changesData, forKey: customPlaceChangesKey)
        iCloud.set(data, forKey: customPlacesKey)
        iCloud.set(changesData, forKey: customPlaceChangesKey)
    }

    private func saveWishlist() {
        let arr = Array(wishlistIDs)
        let changesData = ICloudListMerge.encodeLog(wishlistChanges)
        defaults.set(arr, forKey: wishlistKey)
        defaults.set(changesData, forKey: wishlistChangesKey)
        iCloud.set(arr, forKey: wishlistKey)
        iCloud.set(changesData, forKey: wishlistChangesKey)
    }

    private func save() {
        let arr = Array(visitedIDs)
        defaults.set(arr, forKey: saveKey)
        iCloud.set(arr, forKey: saveKey)
        // The home screen widget reads this key from the App Group; ask it to redraw now
        // instead of waiting for its hourly refresh. Runs for stamps, iCloud merges and reset.
        WidgetCenter.shared.reloadTimelines(ofKind: "PassportWidget")
    }

    func resetAllProgress() {
        visitedIDs.removeAll()
        objectWillChange.send()
        visitDates.removeAll()
        defaults.removeObject(forKey: visitDatesKey)
        buildingNotes.removeAll()
        defaults.removeObject(forKey: buildingNotesKey)
        iCloud.removeObject(forKey: saveKey)
        iCloud.removeObject(forKey: visitDatesKey)
        iCloud.removeObject(forKey: buildingNotesKey)
        // Logged as removals (not just cleared) so other devices remove them too
        for id in wishlistIDs {
            wishlistChanges = ICloudListMerge.recording(id, removed: true, in: wishlistChanges)
        }
        wishlistIDs.removeAll()
        completedTraditionIDs.removeAll()
        iCloud.removeObject(forKey: traditionsKey)
        // Logged as removals (not just cleared) so other devices remove them too
        for place in customPlaces {
            recordCustomPlaceChange(place.id, removed: true)
        }
        customPlaces.removeAll()
        userImages.removeAll()
        
        let documents = getDocumentsDirectory()
        if let files = try? FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "jpg" {
                try? FileManager.default.removeItem(at: file)
            }
        }
        
        UserDefaults.standard.set(0, forKey: "TotalStampsCount")
    }
}
