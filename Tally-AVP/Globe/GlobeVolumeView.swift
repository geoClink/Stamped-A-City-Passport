//
//  GlobeVolumeView.swift
//  Tally-AVP
//
//  A volumetric window with a slowly spinning Earth and a pin for every city.
//  Orange glowing pins = cities with at least one stamp; grey dots = the rest.
//  The white pulsing pin is the city selected in the main window.
//  Tap a pin to see its progress (the globe turns that city toward you);
//  drag sideways to spin the globe, up or down to tilt it.
//

import SwiftUI
import RealityKit

struct GlobeVolumeView: View {

    private let store = VisionStore.shared

    /// Shared with CityListVisionView. Writing a city name here asks the main
    /// window to select that city. We chose a shared @AppStorage value over
    /// openWindow because the main window's WindowGroup would open a second
    /// copy of itself; this way the window that's already open just switches.
    @AppStorage("globeRequestedCity") private var requestedCity = ""

    /// Shared with CityListVisionView, which writes the city selected in the
    /// main window here. That city's pin is drawn white and pulses.
    @AppStorage("globeHighlightedCity") private var highlightedCity = ""

    /// The city whose card is showing (nil = no card).
    @State private var selectedCityName: String?

    /// The entity tree is  tilt → spinner → (earth, pins → one pin per city).
    /// `tilt` leans the globe toward or away from you (around the x axis), and
    /// `spinner` turns it like a real globe (around the y axis). Because the
    /// spinner is a child of the tilt, spinning always happens around the
    /// globe's own (tilted) north–south axis.
    @State private var tilt = Entity()
    @State private var spinner = Entity()
    /// Holds only the pins, so they can be thrown away and rebuilt without
    /// touching the Earth.
    @State private var pins = Entity()
    /// The see-through ball around the highlighted pin; the update loop pulses it.
    @State private var highlightHalo: Entity?

    @State private var spinAngle: Float = 0          // radians around the y axis
    @State private var tiltAngle: Float = .pi / 9    // radians around the x axis (20°)
    @State private var dragStartAngle: Float?        // non-nil while dragging
    @State private var dragStartTilt: Float?
    @State private var updateSubscription: EventSubscription?

    private let globeRadius: Float = 0.2             // metres (the volume is 0.6 m wide)
    private let autoSpinSpeed: Float = 0.12          // radians per second (~52 s per turn)
    private let maxTilt: Float = .pi / 4             // 45°, so the globe can't flip over

    var body: some View {
        RealityView { content, attachments in
            // Start with the top leaning toward the viewer a little. Most of
            // the cities are in the northern hemisphere, so this shows them
            // better than a straight-on view. Dragging up or down changes it.
            tilt.orientation = simd_quatf(angle: tiltAngle, axis: [1, 0, 0])
            tilt.addChild(spinner)
            content.add(tilt)

            spinner.addChild(await makeEarth())
            spinner.addChild(pins)
            rebuildPins()

            // The info card floats above the globe and doesn't spin with it.
            if let card = attachments.entity(for: "cityCard") {
                card.position = [0, globeRadius + 0.07, 0.08]
                card.components.set(BillboardComponent())   // always faces the viewer
                content.add(card)
            }

            // Runs every frame: pulse the highlighted pin, and turn the globe a
            // little unless the user is dragging it or reading a card.
            var elapsed: Float = 0
            updateSubscription = content.subscribe(to: SceneEvents.Update.self) { event in
                elapsed += Float(event.deltaTime)
                // sin() swings between -1 and 1, so the halo's scale swings
                // between 0.7 and 1.3, about once a second (2π / 6 ≈ 1 s).
                let pulse = 1 + 0.3 * sin(elapsed * 6)
                highlightHalo?.scale = SIMD3(repeating: pulse)

                guard dragStartAngle == nil, selectedCityName == nil else { return }
                spinAngle += autoSpinSpeed * Float(event.deltaTime)
                spinner.orientation = simd_quatf(angle: spinAngle, axis: [0, 1, 0])
            }
        } attachments: {
            Attachment(id: "cityCard") {
                if let name = selectedCityName {
                    GlobeCityCard(
                        cityName: name,
                        stampedCount: store.visitedCount(for: name),
                        total: store.buildings(for: name).count,
                        onShow: {
                            requestedCity = name
                            selectedCityName = nil
                        },
                        onClose: { selectedCityName = nil }
                    )
                }
            }
        }
        .gesture(tapGesture)
        .gesture(dragGesture)
        // Pins are built once in the make closure above, so rebuild them when
        // a stamp syncs in from iPhone or the main window picks another city.
        .onChange(of: store.visitedIDs) { rebuildPins() }
        .onChange(of: highlightedCity) { rebuildPins() }
    }

    // MARK: - Gestures

