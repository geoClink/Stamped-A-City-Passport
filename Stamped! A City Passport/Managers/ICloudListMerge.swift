//
//  ICloudListMerge.swift
//  Stamped! A City Passport
//
//  Merges a list saved in iCloud key-value storage (trips, My College List,
//  saved places) item by item, so an edit on one device never wipes out a
//  different edit made on another.
//
//  Before 2.10 the latest saved *list* won: if the iPhone saved trip A while
//  the Mac (offline, or not yet synced) saved trip B, one of them was lost.
//  Now each list also keeps a small change log, saved next to it in iCloud:
//  item id → when it was last added, edited or removed. Merging keeps every
//  item from both devices, takes the newer copy of an item both have, and
//  drops an item only when the log says it was removed.
//
//  The list itself is saved in the same format and under the same key as
//  before, so older app versions (and the Vision Pro app) still read it.
//

import Foundation

/// The latest change to one item of a synced list.
nonisolated struct ListChange: Codable, Equatable {
    var date: Date
    var isRemoved: Bool
}

/// Item id → its latest change. `ICloudListMerge.orderID` records the last reorder.
typealias ListChangeLog = [String: ListChange]

nonisolated enum ICloudListMerge {
    /// Log entry for "the list was reordered" (My College List), so the newer order wins.
    static let orderID = "#order"

    /// Removal entries older than this are dropped so the log doesn't grow forever.
    /// A device offline for longer could bring a removed item back, which is
    /// better than ever losing one.
    static let removalMemory: TimeInterval = 180 * 24 * 60 * 60

    /// Merges this device's list with the one in iCloud.
    /// - Every item on either side is kept unless the merged log says it was removed.
    /// - When both sides have an item, the side whose log has the newer change for
    ///   it wins; on a tie (the usual case, or an older app that doesn't log) iCloud wins.
    /// - Order: the side that reordered last, then the other side's extra items at the end.
    static func merge<Item: Equatable>(
        local: [Item], localLog: ListChangeLog,
        cloud: [Item], cloudLog: ListChangeLog,
        id: (Item) -> String
    ) -> (items: [Item], log: ListChangeLog) {
        let log = mergedLog(localLog, cloudLog)

        // Keyed by id; `uniquingKeysWith` keeps the first if a list somehow has a duplicate
        let localByID = Dictionary(local.map { (id($0), $0) }, uniquingKeysWith: { first, _ in first })
        let cloudByID = Dictionary(cloud.map { (id($0), $0) }, uniquingKeysWith: { first, _ in first })

        func isNewer(_ a: ListChange?, than b: ListChange?) -> Bool {
            (a?.date ?? .distantPast) > (b?.date ?? .distantPast)
        }

        let localOrderWins = isNewer(localLog[orderID], than: cloudLog[orderID])
        let ordered = localOrderWins ? local + cloud : cloud + local

        var seen: Set<String> = []
        var items: [Item] = []
        for item in ordered {
            let itemID = id(item)
            guard seen.insert(itemID).inserted, log[itemID]?.isRemoved != true else { continue }

            if let localCopy = localByID[itemID], let cloudCopy = cloudByID[itemID] {
                items.append(isNewer(localLog[itemID], than: cloudLog[itemID]) ? localCopy : cloudCopy)
            } else {
                items.append(item)
            }
        }
        return (items, log)
    }

    /// Both logs combined, keeping the newer change for each id.
    static func mergedLog(_ a: ListChangeLog, _ b: ListChangeLog) -> ListChangeLog {
        a.merging(b) { first, second in second.date > first.date ? second : first }
    }

    /// Records a change in the log and forgets old removals.
    static func recording(_ itemID: String, removed: Bool, in log: ListChangeLog, now: Date = Date()) -> ListChangeLog {
        var log = log
        log[itemID] = ListChange(date: now, isRemoved: removed)
        return log.filter { !$0.value.isRemoved || now.timeIntervalSince($0.value.date) < removalMemory }
    }

    // MARK: - Saving

    /// Logs are saved as JSON data, like trips, since iCloud can't store custom structs directly.
    static func decodeLog(_ data: Data?) -> ListChangeLog {
        guard let data, let log = try? JSONDecoder().decode(ListChangeLog.self, from: data) else { return [:] }
        return log
    }

    static func encodeLog(_ log: ListChangeLog) -> Data? {
        try? JSONEncoder().encode(log)
    }

    /// True when a key-value store notification says the user signed in to a
    /// different iCloud account. Then iCloud's list replaces this device's
    /// instead of merging, so one person's trips aren't copied into another's iCloud.
    static func isAccountChange(_ notification: Notification) -> Bool {
        let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
        return reason == NSUbiquitousKeyValueStoreAccountChange
    }
}
