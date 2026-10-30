//
//  PanoramaImmersiveView.swift
//  Tally-AVP
//
//  "Stand inside" a landmark: a 360° photo from Wikimedia Commons painted on
//  the inside of a huge sphere around the viewer. A floating panel shows the
//  landmark's name, the photo credit the licence requires, and an Exit button.
//

import SwiftUI
import RealityKit
import ImageIO

struct PanoramaImmersiveView: View {
    static let spaceID = "landmark-panorama"

    let buildingID: String

    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    private enum LoadState { case loading, loaded, failed }
    @State private var loadState: LoadState = .loading
    /// Holds the sphere; empty until the photo has loaded
    @State private var sphereHolder = Entity()

    private var panorama: LandmarkPanorama? { PanoramaCatalog.panorama(for: buildingID) }

    var body: some View {
        RealityView { content, attachments in
            content.add(sphereHolder)
            // The panel floats a metre ahead, a little below eye level
            if let panel = attachments.entity(for: "panel") {
                panel.position = SIMD3(0, 1.1, -1.0)
                panel.components.set(BillboardComponent())
                content.add(panel)
            }
        } attachments: {
            Attachment(id: "panel") { infoPanel }
        }
        // .task restarts if the building changes; it's cancelled when the space closes
        .task(id: buildingID) { await loadPanorama() }
    }

    // MARK: - Loading

    private func loadPanorama() async {
        guard let panorama else {
            loadState = .failed
            return
        }
        loadState = .loading
        do {
            let image = try await PanoramaImageLoader.image(from: panorama.imageURL)
            let texture = try await TextureResource(image: image, options: .init(semantic: .color))
            sphereHolder.children.removeAll()
            sphereHolder.addChild(Self.makeSphere(texture: texture))
            loadState = .loaded
        } catch is CancellationError {
            // The space closed while loading: nothing to show
        } catch {
            print("[Panorama] Couldn't load \(panorama.fileTitle): \(error)")
            loadState = .failed
        }
    }

    /// A sphere big enough to feel like the horizon, seen from the inside.
    private static func makeSphere(texture: TextureResource) -> ModelEntity {
        var material = UnlitMaterial()   // unlit: the photo already has its own lighting
        material.color = .init(texture: .init(texture))
        let sphere = ModelEntity(mesh: .generateSphere(radius: 1000), materials: [material])
        // A sphere's faces point outwards. Flipping x turns it inside out, so we see
        // the inside, and it also un-mirrors the photo (we look at it from within).
        sphere.scale = SIMD3(-1, 1, 1)
        // Centre it on the viewer's head rather than their feet
        sphere.position = SIMD3(0, 1.5, 0)
        return sphere
    }

    // MARK: - Floating panel

    private var infoPanel: some View {
        VStack(spacing: 14) {
            Text(panorama?.landmarkName ?? "")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            switch loadState {
            case .loading:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading 360° view…").font(.subheadline)
                }
            case .failed:
                Label("Couldn't load the 360° view.", systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                // Retrying only helps when there's a photo to download
                if panorama != nil {
                    Button("Try Again") {
                        Task { await loadPanorama() }
                    }
                    .buttonStyle(.bordered)
                }
            case .loaded:
                EmptyView()
            }

            if let panorama {
                // Credit required by the photo's Creative Commons licence
                Text("Photo: \(panorama.author), \(panorama.licenseName), via Wikimedia Commons")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Link("Photo Details", destination: panorama.filePageURL)
                    .font(.caption)
            }

            Button {
                Task { await dismissImmersiveSpace() }
            } label: {
                Label("Exit", systemImage: "xmark")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(24)
        .frame(width: 440)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - Downloading the photo

enum PanoramaImageLoader {
    enum LoadError: Error { case badResponse, notAnImage }

    /// Downloads the photo and decodes it off the main thread.
    nonisolated static func image(from url: URL) async throws -> CGImage {
        var request = URLRequest(url: url)
        // Wikimedia asks apps to identify themselves
        request.setValue("Stamped-A-City-Passport/2.7 (visionOS)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LoadError.badResponse
        }
        try Task.checkCancellation()
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw LoadError.notAnImage
        }
        return image
    }
}
