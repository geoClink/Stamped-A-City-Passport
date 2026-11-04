//
//  CityModelButton.swift
//  Tally-AVP
//
//  The city map's 3D toolbar button. It changes with the model's state:
//  • on the device  → "Open 3D Model"
//  • not downloaded → "Download Detroit in 3D (≈38 MB)"
//  • downloading    → a progress bar and Cancel
//

import SwiftUI

struct CityModelButton: View {

    let cityName: String

    @Environment(\.openWindow) private var openWindow
    private let models = CityModelStore.shared

    var body: some View {
        content
            .alert("Download Failed", isPresented: showingError) {
                // No buttons listed: SwiftUI adds a localized OK.
            } message: {
                Text("Stamped! couldn't download \(cityName) in 3D. Check your internet connection and try again.")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch models.state(for: cityName) {
        case .ready:
            Button {
                openWindow(id: "city-volume", value: cityName)
            } label: {
                Label("Open 3D Model", systemImage: "cube.transparent")
            }
            .accessibilityHint("Opens a 3D model of the city in its own window")

        case .notDownloaded(let bytes):
            Button {
                models.download(cityName)
            } label: {
                Label(downloadTitle(bytes: bytes), systemImage: "arrow.down.circle")
            }

        case .downloading(let fraction):
            HStack(spacing: 12) {
                ProgressView(value: fraction)
                    .frame(width: 120)
                    .accessibilityLabel(Text("Downloading \(cityName) in 3D…"))
                Button("Cancel") {
                    models.cancelDownload(cityName)
                }
            }

        case .checking, .unavailable:
            EmptyView()
        }
    }

    /// "Download Detroit in 3D (≈38 MB)", or without the size when it isn't known yet.
    private func downloadTitle(bytes: Int?) -> LocalizedStringKey {
        guard let bytes else { return "Download \(cityName) in 3D" }
        // Formats the size for the user's language, e.g. "38 MB" or "38 Mo".
        let size = Int64(bytes).formatted(.byteCount(style: .file))
        return "Download \(cityName) in 3D (≈\(size))"
    }

    /// True while the store reports a failed download for this city.
    private var showingError: Binding<Bool> {
        Binding(
            get: { models.failedCityName == cityName },
            set: { isShowing in
                if !isShowing { models.failedCityName = nil }
            }
        )
    }
}
