#if os(iOS)
import SwiftUI
import RealityKit
import PhotosUI
import Combine

// MARK: - View

struct ScanBuildingView: View {
    let building: Building
    let cityName: String
    @StateObject private var vm: ScanViewModel
    @Environment(\.dismiss) private var dismiss

    init(building: Building, cityName: String) {
        self.building = building
        self.cityName = cityName
        _vm = StateObject(wrappedValue: ScanViewModel(building: building, cityName: cityName))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch vm.phase {
                case .intro:      introView
                case .selected:   selectedView
                case .processing: processingView
                case .uploading:  uploadingView
                case .done:       doneView
                case .failed(let msg): failedView(msg)
                }
            }
            .animation(.easeInOut, value: vm.phase == .intro)
            .navigationTitle("Scan \(building.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if vm.phase == .intro || vm.phase == .selected {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }

    // MARK: - Intro

    private var introView: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 20)

                Image(systemName: "camera.aperture")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.adventureOrange)

                VStack(spacing: 10) {
                    Text("Create a 3D Model")
                        .font(.title2.bold())
                    Text("Take 20–40 photos of \(building.name) from all angles, then select them here. Your model will be shared with all Stamped users.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Tips card
                VStack(alignment: .leading, spacing: 6) {
                    Text("HOW TO GET A GOOD SCAN")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Color.adventureOrange)
                        .tracking(2)
                        .padding(.bottom, 4)

                    tipRow(icon: "1.circle.fill",         text: "Walk slowly around the building — one full circle per level")
                    tipRow(icon: "2.circle.fill",         text: "Do 2–3 passes: shoot low, then chest height, then tilted up")
                    tipRow(icon: "3.circle.fill",         text: "Each photo should overlap the last by about half")
                    tipRow(icon: "sun.max.fill",          text: "Overcast days are ideal — harsh sun creates bad shadows")
                    tipRow(icon: "exclamationmark.triangle.fill", text: "Avoid glass walls — reflections confuse the model")
                    tipRow(icon: "photo.stack.fill",      text: "30+ photos gives the best result")
                }
                .padding(20)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal, 20)

                PhotosPicker(
                    selection: $vm.selectedItems,
                    maxSelectionCount: 40,
                    matching: .images
                ) {
                    Label("Select Photos", systemImage: "photo.stack.fill")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: 300)
                        .padding(.vertical, 16)
                        .background(Color.adventureOrange)
                        .clipShape(Capsule())
                }
                .onChange(of: vm.selectedItems) { _, items in
                    vm.onPhotosSelected(items)
                }

                Spacer(minLength: 40)
            }
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.adventureOrange)
                .frame(width: 26)
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Selected

    private var selectedView: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.adventureOrange)

            VStack(spacing: 8) {
                Text("\(vm.selectedCount) Photos Selected")
                    .font(.title2.bold())
                Text(vm.selectedCount < 20
                     ? "Try to select at least 20 for best results."
                     : "Ready to build your 3D model.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                Button("Build 3D Model") { vm.buildModel() }
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: 300)
                    .padding(.vertical, 16)
                    .background(Color.adventureOrange)
                    .clipShape(Capsule())

                PhotosPicker(
                    selection: $vm.selectedItems,
                    maxSelectionCount: 40,
                    matching: .images
                ) {
                    Text("Change Photos")
                        .font(.subheadline)
                        .foregroundStyle(Color.adventureOrange)
                }
                .onChange(of: vm.selectedItems) { _, items in
                    vm.onPhotosSelected(items)
                }
            }

            Spacer()
        }
    }

    // MARK: - Processing

    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView(value: vm.processingProgress)
                .tint(Color.adventureOrange)
                .scaleEffect(x: 1, y: 2)
                .padding(.horizontal, 48)

            VStack(spacing: 6) {
                Text("Building 3D Model")
                    .font(.title3.bold())
                Text("\(Int(vm.processingProgress * 100))% complete")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Keep the app open — this may take several minutes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    // MARK: - Uploading

    private var uploadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .tint(Color.adventureOrange)
                .scaleEffect(1.4)
            Text("Uploading to Stamped…")
                .font(.title3.bold())
            Text("Your model will be available to all users once uploaded.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Done

    private var doneView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.adventureOrange)

            VStack(spacing: 8) {
                Text("Scan Uploaded!")
                    .font(.title2.bold())
                Text("\(building.name) is now available in 3D for every Stamped user.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button("Done") { dismiss() }
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: 300)
                .padding(.vertical, 16)
                .background(Color.adventureOrange)
                .clipShape(Capsule())

            Spacer()
        }
    }

    // MARK: - Failed

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            Text("Processing Failed")
                .font(.title2.bold())

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                Button("Try Again") { vm.phase = .intro }
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: 300)
                    .padding(.vertical, 16)
                    .background(Color.adventureOrange)
                    .clipShape(Capsule())

                Button("Cancel") { dismiss() }
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - ViewModel

@MainActor
class ScanViewModel: ObservableObject {
    let building: Building
    let cityName: String

    @Published var selectedItems: [PhotosPickerItem] = []
    @Published var selectedCount: Int = 0
    @Published var phase: Phase = .intro
    @Published var processingProgress: Float = 0

    enum Phase: Equatable {
        case intro, selected, processing, uploading, done, failed(String)
    }

    private let imagesDir: URL
    private let outputURL: URL

    init(building: Building, cityName: String) {
        self.building = building
        self.cityName = cityName
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("stamped_scan_\(building.id)")
        self.imagesDir = base.appendingPathComponent("images")
        self.outputURL = base.appendingPathComponent("output.usdz")
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
    }

    func onPhotosSelected(_ items: [PhotosPickerItem]) {
        selectedCount = items.count
        phase = items.isEmpty ? .intro : .selected
    }

    func buildModel() {
        phase = .processing
        processingProgress = 0
        Task { await saveAndReconstruct() }
    }

    private func saveAndReconstruct() async {
        // Clear previous run
        try? FileManager.default.removeItem(at: imagesDir)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        // Write each selected photo to disk
        for (index, item) in selectedItems.enumerated() {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let dest = imagesDir.appendingPathComponent(String(format: "img_%04d.jpg", index))
            try? data.write(to: dest)
        }

        await reconstruct()
    }

    private func reconstruct() async {
        guard #available(iOS 17.0, *) else {
            phase = .failed("iOS 17 or later is required.")
            return
        }
        do {
            let config = PhotogrammetrySession.Configuration()
            let session = try PhotogrammetrySession(input: imagesDir, configuration: config)
            let request = PhotogrammetrySession.Request.modelFile(url: outputURL, detail: .reduced)
            try session.process(requests: [request])

            for try await output in session.outputs {
                switch output {
                case .requestProgress(_, let fraction):
                    processingProgress = Float(fraction)
                case .processingComplete:
                    await upload()
                case .processingCancelled:
                    phase = .failed("Processing was cancelled.")
                case .requestError(_, let error):
                    phase = .failed(error.localizedDescription)
                default:
                    break
                }
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func upload() async {
        phase = .uploading
        do {
            try await BuildingScanService.shared.upload(
                usdzURL: outputURL,
                buildingID: building.id,
                buildingName: building.name,
                cityName: cityName
            )
            phase = .done
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
#endif
