//
//  CityVolumeView.swift
//  Tally-AVP
//
//  Loads the city USDZ into a volumetric RealityKit window.
//  • Pinch anywhere on the city to identify the nearest landmark.
//  • Drag to rotate, pinch-to-scale to resize the miniature.
//  • Tap "Enter City" to open the full immersive walk-through.
//
//  Shared files needed in Xcode target membership:
//    Models/Building.swift
//    CityExplore/CitySceneConfig.swift
//    Resources/BuildingRegistry.json
//

import SwiftUI
import RealityKit

struct CityVolumeView: View {

    let cityName: String

    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow)      private var dismissWindow

    @AppStorage("currentImmersiveCity") private var currentImmersiveCity = "Detroit"
    @State private var isOpeningSpace = false

    @State private var cityEntity: Entity?
    @State private var selectedBuilding: Building?
    @State private var isLoading = true
    @State private var yRotation: Float = 0
    @State private var currentScale: Float = 1
    @State private var baseScale:    Float = 1
    @State private var prevDragX:    CGFloat = 0
    @State private var prevMag:      CGFloat = 1

    private var buildings: [Building]   { loadBuildings(for: cityName) }
    private var visitedIDs: Set<String> { visionVisitedIDs() }

    var body: some View {
        ZStack {
            RealityView { content in
                await loadCity(into: content)
            }
            .gesture(dragGesture)
            .gesture(magnifyGesture)
            .gesture(tapGesture)

            if isLoading {
                ProgressView("Loading \(cityName)…")
                    .padding(20)
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
            }
        }
        // ── Building info card as a volume ornament ───────────────────────────
        .ornament(
            visibility: selectedBuilding != nil ? .visible : .hidden,
            attachmentAnchor: .scene(.bottom),
            contentAlignment: .top
        ) {
            if let building = selectedBuilding {
                buildingCard(building)
            }
        }
        // ── "Enter City" button as a bottom ornament ──────────────────────────
        .ornament(
            visibility: .visible,
            attachmentAnchor: .scene(.bottom),
            contentAlignment: .bottom
        ) {
            HStack(spacing: 16) {
                Text(cityName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Divider().frame(height: 20)

                Button {
                    guard !isOpeningSpace else { return }
                    isOpeningSpace = true
                    currentImmersiveCity = cityName
                    Task {
                        await openImmersiveSpace(id: "city-immersive")
                        isOpeningSpace = false
                    }
                } label: {
                    Label("Enter City", systemImage: "arrow.up.forward")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(isOpeningSpace)

                Button {
                    selectedBuilding = nil
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .opacity(selectedBuilding != nil ? 1 : 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassBackgroundEffect(in: Capsule())
        }
    }

    // MARK: - Load city model

    private func loadCity(into content: RealityViewContent) async {
        guard let url = Bundle.main.url(forResource: cityName.lowercased(), withExtension: "usdz") else {
            isLoading = false
            return
        }
        do {
            let entity = try await Entity(contentsOf: url)

            // Scale the city to fit in about 0.45 m of the volume's width
            let bounds = entity.visualBounds(relativeTo: nil)
            let longest = max(bounds.extents.x, bounds.extents.z)
            if longest > 0 {
                baseScale = 0.45 / longest
                entity.scale = SIMD3(repeating: baseScale)
                currentScale = baseScale
            }

            // Center the model in the volume
            entity.position = SIMD3(0, -0.05, 0)

            // Make the city tappable via an invisible collision box
            let scaledBounds = entity.visualBounds(relativeTo: entity)
            let collisionBox = Entity()
            collisionBox.components.set(InputTargetComponent(allowedInputTypes: .indirect))
            collisionBox.components.set(CollisionComponent(
                shapes: [.generateBox(size: scaledBounds.extents)],
                isStatic: true
            ))
            collisionBox.position = scaledBounds.center
            entity.addChild(collisionBox)

            content.add(entity)
            cityEntity = entity
            isLoading = false
        } catch {
            print("[CityVolume] Failed to load \(cityName): \(error)")
            isLoading = false
        }
    }

    // MARK: - Gestures

    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                guard let cityEntity,
                      let config = CitySceneConfig.config(for: cityName) else { return }

                // Convert world-space tap → entity local → scene space → lat/lon
                let worldPt  = SIMD3<Float>(Float(value.location3D.x),
                                            Float(value.location3D.y),
                                            Float(value.location3D.z))
                let localPt  = cityEntity.convert(position: worldPt, from: nil)
                let sceneX   = localPt.x / cityEntity.scale.x
                let sceneZ   = localPt.z / cityEntity.scale.z
                let (tapLat, tapLon) = config.latLon(sceneX: sceneX, sceneZ: sceneZ)

                var nearest: Building?
                var minDist  = Double.infinity
                for building in buildings {
                    guard let bLat = building.latitude,
                          let bLon = building.longitude else { continue }
                    let d = config.distanceMeters(lat1: tapLat, lon1: tapLon,
                                                  lat2: bLat,  lon2: bLon)
                    if d < minDist { minDist = d; nearest = building }
                }
                if let nearest, minDist < 1500 {
                    selectedBuilding = nearest
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let delta = Float(value.translation.width - prevDragX) * 0.008
                yRotation += delta
                cityEntity?.transform.rotation = simd_quatf(angle: yRotation, axis: [0, 1, 0])
                prevDragX = value.translation.width
            }
            .onEnded { _ in prevDragX = 0 }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let factor = Float(value.magnification / prevMag)
                currentScale = (currentScale * factor).clamped(to: (baseScale * 0.4)...(baseScale * 8))
                cityEntity?.scale = SIMD3(repeating: currentScale)
                prevMag = value.magnification
            }
            .onEnded { _ in prevMag = 1 }
    }

    // MARK: - Building card ornament

    private func buildingCard(_ building: Building) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if visitedIDs.contains(building.id) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.orange)
                }
                Text(building.name)
                    .font(.headline)
            }
            Text("\(building.yearBuilt) · \(building.buildingStyle)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(building.address)
                .font(.caption)
                .foregroundStyle(.tertiary)

            if !building.description.isEmpty {
                Text(building.description)
                    .font(.caption)
                    .lineLimit(3)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(20)
        .frame(minWidth: 300, maxWidth: 380)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Helpers

private func visionVisitedIDs() -> Set<String> {
    // Read from the same UserDefaults key the iOS app writes to.
    let saved = UserDefaults.standard.stringArray(forKey: "GlobalVisitedBuildingsKey") ?? []
    return Set(saved)
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
