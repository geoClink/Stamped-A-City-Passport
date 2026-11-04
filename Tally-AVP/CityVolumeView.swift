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
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.dismissWindow)      private var dismissWindow
    @Environment(\.dynamicTypeSize)    private var dynamicTypeSize

    @AppStorage("currentImmersiveCity") private var currentImmersiveCity = "Detroit"
    @State private var isOpeningSpace = false

    @State private var cityEntity: Entity?
    @State private var selectedBuilding: Building?
    @State private var isLoading = true
    /// The model is missing or couldn't be read: show a message instead of an empty box.
    @State private var loadFailed = false
    @State private var yRotation: Float = 0
    @State private var currentScale: Float = 1
    @State private var baseScale:    Float = 1
    @State private var prevDragX:    CGFloat = 0
    @State private var prevMag:      CGFloat = 1

    private var buildings: [Building]   { loadBuildings(for: cityName) }
    private var visitedIDs: Set<String> { VisionStore.shared.visitedIDs }

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
            } else if loadFailed {
                Label("Couldn't open the 3D model of \(cityName).", systemImage: "exclamationmark.triangle")
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
                    // VoiceOver can't reach the 3D model, so its drag, pinch and tap
                    // gestures are offered as actions here instead
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityAction(named: "Show Next Landmark") { selectNextLandmark() }
                    .accessibilityAction(named: "Rotate Left") { rotate(by: -.pi / 8) }
                    .accessibilityAction(named: "Rotate Right") { rotate(by: .pi / 8) }
                    .accessibilityAction(named: "Zoom In") { zoom(by: 1.25) }
                    .accessibilityAction(named: "Zoom Out") { zoom(by: 0.8) }

                Divider().frame(height: 20)

                Button {
                    guard !isOpeningSpace else { return }
                    isOpeningSpace = true
                    currentImmersiveCity = cityName
                    Task {
                        // Only one immersive space can be open: close a 360° landmark view first
                        await dismissImmersiveSpace()
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
                .accessibilityHint("Opens the city around you at room scale")

                Button {
                    selectedBuilding = nil
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .opacity(selectedBuilding != nil ? 1 : 0)
                .accessibilityLabel("Close")
                // Invisible without a card, so keep VoiceOver from landing on it
                .accessibilityHidden(selectedBuilding == nil)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassBackgroundEffect(in: Capsule())
        }
    }

    // MARK: - Load city model

    private func loadCity(into content: RealityViewContent) async {
        // From the app bundle, or from the downloaded asset pack
        guard let url = CityModelStore.shared.modelURL(for: cityName) else {
            print("[CityVolume] No 3D model for \(cityName) on this device")
            loadFailed = true
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
            loadFailed = true
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

    // MARK: - VoiceOver actions (the same changes the gestures make)

    /// Steps through the landmarks in order, since VoiceOver can't tap the model
    private func selectNextLandmark() {
        let mappable = buildings.filter { $0.latitude != nil && $0.longitude != nil }
        guard !mappable.isEmpty else { return }
        let currentIndex = mappable.firstIndex { $0.id == selectedBuilding?.id } ?? -1
        selectedBuilding = mappable[(currentIndex + 1) % mappable.count]
    }

    private func rotate(by angle: Float) {
        yRotation += angle
        cityEntity?.transform.rotation = simd_quatf(angle: yRotation, axis: [0, 1, 0])
    }

    private func zoom(by factor: Float) {
        currentScale = (currentScale * factor).clamped(to: (baseScale * 0.4)...(baseScale * 8))
        cityEntity?.scale = SIMD3(repeating: currentScale)
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
                        .accessibilityLabel("Stamped")
                }
                Text(building.name)
                    .font(.headline)
            }
            if let subtitle = building.styleAndYear {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(building.address)
                .font(.caption)
                .foregroundStyle(.tertiary)

            if !building.description.isEmpty {
                Text(building.description)
                    .font(.caption)
                    // Three lines is a preview; at the largest text sizes that's only a few words
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 8 : 3)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(20)
        .frame(minWidth: 300, maxWidth: 380)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Helpers

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
