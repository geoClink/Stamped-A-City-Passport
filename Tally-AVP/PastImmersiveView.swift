//
//  PastImmersiveView.swift
//  Tally-AVP
//
//  Step into the Past: the room fades to sepia dark and a big screen in front of
//  you plays an old film of the city from the Internet Archive's Prelinger
//  Archives (public-domain films only). Where there's no film, the landmark's old
//  Library of Congress photos fade one into the next while its story is read aloud.
//

import SwiftUI
import RealityKit
import AVKit

struct PastImmersiveView: View {
    static let spaceID = "landmark-past"

    let buildingID: String

    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    private let store = VisionStore.shared
    private let storyPlayer = AudioStoryPlayer.shared

    private enum Content {
        case loading
        case film(OldFilm, AVPlayer)
        case photos([HistoricImage])
        case nothing
    }
    @State private var content: Content = .loading
    @State private var photoIndex = 0
    /// Plays the city's street sounds around the viewer
    @State private var soundHolder = Entity()
    @State private var citySound: CitySound?

    /// The landmark and its city
    private var place: (building: Building, city: String)? {
        for (city, buildings) in store.buildingsByCity {
            if let building = buildings.first(where: { $0.id == buildingID }) { return (building, city) }
        }
        return nil
    }

    var body: some View {
        RealityView { content, attachments in
            content.add(Self.makeDarkRoom())
            content.add(soundHolder)
            if let screen = attachments.entity(for: "screen") {
                screen.position = SIMD3(0, 1.5, -2.6)
                screen.scale = SIMD3(repeating: 2.2)
                content.add(screen)
            }
            if let panel = attachments.entity(for: "panel") {
                panel.position = SIMD3(0, 0.95, -1.0)
                panel.components.set(BillboardComponent())
                content.add(panel)
            }
        } attachments: {
            Attachment(id: "screen") { screen }
            Attachment(id: "panel") { panel }
        }
        .task(id: buildingID) { await load() }
        .onDisappear {
            if case .film(_, let player) = content { player.pause() }
            storyPlayer.stop()
        }
    }

    // MARK: - Screen

    @ViewBuilder private var screen: some View {
        Group {
            switch content {
            case .loading:
                ProgressView()
            case .film(_, let player):
                VideoPlayer(player: player)
            case .photos(let images):
                AsyncImage(url: images[photoIndex % images.count].largeURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .id(photoIndex)
                .transition(.opacity)
                // A new photo every 8 seconds
                .task(id: photoIndex) {
                    try? await Task.sleep(for: .seconds(8))
                    withAnimation(.easeInOut(duration: 2)) { photoIndex += 1 }
                }
            case .nothing:
                Text("No old film or photos of this landmark yet.")
                    .font(.title)
            }
        }
        .frame(width: 1280, height: 760)
        .background(.black)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Panel

    private var panel: some View {
        VStack(spacing: 10) {
            if let place {
                Text(place.building.name).font(.title2.bold())
            }
            switch content {
            case .film(let film, _):
                Text(verbatim: film.title).font(.headline)
                Text("Film: Prelinger Archives, Internet Archive · Public domain")
                    .font(.caption).foregroundStyle(.secondary)
            case .photos(let images):
                if let caption = images[photoIndex % images.count].caption {
                    Text(verbatim: caption).font(.callout)
                }
                Text(verbatim: images[photoIndex % images.count].credit)
                    .font(.caption).foregroundStyle(.secondary)
                if let citySound {
                    Text("Sound: \(citySound.name) by \(citySound.author), CC0, Freesound")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            default:
                EmptyView()
            }
            Button {
                Task { await dismissImmersiveSpace() }
            } label: {
                Label("Exit", systemImage: "xmark")
            }
        }
        .padding(24)
        .frame(maxWidth: 520)
        .glassBackgroundEffect()
    }

    // MARK: - Loading

    private func load() async {
        guard let place else {
            content = .nothing
            return
        }
        if let film = await OldFilmService.shared.film(for: place.city) {
            let player = AVPlayer(url: film.videoURL)
            content = .film(film, player)
            player.play()
            return
        }
        let photos = await OldPhotoSources.photos(for: place.building, cityName: place.city)
        if photos.isEmpty {
            content = .nothing
        } else {
            content = .photos(photos)
        }
        // The photos are silent, so the story is read over them, with the city's street sounds
        storyPlayer.play(place.building)
        await playCitySound(for: place.city)
    }

    /// A CC0 street ambience from Freesound, soft and all around, looping
    private func playCitySound(for city: String) async {
        guard let sound = await CitySoundService.shared.sound(for: city),
              let file = await CitySoundService.shared.localFile(for: sound),
              let resource = try? await AudioFileResource(contentsOf: file,
                                                          configuration: .init(shouldLoop: true))
        else { return }
        soundHolder.components.set(AmbientAudioComponent(gain: -14))
        soundHolder.playAudio(resource)
        citySound = sound
    }

    /// A dark sepia sphere around the viewer, so only the past is in view
    private static func makeDarkRoom() -> Entity {
        var material = UnlitMaterial(color: UIColor(red: 0.09, green: 0.07, blue: 0.05, alpha: 1))
        material.faceCulling = .front
        let sphere = ModelEntity(mesh: .generateSphere(radius: 30), materials: [material])
        sphere.position = SIMD3(0, 1.5, 0)
        return sphere
    }
}
