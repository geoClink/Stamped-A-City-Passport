//
//  CitySceneConfig.swift
//  Stamped! A City Passport
//

import Foundation
import simd

// Mirrors the coordinate math in tools/city-generator/generate.py.
// to_xy(lat, lon) → (x, y_north) in trimesh (Z-up), then converted to Y-up USD:
//   USD x =  x_east  = (lon - centerLon) * lonToM
//   USD y =  height  (up)
//   USD z = -y_north = -(lat - centerLat) * latToM
struct CitySceneConfig {
    let centerLat: Double
    let centerLon: Double

    private var latToM: Double { 111_000 }
    private var lonToM: Double { 111_000 * cos(centerLat * .pi / 180) }

    /// Returns the position of a coordinate in the USDZ scene's local space (metres).
    func scenePosition(lat: Double, lon: Double) -> SIMD3<Float> {
        let x = Float((lon - centerLon) * lonToM)
        let z = Float(-(lat - centerLat) * latToM)
        return SIMD3(x, 0, z)
    }

    /// Inverse of scenePosition — converts a SceneKit hit-test world coordinate back to lat/lon.
    func latLon(sceneX: Float, sceneZ: Float) -> (lat: Double, lon: Double) {
        let lat = Double(-sceneZ) / latToM + centerLat
        let lon = Double(sceneX)  / lonToM + centerLon
        return (lat, lon)
    }

    /// Distance in metres between two lat/lon points, using the local metre-per-degree scale.
    func distanceMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let dx = (lon2 - lon1) * lonToM
        let dy = (lat2 - lat1) * latToM
        return (dx * dx + dy * dy).squareRoot()
    }

    // Add a new entry here whenever a city USDZ is generated.
    // centerLat/Lon must match the CENTER_LAT/CENTER_LON values in generate.py.
    static let all: [String: CitySceneConfig] = [
        // centerLat/Lon must match CENTER_LAT/CENTER_LON in generate.py
        // Computed from bounding box: lat (42.318–42.385), lon (-83.092– -83.025)
        "Detroit": CitySceneConfig(centerLat: 42.3515, centerLon: -83.0585),
    ]

    static func config(for cityName: String) -> CitySceneConfig? {
        all[cityName]
    }
}
