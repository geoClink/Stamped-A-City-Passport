//
//  StepIntoPastView.swift
//  Stamped! A City Passport
//
//  Step into the Past on iPhone, iPad and Mac (Vision Pro has PastImmersiveView): an old
//  film of the city from the Prelinger Archives (public-domain films only). Where there's
//  no film, the landmark's old photos fade one into the next while its story is read aloud
//  over the city's street sounds.
//

import SwiftUI
import AVKit

#if !os(visionOS)
struct StepIntoPastView: View {
    let building: Building
    let cityName: String

    @Environment(\.dismiss) private var dismiss
    private let storyPlayer = AudioStoryPlayer.shared

    private enum Content {
        case loading
        case film(OldFilm, AVPlayer)
        case photos([HistoricImage])
        case nothing
    }
    @State private var content: Content = .loading
    @State private var photoIndex = 0
    @State private var citySound: CitySound?
    @State private var soundLoop = CitySoundLoop()

    var body: some View {
        VStack(spacing: DS.Space.m) {
            HStack {
                Text(building.name)
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Label("Exit", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
            }
            screen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            credits
        }
        .padding(DS.Space.page)
        .foregroundStyle(.white)
        .background(Color.black.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 520)
        #endif
        .task(id: building.id) { await load() }
        .onDisappear {
            if case .film(_, let player) = content { player.pause() }
            storyPlayer.stop()
            soundLoop.stop()
        }
    }

    @ViewBuilder private var screen: some View {
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
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder private var credits: some View {
        VStack(spacing: DS.Space.xs) {
            switch content {
            case .film(let film, _):
                Text(verbatim: film.title).font(.subheadline.bold())
                Text("Film: Prelinger Archives, Internet Archive · Public domain")
                    .font(.caption)
            case .photos(let images):
                let image = images[photoIndex % images.count]
                if let caption = image.caption {
                    Text(verbatim: caption).font(.subheadline).lineLimit(3)
                }
                Text(verbatim: image.credit).font(.caption)
            default:
                EmptyView()
            }
            if let citySound {
                Text("Sound: \(citySound.name) by \(citySound.author), CC0, Freesound")
                    .font(.caption2)
                    .lineLimit(2)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private func load() async {
        if let film = await OldFilmService.shared.film(for: cityName) {
            let player = AVPlayer(url: film.videoURL)
            content = .film(film, player)
            player.play()
            return
        }
        let photos = await OldPhotoSources.photos(for: building, cityName: cityName)
        content = photos.isEmpty ? .nothing : .photos(photos)
        guard !photos.isEmpty else { return }
        // The photos are silent, so the story is read over them, with the city's street sounds
        storyPlayer.play(building)
        if let sound = await CitySoundService.shared.sound(for: cityName),
           let file = await CitySoundService.shared.localFile(for: sound), !Task.isCancelled {
            soundLoop.play(file)
            citySound = sound
        }
    }
}
#endif
