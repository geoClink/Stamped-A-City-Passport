//
//  GlobeMath.swift
//  Tally-AVP
//
//  The data and math behind the 3D globe: one pin per city, and the helper
//  that turns a latitude/longitude into a point on a sphere.
//

import Foundation
import simd

/// One city as it appears on the globe.
struct GlobeCity: Identifiable {
    let name: String
    let latitude: Double
    let longitude: Double
    let stampedCount: Int

    var id: String { name }
    var isStamped: Bool { stampedCount > 0 }
}

enum GlobeMath {

    /// Converts a latitude/longitude (in degrees) to a point on a sphere
    /// centred at the origin.
    ///
    /// RealityKit axes: +x is right, +y is up, +z points toward the viewer.
    /// - Latitude tilts the point up (+y) or down (-y) from the equator.
    /// - Longitude swings it around the vertical axis. Longitude 0 faces the
    ///   viewer (+z) and 90°E points right (+x), like looking at a real globe.
    static func position(latitude: Double, longitude: Double, radius: Float) -> SIMD3<Float> {
        let lat = Float(latitude * .pi / 180)   // degrees → radians
        let lon = Float(longitude * .pi / 180)

        // cos(lat) is how far the point sits from the vertical axis: 1 at the
        // equator, 0 at the poles. sin/cos(lon) then split that distance
        // between the x and z directions.
        let x = radius * cos(lat) * sin(lon)
        let y = radius * sin(lat)
        let z = radius * cos(lat) * cos(lon)
        return SIMD3(x, y, z)
    }

    /// The middle value of a list (nil if empty). The median ignores the odd
    /// landmark that's far from downtown, so the pin lands in the city centre.
    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    /// Every city that has at least one landmark with coordinates.
    @MainActor
    static func cities(from store: VisionStore) -> [GlobeCity] {
        store.cityNames.compactMap { name in
            let buildings = store.buildings(for: name)
            let latitudes = buildings.compactMap(\.latitude)
            let longitudes = buildings.compactMap(\.longitude)
            guard let latitude = median(latitudes), let longitude = median(longitudes) else {
                return nil
            }
            return GlobeCity(
                name: name,
                latitude: latitude,
                longitude: longitude,
                stampedCount: store.visitedCount(for: name)
            )
        }
    }
}
