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
        // The Library of Congress surveys only cover US landmarks
        let isUS = LibraryOfCongressService.cityAndState(from: place.building.address) != nil
        let images = !isUS ? [] : await LibraryOfCongressService.shared.images(
            buildingID: place.building.id, name: place.building.name,
            address: place.building.address, cityName: place.city
        ).filter { !$0.isDrawing }
        // Anywhere else, or when the survey has none: old photos from Wikimedia Commons
        let photos = images.isEmpty ? await HeritageService.shared.oldPhotos(for: place.building) : images
        if photos.isEmpty {
            content = .nothing
        } else {
            content = .photos(photos)
        }
        // The photos are silent, so the story is read over them
        storyPlayer.play(place.building)
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

// MARK: - Old films

nonisolated struct OldFilm: Sendable, Hashable {
    let identifier: String
    let title: String
    let videoURL: URL
}

/// Public-domain films of a city from the Internet Archive's Prelinger Archives.
/// Free, no key. Only films marked public domain or CC0 are used.
actor OldFilmService {
    static let shared = OldFilmService()
    private var cache: [String: OldFilm?] = [:]

    func film(for city: String) async -> OldFilm? {
        if let cached = cache[city] { return cached }
        let film = await search(city)
        cache[city] = film
        return film
    }

    private func search(_ city: String) async -> OldFilm? {
        // The title must name the city, so it's a film of this city and not just a mention
        let quoted = city.replacingOccurrences(of: "\"", with: "")
        var components = URLComponents(string: "https://archive.org/advancedsearch.php")!
        components.queryItems = [
            .init(name: "q", value: "collection:prelinger AND mediatype:movies AND title:(\"\(quoted)\") "
                  + "AND (licenseurl:*publicdomain* OR licenseurl:*zero*)"),
            .init(name: "fl[]", value: "identifier"),
            .init(name: "fl[]", value: "title"),
            .init(name: "sort[]", value: "downloads desc"),
            .init(name: "rows", value: "5"),
            .init(name: "output", value: "json"),
        ]
        guard let url = components.url,
              let search: SearchResponse = await get(url) else { return nil }
        for doc in search.response.docs {
            if let video = await videoURL(identifier: doc.identifier) {
                return OldFilm(identifier: doc.identifier, title: doc.title, videoURL: video)
            }
        }
        return nil
    }

    /// The film's MP4, preferring the smaller streaming copy
    private func videoURL(identifier: String) async -> URL? {
        guard let url = URL(string: "https://archive.org/metadata/\(identifier)/files"),
              let files: FilesResponse = await get(url) else { return nil }
        let mp4s = files.result.filter { $0.name.hasSuffix(".mp4") }
        guard let file = mp4s.first(where: { $0.name.hasSuffix("_512kb.mp4") }) ?? mp4s.first,
              let encoded = file.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else { return nil }
        return URL(string: "https://archive.org/download/\(identifier)/\(encoded)")
    }

    private func get<T: Decodable>(_ url: URL) async -> T? {
        guard let (data, response) = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 20)),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private struct SearchResponse: Decodable {
        struct Inner: Decodable { let docs: [Doc] }
        struct Doc: Decodable { let identifier: String; let title: String }
        let response: Inner
    }

    private struct FilesResponse: Decodable {
        struct File: Decodable { let name: String }
        let result: [File]
    }
}
