//
//  TripTour.swift
//  Stamped! A City Passport
//
//  Turns a trip into the ordered list of places the map's Tour flies to:
//  Day 1's stops in order, then Day 2's, and so on.
//

import Foundation
import CoreLocation

/// One place the trip tour flies to.
struct TripTourStep: Identifiable, Hashable {
    /// What the map shows a card for when it arrives.
    enum Target: Hashable {
        case landmark(Building)
        case place(CustomPlace)
    }

    /// The trip stop's id, so the same landmark on two days counts as two steps.
    let id: String
    let target: Target
    /// 1-based day number in the trip.
    let dayNumber: Int
    /// 1-based position within that day.
    let stopNumber: Int
    /// How many located stops that day has (for "Stop 2 of 4").
    let stopsInDay: Int

    var coordinate: CLLocationCoordinate2D {
        switch target {
        case .landmark(let building):
            CLLocationCoordinate2D(latitude: building.latitude ?? 0, longitude: building.longitude ?? 0)
        case .place(let place):
            place.coordinate
        }
    }

    var name: String {
        switch target {
        case .landmark(let building): building.name
        case .place(let place): place.name
        }
    }
}

enum TripTour {
    /// Every stop the tour can fly to, in trip order. Stops with no location
    /// (a landmark without coordinates, or a saved place that was deleted)
    /// are skipped, and so are days left with nothing to show.
    static func steps(for trip: Trip, buildings: [Building], customPlaces: [CustomPlace]) -> [TripTourStep] {
        var steps: [TripTourStep] = []
        for (dayIndex, day) in trip.days.enumerated() {
            let targets = day.stops.compactMap { stop in
                target(for: stop, buildings: buildings, customPlaces: customPlaces).map { (stop.id, $0) }
            }
            for (stopIndex, (stopID, target)) in targets.enumerated() {
                steps.append(TripTourStep(
                    id: stopID,
                    target: target,
                    dayNumber: dayIndex + 1,
                    stopNumber: stopIndex + 1,
                    stopsInDay: targets.count
                ))
            }
        }
        return steps
    }

    private static func target(for stop: TripStop, buildings: [Building], customPlaces: [CustomPlace]) -> TripTourStep.Target? {
        switch stop.kind {
        case .landmark(let buildingID):
            guard let building = buildings.first(where: { $0.id == buildingID }),
                  building.latitude != nil, building.longitude != nil else { return nil }
            return .landmark(building)
        case .place(let placeID):
            return customPlaces.first { $0.id == placeID }.map { .place($0) }
        }
    }
}
