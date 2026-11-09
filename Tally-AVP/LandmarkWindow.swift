//
//  LandmarkWindow.swift
//  Tally-AVP
//
//  The landmark's page in its own window beside the map, so it never covers the
//  map and can be moved and turned like any window. The map picks the landmark
//  (LandmarkSelection); "Designed by" opens the architect's page in the same window.
//

import SwiftUI

/// The landmark open in the landmark window. The map sets it; the window shows it.
@Observable
final class LandmarkSelection {
    static let shared = LandmarkSelection()

    var building: Building?
    private(set) var cityName = ""
    /// What closing the window also stops (the tour, the story, SharePlay); set by the map
    @ObservationIgnored var onClose: () -> Void = {}

    private init() {}

    func show(_ building: Building, in cityName: String) {
        self.cityName = cityName
        self.building = building
    }

    /// The person closed the window
    func close() {
        guard building != nil else { return }
        building = nil
        onClose()
    }
}

struct LandmarkWindowView: View {
    static let windowID = "landmark"

    private let selection = LandmarkSelection.shared
    private let store = VisionStore.shared
    @ObservedObject private var storyPlayer = AudioStoryPlayer.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        NavigationStack {
            ScrollView {
                if let building = selection.building {
                    LandmarkCard(building: building,
                                 cityName: selection.cityName,
                                 isVisited: store.visitedIDs.contains(building.id),
                                 isWishlisted: store.isWishlisted(building.id),
                                 isPlaying: storyPlayer.isPlaying(building),
                                 onWishlist: { store.toggleWishlist(building.id) },
                                 onListen: { storyPlayer.toggle(building) }) {
                        selection.close()
                        dismissWindow(id: Self.windowID)
                    }
                    // A new landmark starts at the top of the page
                    .id(building.id)
                }
            }
        }
        // Reopened by visionOS with nothing picked: go to the main window instead of a blank page
        .onAppear {
            guard selection.building == nil else { return }
            openWindow(id: Tally_AVPApp.mainWindowID)
            dismissWindow(id: Self.windowID)
        }
        // Closed with the window's own close button
        .onDisappear { selection.close() }
    }
}

// MARK: - Architect

/// "Designed by …" on a landmark page. With one architect it opens their page;
/// with several ("I.M. Pei & Henry N. Cobb") it asks which one.
/// Plain text when there's no one to link to ("Traditional / Unknown").
struct VisionArchitectLink: View {
    let building: Building

    @State private var openArchitect: ArchitectName?

    var body: some View {
        let architects = ArchitectIndex.architects(of: building)
        Group {
            if architects.count == 1 {
                Button { openArchitect = architects[0] } label: { linkLabel }
            } else if architects.count > 1 {
                Menu {
                    ForEach(architects) { name in
                        Button(name.displayName) { openArchitect = name }
                    }
                } label: { linkLabel }
            } else {
                Label(building.architect, systemImage: "person.crop.square")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationDestination(item: $openArchitect) { name in
            VisionArchitectPage(architect: name)
        }
    }

    private var linkLabel: some View {
        Label {
            HStack(spacing: 6) {
                Text(building.architect)
                Image(systemName: "chevron.right").font(.caption.bold())
            }
        } icon: {
            Image(systemName: "person.crop.square")
        }
        .font(.callout)
        .accessibilityHint(Text("Shows the architect's other landmarks"))
    }
}

/// An architect's page: their photo (when Wikipedia has a free one), a short bio,
/// and every landmark of theirs in the app, across all cities.
struct VisionArchitectPage: View {
    let architect: ArchitectName

    private let store = VisionStore.shared
    @State private var summary: ArchitectSummary?
    @State private var isLoading = true

    private var landmarks: [(building: Building, city: ArchitectCity)] {
        ArchitectIndex.landmarks(by: architect)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 20) {
                    if let url = summary?.photoURL {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.secondary.opacity(0.2)
                        }
                        .frame(width: 110, height: 138)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel(Text("Photo of \(architect.displayName)"))
                    }
                    Text(architect.displayName)
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                }
                if isLoading {
                    ProgressView()
                } else if let summary {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("From Wikipedia", systemImage: "w.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(summary.extract)
                        if let articleURL = summary.articleURL {
                            Link(destination: articleURL) {
                                Label("Read on Wikipedia", systemImage: "arrow.up.right.square")
                                    .font(.callout.bold())
                            }
                        }
                        if summary.photoURL != nil {
                            Text("Photo: Wikimedia Commons")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                ForEach(landmarks, id: \.building.id) { landmark in
                    let isVisited = store.visitedIDs.contains(landmark.building.id)
                    Label {
                        VStack(alignment: .leading) {
                            Text(landmark.building.name).font(.headline)
                            Text(landmark.building.hasKnownYear
                                 ? "\(landmark.city) · \(String(landmark.building.yearBuilt))"
                                 : landmark.city)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        // The landmark's Wikipedia photo, with the stamp on its corner once visited
                        WikiBuildingPhoto(building: landmark.building, height: 72)
                            .frame(width: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(alignment: .topTrailing) {
                                if isVisited {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(.white, .orange)
                                        .padding(4)
                                }
                            }
                    }
                    .labelStyle(PhotoRowLabelStyle())
                    .accessibilityValue(isVisited ? Text("Stamped") : Text(verbatim: ""))
                }
            } header: {
                Text("Landmarks (\(landmarks.count))")
            }
        }
        .navigationTitle(architect.displayName)
        .task {
            summary = await ArchitectWikiService.shared.summary(for: architect.displayName)
            isLoading = false
        }
    }
}

/// A Label with a photo for its icon: photo and text side by side, centred on each other
private struct PhotoRowLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 16) {
            configuration.icon
            configuration.title
        }
    }
}

// MARK: - Shared iPhone screens

extension EnvironmentValues {
    /// The iPhone app's wide-layout flag (set by its city list). Vision Pro windows are wide.
    @Entry var isWideWindow = true
}
