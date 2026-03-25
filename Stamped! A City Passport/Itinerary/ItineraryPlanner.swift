//import Foundation
//import CoreLocation
//
//struct PlannedStop: Codable {
//    let buildingID: String
//    let distanceMeters: Double
//    let travelMinsFromPrev: Int
//    let arrivalOffsetMins: Int // minutes after start
//}
//
///// Simple on-device itinerary planner using nearest-neighbor and Haversine speed estimates.
///// - Notes: This is intentionally light-weight: uses walking speed by default and provides
/////   deterministic ordering for small lists (<= 20). You can later refine travelMins with MKDirections.
//final class ItineraryPlanner {
//    /// Plan an order of buildings and estimate travel times.
//    /// - Parameters:
//    ///   - buildings: list of Building objects (must include latitude/longitude where possible)
//    ///   - startOffsetMin: starting offset minutes from day start (default 0)
//    ///   - visitDurationMin: expected visit duration per stop (default 30)
//    ///   - walkingSpeedMetersPerMin: walking speed in meters per minute (default ~80 m/min ~4.8 km/h)
//    /// - Returns: ordered list of PlannedStop matching the chosen visit order.
//    static func plan(buildings: [Building], startOffsetMin: Int = 0, visitDurationMin: Int = 30, walkingSpeedMetersPerMin: Double = 80.0) -> [PlannedStop] {
//        // Helper: extract coordinate
//        func coord(of b: Building) -> CLLocationCoordinate2D? {
//            if let lat = b.latitude, let lon = b.longitude {
//                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
//            }
//            return nil
//        }
//
//        // Haversine distance (meters)
//        func haversine(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
//            let R = 6_371_000.0
//            let φ1 = a.latitude * .pi / 180.0
//            let φ2 = b.latitude * .pi / 180.0
//            let Δφ = (b.latitude - a.latitude) * .pi / 180.0
//            let Δλ = (b.longitude - a.longitude) * .pi / 180.0
//            let sinΔφ = sin(Δφ/2)
//            let sinΔλ = sin(Δλ/2)
//            let aa = sinΔφ * sinΔφ + cos(φ1) * cos(φ2) * sinΔλ * sinΔλ
//            let c = 2 * atan2(sqrt(aa), sqrt(1-aa))
//            return R * c
//        }
//
//        // If no building coords at all, return fallback order with zero distances
//        let anyCoord = buildings.contains { coord(of: $0) != nil }
//        var plan: [PlannedStop] = []
//        if !anyCoord {
//            var offset = startOffsetMin
//            for b in buildings {
//                plan.append(PlannedStop(buildingID: b.id, distanceMeters: 0, travelMinsFromPrev: 0, arrivalOffsetMins: offset))
//                offset += visitDurationMin
//            }
//            return plan
//        }
//
//        // Mutable pool
//        var pool = buildings
//        var offsetMin = startOffsetMin
//        var lastCoord: CLLocationCoordinate2D? = nil
//
//        // Seed with first item that has coords
//        if let startIdx = pool.firstIndex(where: { coord(of: $0) != nil }) {
//            let b = pool.remove(at: startIdx)
//            if let c = coord(of: b) { lastCoord = c }
//            plan.append(PlannedStop(buildingID: b.id, distanceMeters: 0, travelMinsFromPrev: 0, arrivalOffsetMins: offsetMin))
//            offsetMin += visitDurationMin
//        }
//
//        while !pool.isEmpty {
//            // find nearest pool building from lastCoord (if lastCoord nil, pick first with coords or first overall)
//            var bestIdx: Int? = nil
//            var bestDist = Double.greatestFiniteMagnitude
//            for (i, b) in pool.enumerated() {
//                guard let cb = coord(of: b) else { continue }
//                if let last = lastCoord {
//                    let d = haversine(last, cb)
//                    if d < bestDist { bestDist = d; bestIdx = i }
//                } else {
//                    bestIdx = i; bestDist = 0; break
//                }
//            }
//            // fallback: if no candidate with coords found, pick first
//            if bestIdx == nil { bestIdx = 0; bestDist = 0 }
//            let chosen = pool.remove(at: bestIdx!)
//            let dist = (bestDist == Double.greatestFiniteMagnitude) ? 0.0 : bestDist
//            let travelMins = Int(round(dist / walkingSpeedMetersPerMin))
//            let arrival = offsetMin + travelMins
//            plan.append(PlannedStop(buildingID: chosen.id, distanceMeters: dist, travelMinsFromPrev: travelMins, arrivalOffsetMins: arrival))
//            if let c = coord(of: chosen) { lastCoord = c }
//            offsetMin = arrival + visitDurationMin
//        }
//
//        return plan
//    }
//
//    /// Partition the set of buildings into `days` geographic clusters (simple k-means on lat/lon)
//    /// and plan each cluster independently using the nearest-neighbor planner.
//    static func planMultiDay(buildings: [Building], days: Int = 3, startOffsetMin: Int = 0, visitDurationMin: Int = 30, walkingSpeedMetersPerMin: Double = 80.0) -> [[PlannedStop]] {
//        guard days > 0 else { return [] }
//        // Separate buildings with coordinates from those without
//        var withCoord: [Building] = []
//        var withoutCoord: [Building] = []
//        for b in buildings {
//            if b.latitude != nil && b.longitude != nil {
//                withCoord.append(b)
//            } else {
//                withoutCoord.append(b)
//            }
//        }
//
//        // If not enough coord-bearing buildings, distribute simply
//        if withCoord.count <= days {
//            var out: [[PlannedStop]] = Array(repeating: [], count: days)
//            var idx = 0
//            for b in withCoord {
//                let p = plan(buildings: [b], startOffsetMin: 0, visitDurationMin: visitDurationMin, walkingSpeedMetersPerMin: walkingSpeedMetersPerMin)
//                out[idx % days] = p
//                idx += 1
//            }
//            // attach non-coord buildings round-robin as zero-distance stops
//            var j = 0
//            for b in withoutCoord {
//                let ps = PlannedStop(buildingID: b.id, distanceMeters: 0, travelMinsFromPrev: 0, arrivalOffsetMins: 0)
//                out[j % days].append(ps)
//                j += 1
//            }
//            return out
//        }
//
//        // Build coordinate array
//        struct C { var lat: Double; var lon: Double; var idx: Int }
//        var coords: [C] = []
//        for (i, b) in withCoord.enumerated() {
//            coords.append(C(lat: b.latitude!, lon: b.longitude!, idx: i))
//        }
//
//        // Initialize k centroids deterministically (pick spaced points)
//        let k = min(days, coords.count)
//        var centroids: [(lat: Double, lon: Double)] = []
//        for i in 0..<k {
//            let sel = coords[(i * coords.count) / k]
//            centroids.append((lat: sel.lat, lon: sel.lon))
//        }
//
//        func dist(_ a: (Double,Double), _ b: (Double,Double)) -> Double {
//            let A = CLLocationCoordinate2D(latitude: a.0, longitude: a.1)
//            let B = CLLocationCoordinate2D(latitude: b.0, longitude: b.1)
//            // reuse haversine impl
//            let R = 6_371_000.0
//            let φ1 = A.latitude * .pi / 180.0
//            let φ2 = B.latitude * .pi / 180.0
//            let Δφ = (B.latitude - A.latitude) * .pi / 180.0
//            let Δλ = (B.longitude - A.longitude) * .pi / 180.0
//            let sinΔφ = sin(Δφ/2)
//            let sinΔλ = sin(Δλ/2)
//            let aa = sinΔφ * sinΔφ + cos(φ1) * cos(φ2) * sinΔλ * sinΔλ
//            let c = 2 * atan2(sqrt(aa), sqrt(1-aa))
//            return R * c
//        }
//
//        var assignments: [Int] = Array(repeating: 0, count: coords.count)
//        for _ in 0..<10 { // iterate
//            // assign
//            for (i, c) in coords.enumerated() {
//                var best = 0
//                var bestD = Double.greatestFiniteMagnitude
//                for j in 0..<centroids.count {
//                    let d = dist((c.lat, c.lon), (centroids[j].lat, centroids[j].lon))
//                    if d < bestD { bestD = d; best = j }
//                }
//                assignments[i] = best
//            }
//            // recompute centroids
//            var sums = Array(repeating: (lat: 0.0, lon: 0.0, cnt: 0), count: centroids.count)
//            for (i, c) in coords.enumerated() {
//                let a = assignments[i]
//                sums[a].lat += c.lat
//                sums[a].lon += c.lon
//                sums[a].cnt += 1
//            }
//            var changed = false
//            for j in 0..<centroids.count {
//                if sums[j].cnt > 0 {
//                    let newLat = sums[j].lat / Double(sums[j].cnt)
//                    let newLon = sums[j].lon / Double(sums[j].cnt)
//                    if abs(newLat - centroids[j].lat) > 1e-6 || abs(newLon - centroids[j].lon) > 1e-6 {
//                        centroids[j] = (lat: newLat, lon: newLon); changed = true
//                    }
//                }
//            }
//            if !changed { break }
//        }
//
//        // build clusters
//        var clusters: [[Building]] = Array(repeating: [], count: centroids.count)
//        for (i, c) in coords.enumerated() {
//            let a = assignments[i]
//            clusters[a].append(withCoord[c.idx])
//        }
//        // distribute buildings without coords round-robin to clusters
//        var r = 0
//        for b in withoutCoord {
//            clusters[r % clusters.count].append(b); r += 1
//        }
//
//        // Plan each cluster using nearest neighbor planner
//        var out: [[PlannedStop]] = []
//        for cluster in clusters {
//            let p = plan(buildings: cluster, startOffsetMin: 0, visitDurationMin: visitDurationMin, walkingSpeedMetersPerMin: walkingSpeedMetersPerMin)
//            out.append(p)
//        }
//
//        // If days > k, append empty arrays
//        if days > out.count {
//            for _ in out.count..<days { out.append([]) }
//        }
//
//        return out
//    }
//}
