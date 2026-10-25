//
//  CityExploreView.swift
//  Stamped! A City Passport
//
//  Object mode  — spin/zoom the city in a plain 3D viewer (SceneKit, no camera)
//  AR mode      — place the city miniature on a real surface using RealityKit
//

import SwiftUI
import MapKit

#if os(iOS)
import RealityKit
import SceneKit
import Combine

// MARK: - Mode

enum CityExploreMode { case object, ar }

// MARK: - Component

struct BuildingIdentityComponent: Component {
    let buildingID: String
}

// MARK: - Root View

struct CityExploreView: View {
    let buildings: [Building]
    let visitedIDs: Set<String>
    let cityName: String

    @StateObject private var vm: CityExploreViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var mode: CityExploreMode = .object
    @State private var lookAroundScene: MKLookAroundScene?
    @State private var showingLookAround = false
    @State private var isRaining = false
    @State private var showingCredits = false

    init(buildings: [Building], visitedIDs: Set<String>, cityName: String) {
        self.buildings = buildings
        self.visitedIDs = visitedIDs
        self.cityName = cityName
        _vm = StateObject(wrappedValue: CityExploreViewModel(
            cityName: cityName, buildings: buildings
        ))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            switch mode {
            case .object:
                if let url = Bundle.main.url(forResource: cityName.lowercased(), withExtension: "usdz") {
                    CityObjectView(
                        usdzURL: url,
                        buildings: buildings,
                        cityName: cityName,
                        visitedIDs: visitedIDs,
                        onBuildingSelected: { vm.selectedBuilding = $0 }
                    )
                    .ignoresSafeArea()
                } else {
                    Text("No 3D model available for \(cityName) yet.")
                        .foregroundStyle(.secondary)
                }

            case .ar:
                CityARView(
                    buildings: buildings,
                    visitedIDs: visitedIDs,
                    cityName: cityName,
                    vm: vm
                )
                .ignoresSafeArea()
            }

            // Building info card — shown in both Object and AR modes
            if let building = vm.selectedBuilding {
                buildingCard(building)
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            header
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .animation(.spring(duration: 0.3), value: vm.selectedBuilding?.id)
        .onChange(of: isRaining) { _, value in CityAudioManager.shared.setRaining(value) }
        .sheet(isPresented: $showingCredits) { SoundCreditsView() }
        .fullScreenCover(isPresented: $showingLookAround) {
            if let scene = lookAroundScene {
                ZStack(alignment: .topTrailing) {
                    LookAroundPreviewWrapper(scene: scene)
                        .ignoresSafeArea()
                    Button("Done") { showingLookAround = false }
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .padding()
                }
            }
        }
        .onChange(of: vm.selectedBuilding) { _, building in
            lookAroundScene = nil
            guard let building,
                  let lat = building.latitude,
                  let lon = building.longitude else { return }
            Task {
                let req = MKLookAroundSceneRequest(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                lookAroundScene = try? await req.scene
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Close")

                Spacer()

                Text(cityName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 12)

            HStack(spacing: 16) {
                // AR / Object picker
                Picker("Mode", selection: $mode) {
                    Text("Object").tag(CityExploreMode.object)
                    Text("AR").tag(CityExploreMode.ar)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                // Weather toggle
                Button {
                    isRaining.toggle()
                } label: {
                    Image(systemName: isRaining ? "cloud.rain.fill" : "sun.max.fill")
                        .font(.title3)
                        .foregroundStyle(isRaining ? .blue : .yellow)
                }
                .buttonStyle(.plain)

                // Credits
                Button {
                    showingCredits = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial.opacity(0.85))
    }

    // MARK: - Building card

    private func buildingCard(_ building: Building) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if visitedIDs.contains(building.id) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color.adventureOrange)
                                .font(.caption)
                        }
                        Text(building.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    Text([building.hasKnownYear ? String(building.yearBuilt) : nil, building.knownStyle]
                            .compactMap { $0 }
                            .joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    if vm.loadedScans.contains(building.id) {
                        Label("User Scan", systemImage: "camera.viewfinder")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.adventureOrange)
                            .padding(.top, 2)
                    }
                }
                Spacer()
                Button { vm.selectedBuilding = nil } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(4)
                }
            }

            // Look Around — only shown when Apple has street imagery for this location
            if lookAroundScene != nil {
                Button {
                    showingLookAround = true
                } label: {
                    Label("Walk the Street", systemImage: "figure.walk")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.adventureOrange, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }
}

#endif

// MARK: - Look Around wrapper

/// Wraps MKLookAroundViewController for SwiftUI presentation.
struct LookAroundPreviewWrapper: UIViewControllerRepresentable {
    let scene: MKLookAroundScene

    func makeUIViewController(context: Context) -> MKLookAroundViewController {
        let vc = MKLookAroundViewController(scene: scene)
        vc.showsRoadLabels = true
        return vc
    }

    func updateUIViewController(_ uiViewController: MKLookAroundViewController, context: Context) {
        uiViewController.scene = scene
    }
}

#if os(iOS)
// MARK: - Object Mode (SceneKit)

/// Pure 3D viewer with black background — no camera, no AR.
/// SCNView.allowsCameraControl gives free orbit/zoom/pan for free.
/// Tapping on the model finds the nearest landmark via inverse coordinate math.
///
/// The USDZ is loaded on a background thread so the UI stays responsive
/// while the large file is parsed (can take several seconds for 100+ MB files).
struct CityObjectView: UIViewRepresentable {
    let usdzURL: URL
    let buildings: [Building]
    let cityName: String
    let visitedIDs: Set<String>
    var onBuildingSelected: (Building) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(buildings: buildings, cityName: cityName, onSelected: onBuildingSelected)
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .black
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tap)
        context.coordinator.scnView = scnView

        // Show a spinner while the scene loads
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        scnView.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: scnView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: scnView.centerYAnchor),
        ])
        context.coordinator.spinner = spinner

        // Load the scene off the main thread — 100+ MB USDZ parses slowly
        let url = usdzURL
        DispatchQueue.global(qos: .userInitiated).async {
            let scene = try? SCNScene(url: url)
            DispatchQueue.main.async {
                spinner.stopAnimating()
                spinner.removeFromSuperview()
                guard let scene else { return }
                scnView.scene = scene

                let allNodes = scene.rootNode.childNodes
                guard !allNodes.isEmpty else { return }

                var minVec = SCNVector3(Float.infinity, Float.infinity, Float.infinity)
                var maxVec = SCNVector3(-Float.infinity, -Float.infinity, -Float.infinity)
                for node in allNodes {
                    let (lo, hi) = node.boundingBox
                    minVec.x = min(minVec.x, lo.x + Float(node.position.x))
                    minVec.y = min(minVec.y, lo.y + Float(node.position.y))
                    minVec.z = min(minVec.z, lo.z + Float(node.position.z))
                    maxVec.x = max(maxVec.x, hi.x + Float(node.position.x))
                    maxVec.y = max(maxVec.y, hi.y + Float(node.position.y))
                    maxVec.z = max(maxVec.z, hi.z + Float(node.position.z))
                }
                let center = SCNVector3(
                    (minVec.x + maxVec.x) / 2,
                    (minVec.y + maxVec.y) / 2,
                    (minVec.z + maxVec.z) / 2
                )
                let span = max(maxVec.x - minVec.x, maxVec.z - minVec.z)

                let camera = SCNCamera()
                camera.zFar = Double(span) * 10
                let cameraNode = SCNNode()
                cameraNode.camera = camera
                cameraNode.position = SCNVector3(center.x, center.y + span * 0.7, center.z + span * 0.9)
                cameraNode.look(at: center)
                scene.rootNode.addChildNode(cameraNode)
                scnView.pointOfView = cameraNode

                context.coordinator.setupDayNight(scene: scene)
            }
        }

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    // MARK: Coordinator
    class Coordinator: NSObject {
        let buildings: [Building]
        let cityName: String
        let onSelected: (Building) -> Void
        weak var scnView: SCNView?
        weak var spinner: UIActivityIndicatorView?

        // Day/night cycle
        private var sunOrbitNode: SCNNode?
        private var ambientNode:  SCNNode?
        private var cycleTimer:   Timer?
        private var cycleTime:    Double = 0.5   // 0 = midnight, 0.5 = noon

        init(buildings: [Building], cityName: String, onSelected: @escaping (Building) -> Void) {
            self.buildings = buildings
            self.cityName = cityName
            self.onSelected = onSelected
        }

        deinit {
            cycleTimer?.invalidate()
            CityAudioManager.shared.stopAll()
        }

        func setupDayNight(scene: SCNScene) {
            // Ambient fill — keeps scene visible at night
            let al = SCNLight()
            al.type = .ambient
            al.intensity = 60
            al.color = UIColor(white: 1, alpha: 1)
            let an = SCNNode()
            an.light = al
            scene.rootNode.addChildNode(an)
            ambientNode = an

            // Directional sun light on an orbit pivot
            let sl = SCNLight()
            sl.type = .directional
            sl.castsShadow = false
            sl.intensity = 900
            let sn = SCNNode()
            sn.light = sl
            sn.position = SCNVector3(0, 1, 0)
            sn.look(at: SCNVector3(0, 0, 0))
            let orbit = SCNNode()
            orbit.addChildNode(sn)
            scene.rootNode.addChildNode(orbit)
            sunOrbitNode = orbit

            applyDayNight(scene: scene)
            CityAudioManager.shared.startAll()

            // 120-second full day cycle
            cycleTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self, weak scene] _ in
                guard let self, let scene else { return }
                self.cycleTime += (1.0 / 30.0) / 120.0
                if self.cycleTime >= 1.0 { self.cycleTime -= 1.0 }
                self.applyDayNight(scene: scene)
                CityAudioManager.shared.updateForTime(cycleTime: self.cycleTime)
            }
        }

        private func applyDayNight(scene: SCNScene) {
            // elevation: -1 at midnight, 0 at horizon, 1 at solar noon
            let angle = (cycleTime - 0.25) * 2 * .pi
            let elevation = sin(angle)   // -1 … 1
            let dayFactor = max(0.0, elevation)

            // Rotate orbit so light enters from the correct angle
            sunOrbitNode?.eulerAngles = SCNVector3(Float(-elevation * .pi / 2),
                                                    Float(cycleTime * 2 * .pi), 0)

            if let light = sunOrbitNode?.childNodes.first?.light {
                light.intensity  = CGFloat(dayFactor * 900)
                let warmth       = Float(1.0 - min(dayFactor * 2.5, 1.0))
                light.color      = UIColor(red: 1.0,
                                           green: CGFloat(0.90 + Double(warmth) * 0.10),
                                           blue:  CGFloat(0.60 + dayFactor * 0.40),
                                           alpha: 1.0)
            }
            ambientNode?.light?.intensity = 40 + CGFloat(dayFactor * 120)

            // Sky colour: night → dawn/dusk → day
            let t = CGFloat((elevation + 1) / 2)   // 0 at midnight, 1 at noon
            let sky: UIColor
            if t < 0.25 {
                sky = lerp(UIColor(red: 0.03, green: 0.03, blue: 0.12, alpha: 1),
                           UIColor(red: 0.95, green: 0.45, blue: 0.20, alpha: 1), t: t / 0.25)
            } else if t < 0.55 {
                sky = lerp(UIColor(red: 0.95, green: 0.45, blue: 0.20, alpha: 1),
                           UIColor(red: 0.37, green: 0.62, blue: 0.98, alpha: 1), t: (t - 0.25) / 0.30)
            } else {
                sky = UIColor(red: 0.37, green: 0.62, blue: 0.98, alpha: 1)
            }
            scene.background.contents = sky
        }

        private func lerp(_ a: UIColor, _ b: UIColor, t: CGFloat) -> UIColor {
            var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0
            var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0
            a.getRed(&ar, green: &ag, blue: &ab, alpha: nil)
            b.getRed(&br, green: &bg, blue: &bb, alpha: nil)
            return UIColor(red:   ar + (br - ar) * t,
                           green: ag + (bg - ag) * t,
                           blue:  ab + (bb - ab) * t,
                           alpha: 1)
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scnView,
                  let config = CitySceneConfig.config(for: cityName) else { return }

            let point = recognizer.location(in: scnView)
            // Hit-test against all scene geometry
            let hits = scnView.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue])
            guard let hit = hits.first else { return }

            // Convert scene-space hit point back to lat/lon, then find nearest landmark
            let wx = hit.worldCoordinates.x
            let wz = hit.worldCoordinates.z
            let (tapLat, tapLon) = config.latLon(sceneX: wx, sceneZ: wz)

            var nearest: Building?
            var minDist = Double.infinity
            for building in buildings {
                guard let bLat = building.latitude, let bLon = building.longitude else { continue }
                let d = config.distanceMeters(lat1: tapLat, lon1: tapLon, lat2: bLat, lon2: bLon)
                if d < minDist { minDist = d; nearest = building }
            }

            if let nearest, minDist < 1500 {
                DispatchQueue.main.async { self.onSelected(nearest) }
            }
        }
    }
}

