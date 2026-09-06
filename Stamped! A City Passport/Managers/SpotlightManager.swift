//
//  SpotlightManager.swift
//  Stamped! A City Passport
//
//  Indexes all 89 cities and their buildings into iOS Spotlight so they
//  appear in system search results. No entitlement required.
//

import Foundation
import CoreSpotlight

enum SpotlightManager {

    // Call once at launch — subsequent calls are cheap (CoreSpotlight deduplicates).
    static func indexAll(cities: [CityLocation.City]) {
        var items: [CSSearchableItem] = []

        for city in cities {
            // City entry
            let cityAttr = CSSearchableItemAttributeSet(contentType: .item)
            cityAttr.title = city.name
            cityAttr.contentDescription = city.details.nickname
            cityAttr.keywords = [city.name, "architecture", "travel", "passport", "landmark"]
            items.append(CSSearchableItem(
                uniqueIdentifier: "stamped://city/\(city.id)",
                domainIdentifier: "com.stamped.city",
                attributeSet: cityAttr
            ))

            // Building entries
            for building in city.buildings {
                let attr = CSSearchableItemAttributeSet(contentType: .item)
                attr.title = building.name
                attr.contentDescription = "by \(building.architect) · \(city.name)"
                attr.keywords = [building.name, building.architect, building.buildingStyle, city.name, "landmark"]
                items.append(CSSearchableItem(
                    uniqueIdentifier: "stamped://building/\(building.id)/\(city.id)",
                    domainIdentifier: "com.stamped.building",
                    attributeSet: attr
                ))
            }
        }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error = error {
                print("[Spotlight] Indexing error: \(error)")
            } else {
                print("[Spotlight] ✅ Indexed \(items.count) items")
            }
        }
    }

    // Call from onContinueUserActivity — returns the city to navigate to.
    static func city(from activity: NSUserActivity) -> CityLocation.City? {
        guard activity.activityType == CSSearchableItemActionType,
              let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else { return nil }

        if id.hasPrefix("stamped://city/") {
            let raw = String(id.dropFirst("stamped://city/".count))
            return CityLocation.City(rawValue: raw)
        }
        if id.hasPrefix("stamped://building/") {
            // format: stamped://building/{buildingID}/{cityRawValue}
            let tail = id.dropFirst("stamped://building/".count)
            if let slashIdx = tail.lastIndex(of: "/") {
                let cityRaw = String(tail[tail.index(after: slashIdx)...])
                return CityLocation.City(rawValue: cityRaw)
            }
        }
        return nil
    }
}
