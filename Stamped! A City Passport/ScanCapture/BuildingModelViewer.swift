import SwiftUI
import RealityKit

// Displays a USDZ model in an AR-ready RealityView.
// Works on iOS 18+ and visionOS — the same code runs on both platforms.
struct BuildingModelViewer: View {
    let modelURL: URL
    let buildingName: String
    @Environment(\.dismiss) private var dismiss

    // Accumulated Y-axis rotation driven by drag gesture
    @State private var rotationY: Float = 0
    // Tracks the previous drag translation so we can compute per-frame deltas
    @State private var prevDragWidth: CGFloat = 0

    var body: some View {
        NavigationStack {
            RealityView { content in
                do {
                    let entity = try await ModelEntity(contentsOf: modelURL)

                    // Normalise to ~1m tall so it fits the view regardless of source scale
                    let bounds = entity.visualBounds(relativeTo: nil)
                    let maxExtent = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
                    if maxExtent > 0 {
                        entity.scale = SIMD3(repeating: 1.0 / maxExtent)
                    }

                    // Centre vertically and position 1.5 m in front
                    entity.position = SIMD3(
                        x: 0,
                        y: -bounds.center.y * (1.0 / maxExtent),
                        z: -1.5
                    )

                    entity.components.set(InputTargetComponent())
                    entity.generateCollisionShapes(recursive: true)

                    let anchor = AnchorEntity(world: .zero)
                    anchor.addChild(entity)
                    content.add(anchor)
                } catch {
                    print("BuildingModelViewer: failed to load model — \(error)")
                }
            } update: { content in
                // Re-runs whenever rotationY changes — applies drag rotation to the model entity
                guard let anchor = content.entities.first,
                      let entity = anchor.children.first else { return }
                entity.orientation = simd_quatf(angle: rotationY, axis: [0, 1, 0])
            }
            .ignoresSafeArea()
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let delta = Float(value.translation.width - prevDragWidth) * 0.005
                        rotationY += delta
                        prevDragWidth = value.translation.width
                    }
                    .onEnded { _ in prevDragWidth = 0 }
            )
            .navigationTitle(buildingName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adventureOrange)
                }
            }
        }
    }
}