// MARK: - AR Mode (RealityKit)

struct CityARView: View {
    let buildings: [Building]
    let visitedIDs: Set<String>
    let cityName: String
    @ObservedObject var vm: CityExploreViewModel

    @State private var prevDragX: CGFloat = 0
    @State private var prevMagnification: CGFloat = 1

    var body: some View {
        ZStack(alignment: .bottom) {
            RealityView { content in
                // On iPhone, RealityView shows an empty virtual scene by default.
                // This switches it to the live camera with world tracking, which
                // plane anchors need. (Vision Pro doesn't need this line.)
                content.camera = .spatialTracking

                let anchor = AnchorEntity(
                    .plane(.horizontal, classification: .any, minimumBounds: [0.05, 0.05])
                )
                vm.anchor = anchor
                content.add(anchor)
                await vm.loadCityModel()
            }
            .simultaneousGesture(dragGesture)
            .simultaneousGesture(pinchGesture)
            .gesture(
                // SpatialTapGesture (unlike TapGesture) reports where on screen the tap landed.
                // hitTest fires a ray from that point into the scene and returns the 3D spot
                // it hit, which we need to work out which part of the city was touched.
                SpatialTapGesture()
                    .targetedToAnyEntity()
                    .onEnded { event in
                        guard let hit = event.hitTest(point: event.location, in: .local).first else { return }
                        vm.handleTap(on: hit.entity, scenePoint: hit.position)
                    }
            )

            if !vm.cityLoaded {
                statusBadge.padding(.bottom, 48).transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.4), value: vm.cityLoaded)
        .task { await vm.loadLandmarkScans() }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let delta = Float(value.translation.width - prevDragX) * 0.007
                vm.rotateCity(by: delta)
                prevDragX = value.translation.width
            }
            .onEnded { _ in prevDragX = 0 }
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let factor = Float(value.magnification / prevMagnification)
                vm.scaleCity(by: factor)
                prevMagnification = value.magnification
            }
            .onEnded { _ in prevMagnification = 1 }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if vm.modelMissing {
            Label("No 3D model for \(cityName) yet", systemImage: "cube.transparent")
                .font(.subheadline.bold()).foregroundStyle(.white)
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(.ultraThinMaterial, in: Capsule())
        } else if vm.isLoading {
            HStack(spacing: 10) {
                ProgressView().tint(.white).scaleEffect(0.85)
                Text("Loading…").font(.subheadline).foregroundStyle(.white)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
        } else {
            Label("Point at a flat surface", systemImage: "arrow.down.to.line")
                .font(.subheadline.bold()).foregroundStyle(.white)
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

// MARK: - ViewModel

@MainActor
final class CityExploreViewModel: ObservableObject {
    let cityName: String
    let buildings: [Building]

    @Published var selectedBuilding: Building? = nil
    @Published var loadedScans: Set<String> = []
    @Published var isLoading = false
    @Published var cityLoaded = false
    @Published var modelMissing = false

    var anchor: AnchorEntity?
    private var cityEntity: Entity?
    private var baseScale: Float = 1
    private var currentYRotation: Float = 0
    private var currentScale: Float = 1

    init(cityName: String, buildings: [Building]) {
        self.cityName = cityName
        self.buildings = buildings
        BuildingIdentityComponent.registerComponent()
    }

    func loadCityModel() async {
        guard let anchor else { return }
        // Only cities that went through tools/city-generator have a model.
        // Say so instead of leaving "Point at a flat surface" up forever.
        guard let usdzURL = Bundle.main.url(forResource: cityName.lowercased(), withExtension: "usdz") else {
            modelMissing = true
            return
        }

        isLoading = true
        do {
            let entity = try await Entity(contentsOf: usdzURL)
            let bounds = entity.visualBounds(relativeTo: nil)
            let longest = max(bounds.extents.x, bounds.extents.z)
            if longest > 0 { baseScale = 0.3 / longest }
            currentScale = baseScale
            entity.scale = SIMD3(repeating: baseScale)

            // RealityKit only delivers taps to entities with a collision shape and an
            // InputTargetComponent. Exact shapes for thousands of buildings would be far
            // too slow, so the whole city gets one thin invisible slab at ground level.
            // A tap on the slab is turned back into lat/lon in handleTap.
            let localBounds = entity.visualBounds(relativeTo: entity)
            let slab = ShapeResource
                .generateBox(width: localBounds.extents.x, height: 1, depth: localBounds.extents.z)
                .offsetBy(translation: [localBounds.center.x, localBounds.min.y, localBounds.center.z])
            entity.components.set(CollisionComponent(shapes: [slab]))
            entity.components.set(InputTargetComponent())
            entity.position.y = 0.005
            anchor.addChild(entity)
            cityEntity = entity
            cityLoaded = true
        } catch {
            print("[CityExplore] Failed to load city model: \(error)")
        }
        isLoading = false
    }

    func loadLandmarkScans() async {
        let deadline = Date.now.addingTimeInterval(15)
        while cityEntity == nil, Date.now < deadline {
            try? await Task.sleep(for: .milliseconds(300))
        }
        guard let parent = cityEntity,
              let config = CitySceneConfig.config(for: cityName) else { return }

        for building in buildings {
            guard let lat = building.latitude, let lon = building.longitude else { continue }
            guard let record = await BuildingScanService.shared.fetchLatestScan(buildingID: building.id) else { continue }
            do {
                let scanURL = try await BuildingScanService.shared.localModelURL(for: record)
                let scan = try await Entity(contentsOf: scanURL)
                let scanBounds = scan.visualBounds(relativeTo: nil)
                let scanHeight = scanBounds.extents.y
                if scanHeight > 0 {
                    scan.scale = SIMD3(repeating: Float(building.height) / scanHeight)
                }
                scan.position = config.scenePosition(lat: lat, lon: lon)
                scan.components.set(BuildingIdentityComponent(buildingID: building.id))
                // Scans are small, so they can have exact collision shapes.
                // They stick up above the ground slab, so a tap hits them first.
                scan.generateCollisionShapes(recursive: true)
                scan.components.set(InputTargetComponent())
                parent.addChild(scan)
                loadedScans.insert(building.id)
            } catch {
                print("[CityExplore] Scan load failed for \(building.name): \(error)")
            }
        }
    }

    /// Picks the building for a tap in AR mode.
    func handleTap(on entity: Entity, scenePoint: SIMD3<Float>) {
        // A user scan was hit. The tap may land on one of its child meshes,
        // so walk up the parents until we find the building ID.
        var current: Entity? = entity
        while let candidate = current {
            if let identity = candidate.components[BuildingIdentityComponent.self] {
                selectedBuilding = buildings.first { $0.id == identity.buildingID }
                return
            }
            current = candidate.parent
        }

        // Otherwise the city slab was hit. Convert the tap into the model's own space
        // (metres, same as tools/city-generator), then into lat/lon, then pick the
        // nearest landmark, using the same 1.5 km cutoff as Object mode.
        guard let cityEntity,
              let config = CitySceneConfig.config(for: cityName) else { return }
        let localPoint = cityEntity.convert(position: scenePoint, from: nil)
        let (tapLat, tapLon) = config.latLon(sceneX: localPoint.x, sceneZ: localPoint.z)

        var nearest: Building?
        var minDistance = Double.infinity
        for building in buildings {
            guard let lat = building.latitude, let lon = building.longitude else { continue }
            let distance = config.distanceMeters(lat1: tapLat, lon1: tapLon, lat2: lat, lon2: lon)
            if distance < minDistance {
                minDistance = distance
                nearest = building
            }
        }
        if let nearest, minDistance < 1500 {
            selectedBuilding = nearest
        }
    }

    func rotateCity(by delta: Float) {
        currentYRotation += delta
        cityEntity?.transform.rotation = simd_quatf(angle: currentYRotation, axis: [0, 1, 0])
    }

    func scaleCity(by factor: Float) {
        currentScale = (currentScale * factor).clamped(to: (baseScale * 0.4)...(baseScale * 6))
        cityEntity?.scale = SIMD3(repeating: currentScale)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
#endif
