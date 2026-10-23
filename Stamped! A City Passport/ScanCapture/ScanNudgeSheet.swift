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

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 24)

            Image(systemName: "camera.viewfinder")
                .font(.system(size: 52))
                .foregroundStyle(Color.adventureOrange)
                .padding(.bottom, 16)

            Text("Help Build \(cityName) in 3D")
                .font(.title3.bold())
                .multilineTextAlignment(.center)

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
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.hidden)
    }
}
#endif
