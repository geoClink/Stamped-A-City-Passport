import Foundation
import CoreLocation

struct PlannedStop: Codable, Identifiable, Equatable {
    let id: String
    let buildingID: String
    let distanceMeters: Double
    let travelMinsFromPrev: Int
    let arrivalOffsetMins: Int
    let dayNumber: Int
    let requiresTransit: Bool
    let visitDurationMins: Int
}

final class ItineraryPlanner {

    // MARK: - Visit Duration by Building Type
    static func visitDuration(for building: Building) -> Int {
        let use = building.newUse.lowercased()
        if use.contains("museum") { return 90 }
        if use.contains("cathedral") || use.contains("church") || use.contains("chapel") { return 30 }
        if use.contains("palace") || use.contains("castle") { return 60 }
        if use.contains("theatre") || use.contains("theater") { return 45 }
        if use.contains("library") { return 45 }
        if use.contains("hotel") { return 20 }
        if use.contains("office") || use.contains("commercial") { return 25 }
        if use.contains("gallery") { return 60 }
        return 45
    }

    // MARK: - Public Entry Point
    static func planCity(
        buildings: [Building],
        days: Int = 3,
        walkingSpeedMetersPerMin: Double = 80.0
    ) -> [[PlannedStop]] {
        guard !buildings.isEmpty else { return [] }

        let balanced = balanceByType(buildings: buildings, days: days)
        var result: [[PlannedStop]] = []

        for (dayIndex, dayBuildings) in balanced.enumerated() {
            let stops = planSingleDay(
                buildings: dayBuildings,
                dayNumber: dayIndex + 1,
                walkingSpeedMetersPerMin: walkingSpeedMetersPerMin
            )
            result.append(stops)
        }

        return result
    }

    // MARK: - Balance Buildings Across Days by Type
    private static func balanceByType(buildings: [Building], days: Int) -> [[Building]] {
        var grouped: [String: [Building]] = [:]
        for b in buildings {
            let category = b.newUse.isEmpty ? b.oldUse : b.newUse
            grouped[category, default: []].append(b)
        }

        var buckets: [[Building]] = Array(repeating: [], count: days)
        var dayIndex = 0

        for (_, group) in grouped {
            for building in group {
                buckets[dayIndex % days].append(building)
                dayIndex += 1
            }
        }

        return buckets
    }

    // MARK: - Single Day Nearest-Neighbor Planner
    private static func planSingleDay(
        buildings: [Building],
        dayNumber: Int,
        walkingSpeedMetersPerMin: Double
    ) -> [PlannedStop] {
        guard !buildings.isEmpty else { return [] }

        let maxWalkMeters = 2000.0
        var pool = buildings
        var plan: [PlannedStop] = []
        var offsetMin = 0
        var lastCoord: CLLocationCoordinate2D? = nil

        // Seed with first building that has coordinates
        if let startIdx = pool.firstIndex(where: { $0.latitude != nil && $0.longitude != nil }) {
            let b = pool.remove(at: startIdx)
            lastCoord = CLLocationCoordinate2D(latitude: b.latitude!, longitude: b.longitude!)
            let duration = visitDuration(for: b)
            plan.append(PlannedStop(
                id: UUID().uuidString,
                buildingID: b.id,
                distanceMeters: 0,
                travelMinsFromPrev: 0,
                arrivalOffsetMins: offsetMin,
                dayNumber: dayNumber,
                requiresTransit: false,
                visitDurationMins: duration
            ))
            offsetMin += duration
        }

        while !pool.isEmpty {
            var bestIdx = 0
            var bestDist = Double.greatestFiniteMagnitude

            for (i, b) in pool.enumerated() {
                guard let lat = b.latitude, let lon = b.longitude else { continue }
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                if let last = lastCoord {
                    let d = haversine(last, coord)
                    if d < bestDist { bestDist = d; bestIdx = i }
                } else {
                    bestIdx = i; bestDist = 0; break
                }
            }

            let chosen = pool.remove(at: bestIdx)
            let dist = bestDist == Double.greatestFiniteMagnitude ? 0.0 : bestDist
            let requiresTransit = dist > maxWalkMeters
            let rawWalkMins = Int(round(dist / walkingSpeedMetersPerMin))
            let travelMins = min(rawWalkMins, 30)
            let arrival = offsetMin + travelMins
            let duration = visitDuration(for: chosen)

            plan.append(PlannedStop(
                id: UUID().uuidString,
                buildingID: chosen.id,
                distanceMeters: dist,
                travelMinsFromPrev: travelMins,
                arrivalOffsetMins: arrival,
                dayNumber: dayNumber,
                requiresTransit: requiresTransit,
                visitDurationMins: duration
            ))

            if let lat = chosen.latitude, let lon = chosen.longitude {
                lastCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            offsetMin = arrival + duration
        }

        return plan
    }

    // MARK: - Haversine Distance
    private static func haversine(
        _ a: CLLocationCoordinate2D,
        _ b: CLLocationCoordinate2D
    ) -> Double {
        let R = 6_371_000.0
        let φ1 = a.latitude * .pi / 180
        let φ2 = b.latitude * .pi / 180
        let Δφ = (b.latitude - a.latitude) * .pi / 180
        let Δλ = (b.longitude - a.longitude) * .pi / 180
        let sinΔφ = sin(Δφ / 2)
        let sinΔλ = sin(Δλ / 2)
        let aa = sinΔφ * sinΔφ + cos(φ1) * cos(φ2) * sinΔλ * sinΔλ
        return R * 2 * atan2(sqrt(aa), sqrt(1 - aa))
    }
}
