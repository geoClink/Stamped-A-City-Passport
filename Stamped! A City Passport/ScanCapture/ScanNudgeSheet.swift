//
//  ScanNudgeSheet.swift
//  Stamped! A City Passport
//
//  Shown after a user stamps a building that has no community 3D scan yet.
//

#if os(iOS)
import SwiftUI
import RealityKit

struct ScanNudgeSheet: View {
    let building: Building
    let cityName: String
    let onScanNow: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Fits the short sheet at normal text sizes; scrolls when large text makes it taller
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
        // A fixed 420 pt sheet would cut off large text, so accessibility sizes get the full height
        .presentationDetents(dynamicTypeSize.isAccessibilitySize
                             ? Set([PresentationDetent.large])
                             : Set([PresentationDetent.height(420)]))
        .presentationDragIndicator(.hidden)
    }

    private var content: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .accessibilityHidden(true)

            Image(systemName: "camera.viewfinder")
                .font(.system(size: 52))
                .foregroundStyle(Color.adventureOrange)
                .padding(.bottom, 16)
                .accessibilityHidden(true)

            Text("Help Build \(cityName) in 3D")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("\(building.name) doesn't have a community 3D scan yet. If you're nearby, take 20–40 photos and we'll build the model — it'll appear for every Stamped user who explores this city.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.top, 8)

            VStack(spacing: 12) {
                Button {
                    dismiss()
                    onScanNow()
                } label: {
                    Label("Scan This Building", systemImage: "camera.viewfinder")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.adventureOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    dismiss()
                } label: {
                    Text("Maybe Later")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 16)
        }
    }
}
#endif
