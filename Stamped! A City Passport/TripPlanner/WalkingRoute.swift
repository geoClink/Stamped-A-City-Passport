//
//  WalkingRoute.swift
//  Stamped! A City Passport
//
//  Puts a day's stops into a sensible walking order and estimates
//  the walk between them. Straight-line distance only — no street routing.
//

import Foundation
import CoreLocation

/// A stop with a known location, ready for route ordering.
nonisolated struct RoutePoint: Hashable {
    let id: String
    let latitude: Double
    let longitude: Double
}

/// The walk from one stop to the next.
nonisolated struct WalkingLeg: Hashable {
    let fromID: String
    let toID: String
    let meters: Double
    let minutes: Int
}

nonisolated enum WalkingRoute {
    /// A relaxed city walking pace, about 4.8 km/h.
    static let metersPerMinute = 80.0

    /// Orders points by always walking to the closest stop not yet visited,
    /// starting from the first point. Not always the shortest possible route,
    /// but close enough for a day of sightseeing and easy to reason about.
    static func nearestNeighbourOrder(_ points: [RoutePoint]) -> [RoutePoint] {
        guard var current = points.first else { return [] }
        var remaining = Array(points.dropFirst())
        var ordered = [current]

        while !remaining.isEmpty {
            // Index of the closest remaining stop to where we are now
            var closestIndex = 0
            var closestDistance = Double.greatestFiniteMagnitude
            for (index, candidate) in remaining.enumerated() {
                let distance = meters(from: current, to: candidate)
                if distance < closestDistance {
                    closestDistance = distance
                    closestIndex = index
                }
            }
            current = remaining.remove(at: closestIndex)
            ordered.append(current)
        }
        return ordered
    }

    /// The walk between each pair of consecutive points, in order.
    static func legs(for points: [RoutePoint]) -> [WalkingLeg] {
        zip(points, points.dropFirst()).map { from, to in
            let distance = meters(from: from, to: to)
            return WalkingLeg(fromID: from.id, toID: to.id, meters: distance, minutes: minutes(forMeters: distance))
        }
    }

    /// Walking minutes for a distance, rounded up so a short hop shows "1 min" rather than "0 min".
    static func minutes(forMeters meters: Double) -> Int {
        Int((meters / metersPerMinute).rounded(.up))
    }

    /// Straight-line ("as the crow flies") distance in meters.
    static func meters(from: RoutePoint, to: RoutePoint) -> Double {
        let start = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let end = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return start.distance(from: end)
    }
}
