//
//  ResolvedTripStop.swift
//  Stamped! A City Passport
//
//  A TripStop only stores an id. This looks the id up in the city's landmarks
//  or the user's saved places so the UI has a name, icon and location to show.
//

import Foundation

struct ResolvedTripStop: Identifiable, Hashable {
    let stop: TripStop
    let name: String
    let subtitle: String?
    let systemImage: String
    let isLandmark: Bool
    /// nil when the landmark has no coordinates or the saved place was deleted.
    let routePoint: RoutePoint?

    var id: String { stop.id }

    init(stop: TripStop, buildings: [Building], customPlaces: [CustomPlace]) {
        self.stop = stop
        switch stop.kind {
        case .landmark(let buildingID):
            let building = buildings.first { $0.id == buildingID }
            name = building?.name ?? "Unknown landmark"
            subtitle = building?.knownStyle
            systemImage = "building.columns.fill"
            isLandmark = true
            if let latitude = building?.latitude, let longitude = building?.longitude {
                routePoint = RoutePoint(id: stop.id, latitude: latitude, longitude: longitude)
            } else {
                routePoint = nil
            }
        case .place(let placeID):
            let place = customPlaces.first { $0.id == placeID }
            name = place?.name ?? "Removed place"
            subtitle = place?.address
            systemImage = CustomPlace.icon(forCategory: place?.category)
            isLandmark = false
            routePoint = place.map { RoutePoint(id: stop.id, latitude: $0.latitude, longitude: $0.longitude) }
        }
    }

    /// Resolves every stop in a day, keeping the day's order.
    static func resolve(_ day: TripDay, buildings: [Building], customPlaces: [CustomPlace]) -> [ResolvedTripStop] {
        day.stops.map { ResolvedTripStop(stop: $0, buildings: buildings, customPlaces: customPlaces) }
    }

    /// The nearest-neighbour walking order for a day, as stop ids. Stops without
    /// a location can't be placed on a route, so they keep their order at the end.
    static func optimizedStopIDs(_ stops: [ResolvedTripStop]) -> [String] {
        let points = stops.compactMap(\.routePoint)
        let unplaced = stops.filter { $0.routePoint == nil }.map(\.id)
        return WalkingRoute.nearestNeighbourOrder(points).map(\.id) + unplaced
    }

    /// Walking minutes from each stop to the next, keyed by the earlier stop's id.
    /// A stop is missing from the result if it or the next stop has no location.
    static func walkingMinutesToNext(_ stops: [ResolvedTripStop]) -> [String: Int] {
        var result: [String: Int] = [:]
        for (current, next) in zip(stops, stops.dropFirst()) {
            guard let from = current.routePoint, let to = next.routePoint else { continue }
            result[current.id] = WalkingRoute.minutes(forMeters: WalkingRoute.meters(from: from, to: to))
        }
        return result
    }
}
