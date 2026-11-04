//
//  OpenNearbyIntent.swift
//  Stamped! A City Passport
//
//  "What's Near Me": finds where you are and opens the closest landmark, or the closest
//  city or campus when no landmark is within walking distance. The app opens first, so the
//  location prompt (if it hasn't been answered yet) shows right when you ask.
//

import AppIntents
import CoreLocation

struct OpenNearbyIntent: AppIntent {
    static let title: LocalizedStringResource = "What's Near Me"
    static let description = IntentDescription("Opens the landmark closest to you in Stamped!, or the nearest city or campus when no landmark is close by.")
    static let openAppWhenRun = true

    /// A landmark farther than this isn't "near"; the nearest city opens instead
    static let walkingDistance: CLLocationDistance = 2_000

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let here = try await NearbyLocator.currentLocation()
        let navigation = NavigationManager.shared

        if let landmark = NearbyLocator.nearestLandmark(to: here),
           landmark.distance <= Self.walkingDistance {
            navigation.landmarkRequest = LandmarkRequest(city: landmark.city, buildingID: landmark.building.id)
            navigation.spotlightCity = landmark.city
            return .result(dialog: "\(landmark.building.name) is \(Self.formatted(landmark.distance)) away.")
        }

        guard let city = NearbyLocator.nearestCity(to: here) else {
            throw NearbyError.locationUnavailable
        }
        navigation.spotlightCity = city.city
        return .result(dialog: "The closest place in Stamped! is \(city.city.name), \(Self.formatted(city.distance)) away.")
    }

    /// "350 m", "1.2 mi": the person's own units
    private static func formatted(_ meters: CLLocationDistance) -> String {
        Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }
}

enum NearbyError: Error, CustomLocalizedStringResourceConvertible {
    case locationDenied
    case locationUnavailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .locationDenied:
            "Stamped! needs your location to find what's near you. You can turn it on in Settings, under Privacy & Security, Location Services."
        case .locationUnavailable:
            "Stamped! couldn't find your location. Try again in a moment."
        }
    }
}

enum NearbyLocator {
    /// One fresh location. Asks for "While Using the App" permission if the person hasn't
    /// answered yet, and the wait gives up after 30 seconds.
    @MainActor static func currentLocation() async throws -> CLLocation {
        #if os(macOS)
        // The Mac has no CLServiceSession, so ask the older way; the manager must stay alive until we're done
        let manager = CLLocationManager()
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        defer { withExtendedLifetime(manager) {} }
        #else
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        #endif

        return try await withThrowingTaskGroup(of: CLLocation?.self) { group in
            group.addTask {
                for try await update in CLLocationUpdate.liveUpdates() {
                    if let location = update.location { return location }
                    if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                        throw NearbyError.locationDenied
                    }
                }
                return nil
            }
            group.addTask {
                try await Task.sleep(for: .seconds(30))
                return nil
            }
            // Whichever finishes first wins: a location, a refusal, or the timeout
            let first = try await group.next() ?? nil
            group.cancelAll()
            guard let location = first else { throw NearbyError.locationUnavailable }
            return location
        }
    }

    /// The closest landmark with coordinates, in any city or campus
    static func nearestLandmark(to here: CLLocation) -> (building: Building, city: CityLocation.City, distance: CLLocationDistance)? {
        var nearest: (building: Building, city: CityLocation.City, distance: CLLocationDistance)?
        for city in CityLocation.City.allCases {
            for building in city.buildings {
                guard let latitude = building.latitude, let longitude = building.longitude else { continue }
                let distance = here.distance(from: CLLocation(latitude: latitude, longitude: longitude))
                if distance < nearest?.distance ?? .infinity {
                    nearest = (building, city, distance)
                }
            }
        }
        return nearest
    }

    /// The city or campus whose centre is closest
    static func nearestCity(to here: CLLocation) -> (city: CityLocation.City, distance: CLLocationDistance)? {
        CityLocation.City.allCases
            .map { city in
                (city: city, distance: here.distance(from: CLLocation(latitude: city.coordinate.lat, longitude: city.coordinate.lon)))
            }
            .min { $0.distance < $1.distance }
    }
}
