import SwiftUI
import RealityKit

// Displays a USDZ model in an AR-ready RealityView.
// Works on iOS 18+ and visionOS — the same code runs on both platforms.
struct BuildingModelViewer: View {
    let modelURL: URL
    let buildingName: String
    @Environment(\.dismiss) private var dismiss

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

                    // Allow tap-to-rotate with input targeting
                    entity.components.set(InputTargetComponent())
                    entity.generateCollisionShapes(recursive: true)

                    let anchor = AnchorEntity(world: .zero)
                    anchor.addChild(entity)
                    content.add(anchor)
                } catch {
                    print("BuildingModelViewer: failed to load model — \(error)")
                }
            }
            .ignoresSafeArea()
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
