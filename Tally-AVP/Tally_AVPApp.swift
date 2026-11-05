//
//  Tally_AVPApp.swift
//  Tally-AVP
//

import SwiftUI

@main
struct Tally_AVPApp: App {

    @State private var immersionStyle: ImmersionStyle = .mixed
    @State private var panoramaImmersionStyle: ImmersionStyle = .full

    init() {
        // Finish any tip that completed while the app was closed (or after Ask to Buy)
        TipJarStore.shared.listenForTransactions()
    }

    var body: some Scene {

        // ── Main window: city list + photoreal 3D map ─────────────────────────
        WindowGroup {
            CityListVisionView()
        }
        .defaultSize(width: 1400, height: 900)

        // ── Landmark page: opens beside the map when a pin is tapped ─────────
        // Its own window, so it never covers the map and can be moved and turned.
        Window("Landmark", id: LandmarkWindowView.windowID) {
            LandmarkWindowView()
        }
        .defaultSize(width: 520, height: 820)
        .defaultWindowPlacement { _, context in
            // Beside the main window, which is the first one open
            if let main = context.windows.first {
                WindowPlacement(.trailing(main))
            } else {
                WindowPlacement()
            }
        }

        // ── My Trips: the iPhone app's trip planner, shared code ──────────────
        Window("My Trips", id: "trips") {
            MyTripsView()
        }
        .defaultSize(width: 900, height: 800)

        // ── Volumetric city model: opens when user selects a city ─────────────
        // Receives the city name as a String value.
        WindowGroup(id: "city-volume", for: String.self) { $cityName in
            CityVolumeView(cityName: cityName ?? "Detroit")
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.6, height: 0.45, depth: 0.6, in: .meters)

        // ── Globe of every city: opened from the city list's toolbar ──────────
        WindowGroup(id: "globe") {
            GlobeVolumeView()
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.6, height: 0.7, depth: 0.6, in: .meters)

        // ── Immersive walk-through: city at room scale ────────────────────────
        // City name is stored in AppStorage before opening so no value-passing needed.
        ImmersiveSpace(id: "city-immersive") {
            CityImmersiveView()
        }
        .immersionStyle(selection: $immersionStyle, in: .mixed)

        // ── 360° landmark photo: opened from a landmark card's "360° View" ────
        // Receives the building ID. Full immersion: the photo surrounds you.
        ImmersiveSpace(id: PanoramaImmersiveView.spaceID, for: String.self) { $buildingID in
            if let buildingID {
                PanoramaImmersiveView(buildingID: buildingID)
            }
        }
        .immersionStyle(selection: $panoramaImmersionStyle, in: .full)
    }
}
