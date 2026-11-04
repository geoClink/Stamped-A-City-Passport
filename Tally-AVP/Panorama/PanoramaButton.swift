//
//  PanoramaButton.swift
//  Tally-AVP
//
//  "360° View" button for a landmark card. Shows nothing when the landmark
//  has no panorama, so a card can always include it.
//

import SwiftUI

/// The bundled panoramas, decoded once.
enum PanoramaCatalog {
    static let byBuildingID: [String: LandmarkPanorama] = LandmarkPanorama.loadAll()

    static func panorama(for buildingID: String) -> LandmarkPanorama? {
        byBuildingID[buildingID]
    }
}

struct PanoramaButton: View {
    let building: Building

    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var isOpening = false

    var body: some View {
        if PanoramaCatalog.panorama(for: building.id) != nil {
            Button {
                Task { await open() }
            } label: {
                Label("360° View", systemImage: "pano")
            }
            .tint(.teal)
            .disabled(isOpening)
            .accessibilityHint("Stand inside this landmark in a 360° photo")
        }
    }

    private func open() async {
        guard !isOpening else { return }
        isOpening = true
        defer { isOpening = false }
        // visionOS allows one immersive space at a time, so close any open one
        // (the Detroit walk-through, or another landmark's panorama) first.
        // Dismissing when nothing is open does nothing.
        await dismissImmersiveSpace()
        _ = await openImmersiveSpace(id: PanoramaImmersiveView.spaceID, value: building.id)
    }
}
