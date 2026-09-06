//
//  ProximityManager.swift
//  Stamped!
//
//  Monitors the 20 closest unvisited landmarks using iOS geofencing.
//  iOS handles this in hardware — no GPS polling, no battery drain.
//  Sends a local notification when the user walks within 100m of a landmark.
//
//  Before this works you must add two keys in Xcode:
//  Target → Info → + key:
//    NSLocationWhenInUseUsageDescription  → "Stamped! shows nearby landmarks while you explore."
//    NSLocationAlwaysAndWhenInUseUsageDescription → "Stamped! alerts you when you're near a landmark, even in the background."
//

import CoreLocation
import UserNotifications
import SwiftUI
import Combine

@MainActor
final class ProximityManager: NSObject, ObservableObject {
    static let shared = ProximityManager()

    // Non-nil when the user is standing within 100m of a landmark they haven't visited
    @Published var nearbyBuilding: Building? = nil
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()
    // Maps region identifier (building.id) → Building so delegate callbacks can look up the name
    private var monitoredBuildings: [String: Building] = [:]

    private override init() {
        super.init()
        locationManager.delegate = self
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Permissions

    func requestPermissions() {
        // Ask for "Always" so geofences fire in the background.
        // iOS requires WhenInUse to be granted first — it will prompt in sequence.
        locationManager.requestAlwaysAuthorization()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Start monitoring a city's buildings

    func startMonitoring(buildings: [Building], visitedIDs: Set<String>, userLocation: CLLocation? = nil) {
        // Clear any previously monitored regions
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        monitoredBuildings.removeAll()
        nearbyBuilding = nil

        // Only buildings with coordinates that the user hasn't visited yet
        let candidates = buildings.filter {
            $0.latitude != nil && $0.longitude != nil && !visitedIDs.contains($0.id)
        }

        // iOS limit is 20 regions. If we have a user location, pick the 20 closest.
        // Otherwise just take the first 20.
        let toMonitor: [Building]
        if let userLoc = userLocation {
            toMonitor = Array(
                candidates.sorted {
                    let a = CLLocation(latitude: $0.latitude!, longitude: $0.longitude!)
                    let b = CLLocation(latitude: $1.latitude!, longitude: $1.longitude!)
                    return userLoc.distance(from: a) < userLoc.distance(from: b)
                }
                .prefix(20)
            )
        } else {
            toMonitor = Array(candidates.prefix(20))
        }

        for building in toMonitor {
            guard let lat = building.latitude, let lon = building.longitude else { continue }
            let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let region = CLCircularRegion(center: center, radius: 100, identifier: building.id)
            region.notifyOnEntry = true
            region.notifyOnExit = false
            locationManager.startMonitoring(for: region)
            monitoredBuildings[building.id] = building
        }

        print("[Proximity] Monitoring \(toMonitor.count) landmarks")
    }

    func stopMonitoring() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        monitoredBuildings.removeAll()
        nearbyBuilding = nil
    }

    // MARK: - Notification

    private func sendNearbyNotification(for building: Building) {
        let content = UNMutableNotificationContent()
        content.title = "You're nearby!"
        content.body = "You're within 100m of \(building.name). Tap to check it off your passport."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "proximity_\(building.id)",
            content: content,
            trigger: nil // fire immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - CLLocationManagerDelegate

extension ProximityManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            guard let building = self.monitoredBuildings[region.identifier] else { return }
            self.nearbyBuilding = building
            self.sendNearbyNotification(for: building)
            print("[Proximity] Entered region: \(building.name)")
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            if self.nearbyBuilding?.id == region.identifier {
                self.nearbyBuilding = nil
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("[Proximity] Monitoring failed for \(region?.identifier ?? "unknown"): \(error.localizedDescription)")
    }
}
