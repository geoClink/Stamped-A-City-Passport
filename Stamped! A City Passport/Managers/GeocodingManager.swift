import Foundation
import CoreLocation

// Simple async geocoding manager with in-memory and optional disk caching.
// Usage:
//   let coord = await GeocodingManager.shared.coordinate(for: address)
//   let meters = await GeocodingManager.shared.distanceBetween(addressA, addressB)

final class GeocodingManager: NSObject {
    static let shared = GeocodingManager()

    private let geocoder = CLGeocoder()
    private var cache: [String: CLLocationCoordinate2D] = [:]
    private let cacheQueue = DispatchQueue(label: "com.stamped.geocache")

    private override init() {
        super.init()
        // Optionally, load persisted cache here if you add persistence
    }

    // Return cached coordinate if available
    func cachedCoordinate(for address: String) -> CLLocationCoordinate2D? {
        var result: CLLocationCoordinate2D?
        cacheQueue.sync { result = cache[address] }
        return result
    }

    // Async geocode address to coordinate, with caching.
    func coordinate(for address: String) async -> CLLocationCoordinate2D? {
        // Trim / normalize address
        let key = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty { return nil }

        if let cached = cachedCoordinate(for: key) {
            return cached
        }

        return await withCheckedContinuation { cont in
            // Use geocodeAddressString; allow cancellation by ignoring results if needed
            geocoder.geocodeAddressString(key) { placemarks, error in
                if let err = error {
                    // Common errors: network, no result, etc.
                    print("Geocoding error for [\(key)]: \(err.localizedDescription)")
                    cont.resume(returning: nil)
                    return
                }

                guard let loc = placemarks?.first?.location else {
                    cont.resume(returning: nil)
                    return
                }

                let coord = loc.coordinate
                // cache
                self.cacheQueue.async {
                    self.cache[key] = coord
                }

                cont.resume(returning: coord)
            }
        }
    }

    // Compute real-world distance (meters) between two addresses
    func distanceBetween(_ addressA: String, _ addressB: String) async -> CLLocationDistance? {
        async let a = coordinate(for: addressA)
        async let b = coordinate(for: addressB)

        guard let ca = await a, let cb = await b else { return nil }
        let la = CLLocation(latitude: ca.latitude, longitude: ca.longitude)
        let lb = CLLocation(latitude: cb.latitude, longitude: cb.longitude)
        return la.distance(from: lb)
    }

    // Convenience: compute distances between sequential itinerary steps
    func distancesAlong(steps: [String]) async -> [CLLocationDistance?] {
        // steps: array of addresses in order
        var results: [CLLocationDistance?] = []
        guard steps.count >= 2 else { return results }
        for i in 1..<steps.count {
            let d = await distanceBetween(steps[i-1], steps[i])
            results.append(d)
        }
        return results
    }
}
