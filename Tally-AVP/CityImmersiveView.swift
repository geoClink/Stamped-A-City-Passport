//
//  CityImmersiveView.swift
//  Tally-AVP
//
//  Mixed-immersive city experience.
//  Controls are RealityView attachments with BillboardComponent —
//  placed at z=−0.3 m so they are always in front of the city model (which
//  starts at z≈−4.5 m and extends to z≈+1.5 m in world space).
//  Stadium crowd audio is a RealityKit SpatialAudioComponent so the OS
//  handles head-tracked 3D positioning automatically.
//

import SwiftUI
import RealityKit
import Combine

struct CityImmersiveView: View {

    @AppStorage("currentImmersiveCity") private var cityName = "Detroit"
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var cityEntity:  Entity?
    @State private var sunEntity:   Entity?
    @State private var selectedBuilding: Building?
    @State private var isLoading   = true
    @State private var cycleTime: Double = 0.5   // 0=midnight, 0.5=noon
    @State private var isRaining   = false
    @State private var showingCredits = false
    @State private var streetMode  = false
    @State private var dayNightLocked = false
    @State private var isNight = false

    // Navigation
    @State private var overviewScale: Float = 0.001
    @State private var cityBaseScale: Float = 0.001
    @State private var cityBasePos: SIMD3<Float> = SIMD3(0, -0.5, -1.5)

    // Spatial audio controllers (kept alive so audio keeps playing)
    @State private var baseballCtrl: AudioPlaybackController?
    @State private var footballCtrl: AudioPlaybackController?

    private let dayTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    private var buildings: [Building] { loadBuildings(for: cityName) }
    private var visitedIDs: Set<String> { VisionStore.shared.visitedIDs }