    /// Tapping a pin opens its card and turns that city toward you; tapping
    /// the Earth itself closes the card.
    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                let name = value.entity.name
                guard let city = GlobeMath.cities(from: store).first(where: { $0.name == name }) else {
                    selectedCityName = nil
                    return
                }
                selectedCityName = name   // also pauses the auto-spin
                turnToFace(city)
            }
    }

    /// Sideways drag spins the globe around its vertical axis; up/down drag
    /// tilts it toward or away from you.
    private var dragGesture: some Gesture {
        DragGesture()
            .targetedToAnyEntity()
            .onChanged { value in
                if dragStartAngle == nil {
                    dragStartAngle = spinAngle
                    dragStartTilt = tiltAngle
                }
                // 0.005 radians per point: a ~600 pt swipe is about one half-turn.
                spinAngle = (dragStartAngle ?? 0) + Float(value.translation.width) * 0.005
                spinner.orientation = simd_quatf(angle: spinAngle, axis: [0, 1, 0])

                // Dragging down (positive height) rolls the front of the globe
                // down, which is a positive turn around +x. Clamp so the globe
                // never tips more than 45° either way.
                let newTilt = (dragStartTilt ?? 0) + Float(value.translation.height) * 0.005
                tiltAngle = min(max(newTilt, -maxTilt), maxTilt)
                tilt.orientation = simd_quatf(angle: tiltAngle, axis: [1, 0, 0])
            }
            .onEnded { _ in
                dragStartAngle = nil
                dragStartTilt = nil
            }
    }

    /// Animates the spinner so the city's longitude faces the viewer (+z).
    ///
    /// GlobeMath puts longitude L at angle L around the y axis, measured from
    /// +z. Spinning the globe by -L brings it back to angle 0, straight ahead.
    private func turnToFace(_ city: GlobeCity) {
        let target = -Float(city.longitude * .pi / 180)

        // spinAngle keeps growing as the globe auto-spins (it can be many full
        // turns). remainder(_, 2π) gives the same turn as a value between -π
        // and π, i.e. the shortest way round: never more than half a turn.
        let shortestTurn = remainder(target - spinAngle, 2 * .pi)
        spinAngle += shortestTurn

        var transform = spinner.transform
        transform.rotation = simd_quatf(angle: spinAngle, axis: [0, 1, 0])
        spinner.move(to: transform, relativeTo: spinner.parent, duration: 0.8, timingFunction: .easeInOut)
    }

    // MARK: - Entities

    /// Throws away every pin and builds them again from the latest stamps and
    /// highlighted city. Rebuilding ~140 tiny spheres is quick, and simpler
    /// than working out which pins changed.
    private func rebuildPins() {
        pins.children.removeAll()
        highlightHalo = nil
        for city in GlobeMath.cities(from: store) {
            pins.addChild(makePin(for: city, isHighlighted: city.name == highlightedCity))
        }
    }

    /// A textured sphere. GlobeEarth.png is a stylised map drawn for this app.
    private func makeEarth() async -> ModelEntity {
        var material = SimpleMaterial(color: .systemBlue, roughness: 0.8, isMetallic: false)
        if let url = Bundle.main.url(forResource: "GlobeEarth", withExtension: "png"),
           let texture = try? await TextureResource(contentsOf: url) {
            material.color = .init(tint: .white, texture: .init(texture))
        }

        let earth = ModelEntity(mesh: .generateSphere(radius: globeRadius), materials: [material])
        earth.name = "earth"

        // generateSphere wraps the left edge of the image (longitude -180°) to
        // a different spot than our position helper assumes, so turn the
        // sphere by this much to line the map up with the pins.
        earth.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])

        // Needed so drags and taps on the Earth reach our gestures.
        earth.components.set(InputTargetComponent())
        earth.components.set(CollisionComponent(shapes: [.generateSphere(radius: globeRadius)]))
        return earth
    }

    /// A small sphere sitting just above the surface at the city's location.
    /// The highlighted city gets a bigger white pin with a pulsing white halo.
    private func makePin(for city: GlobeCity, isHighlighted: Bool) -> ModelEntity {
        let pinRadius: Float
        let material: any RealityKit.Material
        if isHighlighted {
            pinRadius = 0.008
            material = UnlitMaterial(color: .white)
        } else if city.isStamped {
            pinRadius = 0.006
            material = UnlitMaterial(color: .orange)   // unlit = ignores shading, so it reads as glowing
        } else {
            pinRadius = 0.0028
            material = SimpleMaterial(color: .lightGray, roughness: 0.6, isMetallic: false)
        }

        let pin = ModelEntity(mesh: .generateSphere(radius: pinRadius), materials: [material])
        pin.name = city.name   // the tap gesture reads this to know which city was hit
        pin.position = GlobeMath.position(
            latitude: city.latitude,
            longitude: city.longitude,
            radius: globeRadius + pinRadius * 0.5
        )

        if isHighlighted || city.isStamped {
            // A larger see-through sphere around the pin makes a soft halo.
            var haloMaterial = UnlitMaterial(color: isHighlighted ? .white : .orange)
            haloMaterial.blending = .transparent(opacity: isHighlighted ? 0.35 : 0.3)
            let halo = ModelEntity(mesh: .generateSphere(radius: pinRadius * 1.8), materials: [haloMaterial])
            pin.addChild(halo)
            if isHighlighted { highlightHalo = halo }
        }

        // The tap target is bigger than the dot itself so tiny pins are easy to hit.
        pin.components.set(InputTargetComponent())
        pin.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.012)]))
        return pin
    }
}

// MARK: - City card

private struct GlobeCityCard: View {
    let cityName: String
    let stampedCount: Int
    let total: Int
    let onShow: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(cityName).font(.title2.bold())
                Spacer()
                Button("Close", systemImage: "xmark", action: onClose)
                    .labelStyle(.iconOnly)
            }
            Text("\(stampedCount) / \(total) stamped")
                .font(.headline)
                .foregroundStyle(stampedCount > 0 ? .orange : .secondary)
            Button("Show in Main Window", systemImage: "map", action: onShow)
        }
        .padding(20)
        .frame(width: 320)
        .glassBackgroundEffect()
    }
}