    var body: some View {
        RealityView { content, attachments in
            await placeCity(in: content)
            placeSun(in: content)

            // ── Control bar — 0.3 m in front, below eye level, always faces user ──
            if let ctrl = attachments.entity(for: "controls") {
                ctrl.position = SIMD3(0, -0.3, -0.3)
                ctrl.components.set(BillboardComponent())
                content.add(ctrl)
            }
            // ── Building info panel — left of center, eye level ─────────────────
            if let info = attachments.entity(for: "info") {
                info.position = SIMD3(-0.45, 0.05, -0.3)
                info.components.set(BillboardComponent())
                info.isEnabled = false
                content.add(info)
            }
        } update: { _, attachments in
            attachments.entity(for: "info")?.isEnabled = (selectedBuilding != nil)
        } attachments: {
            Attachment(id: "controls") { controlBar }
            Attachment(id: "info") {
                if let b = selectedBuilding { buildingPanel(b) }
            }
        }
        .onReceive(dayTimer) { _ in
            if !dayNightLocked {
                cycleTime += (1.0 / 30.0) / 120.0
                if cycleTime >= 1.0 { cycleTime -= 1.0 }
            }
            applyDayNight()
            CityAudioManager.shared.updateForTime(cycleTime: cycleTime)
        }
        .onAppear   { CityAudioManager.shared.startAll() }
        .onDisappear { CityAudioManager.shared.stopAll() }
        .onChange(of: isRaining) { _, v in CityAudioManager.shared.setRaining(v) }
        .onChange(of: isNight) { _, night in
            guard dayNightLocked else { return }
            cycleTime = night ? 0.0 : 0.5
        }
        .sheet(isPresented: $showingCredits) { SoundCreditsView() }
        // Tap on any entity → identify nearest building
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in identifyBuilding(at: value) }
        )
        // Drag → pan city XZ
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    guard let e = cityEntity else { return }
                    e.position = SIMD3(
                        cityBasePos.x + Float(value.translation.width)  * 0.003,
                        cityBasePos.y,
                        cityBasePos.z - Float(value.translation.height) * 0.003
                    )
                }
                .onEnded { _ in
                    if let p = cityEntity?.position { cityBasePos = p }
                }
        )
        // Pinch → zoom
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    guard let e = cityEntity else { return }
                    let raw = cityBaseScale * Float(value.magnification)
                    e.scale = SIMD3(repeating: max(overviewScale * 0.5, min(overviewScale * 10, raw)))
                }
                .onEnded { _ in
                    if let s = cityEntity?.scale.x { cityBaseScale = s }
                }
        )
    }

    // MARK: - Place city + collision + spatial audio

    private func placeCity(in content: RealityViewContent) async {
        guard let url = Bundle.main.url(forResource: cityName.lowercased(), withExtension: "usdz") else {
            print("[City] Missing \(cityName.lowercased()).usdz")
            isLoading = false
            return
        }
        do {
            let entity = try await Entity(contentsOf: url)

            // Auto-fit: longest axis ≈ 6 m
            let bounds = entity.visualBounds(relativeTo: nil)
            let longest = max(bounds.extents.x, bounds.extents.z)
            let scale: Float = longest > 0 ? 6.0 / longest : 0.001
            entity.scale    = SIMD3(repeating: scale)
            // Lower the city well below eye level so the user always looks down at it
            // and never sees the underside of the ground-plane mesh.
            entity.position = SIMD3(0, -1.1, -1.5)
            overviewScale   = scale
            cityBaseScale   = scale
            cityBasePos     = SIMD3(0, -1.1, -1.5)

            // Collision + input target go directly on the entity with fixed large values —
            // no visualBounds call needed, so zero-extents before first render can't break it.
            // 10 000 × 5 000 × 10 000 local units → ~8 × 4 × 8 m world at overview scale.
            entity.components.set(InputTargetComponent(allowedInputTypes: .indirect))
            entity.components.set(CollisionComponent(
                shapes: [.generateBox(width: 10_000, height: 5_000, depth: 10_000)],
                isStatic: true
            ))

            content.add(entity)
            cityEntity = entity
            isLoading  = false

            // Place stadium spatial-audio sources now that we know the scale
            await placeStadiumAudio(in: content, cityScale: scale, cityPos: entity.position)
        } catch {
            print("[City] Load error: \(error)")
            isLoading = false
        }
    }

    // MARK: - Stadium spatial audio

    private func placeStadiumAudio(
        in content: RealityViewContent,
        cityScale: Float,
        cityPos: SIMD3<Float>
    ) async {
        guard let config = CitySceneConfig.config(for: cityName) else { return }

        func worldPos(lat: Double, lon: Double) -> SIMD3<Float> {
            let s = config.scenePosition(lat: lat, lon: lon)
            return SIMD3(
                cityPos.x + s.x * cityScale,
                cityPos.y,
                cityPos.z + s.z * cityScale
            )
        }

        // Default distance attenuation is inverse-square; RealityKit + head tracking handle the rest.
        var spatialCfg = SpatialAudioComponent()
        spatialCfg.directLevel = 0
        spatialCfg.reverbLevel = -12

        // ── Comerica Park — baseball crowd ──────────────────────────────────────
        if let resource = try? await AudioFileResource(
            named: "baseball_crowd",
            configuration: .init(shouldLoop: true, shouldRandomizeStartTime: true)
        ) {
            let e = Entity()
            e.position = worldPos(lat: 42.3390, lon: -83.0485)
            e.components.set(spatialCfg)
            baseballCtrl = e.playAudio(resource)
            content.add(e)
        } else {
            print("[Audio] baseball_crowd not found for spatial playback")
        }

        // ── Ford Field — football crowd ─────────────────────────────────────────
        if let resource = try? await AudioFileResource(
            named: "football_crowd",
            configuration: .init(shouldLoop: true, shouldRandomizeStartTime: true)
        ) {
            let e = Entity()
            e.position = worldPos(lat: 42.3400, lon: -83.0456)
            e.components.set(spatialCfg)
            footballCtrl = e.playAudio(resource)
            content.add(e)
        } else {
            print("[Audio] football_crowd not found for spatial playback")
        }
    }

    // MARK: - Street mode

    private func toggleStreetMode() {
        guard let entity = cityEntity else { return }
        streetMode.toggle()
        if streetMode {
            cityBaseScale = overviewScale * 5
            cityBasePos   = SIMD3(0, -1.7, 0)
        } else {
            cityBaseScale = overviewScale
            cityBasePos   = SIMD3(0, -1.1, -1.5)
        }
        var t = entity.transform
        t.scale       = SIMD3(repeating: cityBaseScale)
        t.translation = cityBasePos
        entity.move(to: t, relativeTo: nil, duration: 0.6, timingFunction: .easeInOut)
    }

    // MARK: - Sun / day-night

    private func placeSun(in content: RealityViewContent) {
        let sun = Entity()
        var light = DirectionalLightComponent()
        light.intensity = 4000
        sun.components.set(light)
        sun.orientation = simd_quatf(angle: -.pi / 4, axis: SIMD3(1, 0, 0))
        content.add(sun)
        sunEntity = sun
    }

    private func applyDayNight() {
        let angle     = Float((cycleTime - 0.25) * 2 * .pi)
        let elevation = sin(angle)
        let dayFactor = max(0, elevation)
        sunEntity?.orientation =
            simd_quatf(angle: Float(cycleTime * 2 * .pi), axis: SIMD3(0, 1, 0)) *
            simd_quatf(angle: -elevation * .pi / 2,        axis: SIMD3(1, 0, 0))
        if var l = sunEntity?.components[DirectionalLightComponent.self] {
            l.intensity = dayFactor * 5000
            sunEntity?.components.set(l)
        }
    }

    // MARK: - Tap → nearest building

    private func identifyBuilding(at value: EntityTargetValue<SpatialTapGesture.Value>) {
        guard let cityEntity,
              let config = CitySceneConfig.config(for: cityName) else { return }

        let wp = SIMD3<Float>(Float(value.location3D.x),
                              Float(value.location3D.y),
                              Float(value.location3D.z))
        let local = cityEntity.convert(position: wp, from: nil)
        let (tapLat, tapLon) = config.latLon(sceneX: local.x / cityEntity.scale.x,
                                              sceneZ: local.z / cityEntity.scale.z)

        var nearest: Building?
        var minDist = Double.infinity
        for b in buildings {
            guard let bLat = b.latitude, let bLon = b.longitude else { continue }
            let d = config.distanceMeters(lat1: tapLat, lon1: tapLon, lat2: bLat, lon2: bLon)
            if d < minDist { minDist = d; nearest = b }
        }
        if let nearest, minDist < 1500 {
            selectedBuilding = nearest
        }
    }

    // MARK: - Attachment views

    private var controlBar: some View {
        VStack(spacing: 10) {
            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading \(cityName)…").font(.subheadline)
                }
            } else {
                // Row 1: navigation
                HStack(spacing: 14) {
                    Text(cityName).font(.headline)

                    Divider().frame(height: 20)

                    Button { toggleStreetMode() } label: {
                        // Typed as LocalizedStringKey so both titles get translated
                        let title: LocalizedStringKey = streetMode ? "City View" : "Street View"
                        Label(title, systemImage: streetMode ? "building.2" : "figure.walk")
                    }
                    .buttonStyle(.bordered)
                    .tint(streetMode ? .purple : .green)

                    if selectedBuilding != nil {
                        Button { selectedBuilding = nil } label: {
                            Label("Dismiss", systemImage: "xmark")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button { Task { await dismissImmersiveSpace() } } label: {
                        Label("Exit", systemImage: "arrow.down.forward")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                // Row 2: environment
                HStack(spacing: 14) {
                    // Day / Night toggle
                    Button {
                        if dayNightLocked {
                            isNight.toggle()
                        } else {
                            dayNightLocked = true
                            isNight = cycleTime < 0.25 || cycleTime > 0.75
                            isNight.toggle()
                        }
                    } label: {
                        let title: LocalizedStringKey = dayNightLocked ? (isNight ? "Night" : "Day") : "Auto"
                        Label(
                            title,
                            systemImage: dayNightLocked
                                ? (isNight ? "moon.stars.fill" : "sun.max.fill")
                                : (cycleTime > 0.25 && cycleTime < 0.75 ? "sun.max.fill" : "moon.stars.fill")
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(dayNightLocked ? (isNight ? .indigo : .orange) : .gray)

                    if dayNightLocked {
                        Button { dayNightLocked = false } label: {
                            Label("Auto Cycle", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .tint(.gray)
                    }

                    // Weather
                    Button { isRaining.toggle() } label: {
                        let title: LocalizedStringKey = isRaining ? "Raining" : "Clear"
                        Label(title, systemImage: isRaining ? "cloud.rain.fill" : "sun.max.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(isRaining ? .blue : .yellow)

                    // Credits
                    Button { showingCredits = true } label: {
                        Label("Credits", systemImage: "music.note.list")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20))
    }

    private func buildingPanel(_ building: Building) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if visitedIDs.contains(building.id) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.orange).font(.title3)
                }
                Text(building.name).font(.title3.bold()).lineLimit(2)
            }
            Text("\(String(building.yearBuilt)) · \(building.buildingStyle)")
                .font(.subheadline).foregroundStyle(.secondary)
            Text(building.address)
                .font(.caption).foregroundStyle(.tertiary)
            if !building.description.isEmpty {
                Divider()
                Text(building.description)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(5)
            }
        }
        .padding(20)
        .frame(minWidth: 300, maxWidth: 380)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 18))
    }
}
