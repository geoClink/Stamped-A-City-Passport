//
//  CitySounds.swift
//  Stamped! A City Passport
//
//  City sounds: a CC0 street ambience from Freesound, played softly around the viewer
//  in Step into the Past and under the map's tour. CC0 needs no
//  credit, but the sound and its author are named on screen anyway. Key in Secrets.plist;
//  without it there's simply no sound.
//

import Foundation
import AVFoundation

nonisolated struct CitySound: Sendable, Hashable {
    let name: String
    let author: String
    /// Freesound's MP3 preview: public, no key needed to download it
    let previewURL: URL
    let pageURL: URL
}

actor CitySoundService {
    static let shared = CitySoundService()
    private var cache: [String: CitySound?] = [:]

    /// A street ambience recorded in the city when there is one, else any city street
    func sound(for city: String) async -> CitySound? {
        if let cached = cache[city] { return cached }
        var found = await search("\(city) street ambience")
        if found == nil { found = await search("city street ambience") }
        cache[city] = found
        return found
    }

    /// Downloads the preview so RealityKit can play it as an audio resource
    func localFile(for sound: CitySound) async -> URL? {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("citysound-\(sound.previewURL.lastPathComponent)")
        if FileManager.default.fileExists(atPath: file.path) { return file }
        guard let (data, response) = try? await URLSession.shared.data(from: sound.previewURL),
              (response as? HTTPURLResponse)?.statusCode == 200,
              (try? data.write(to: file)) != nil else { return nil }
        return file
    }

    private func search(_ query: String) async -> CitySound? {
        guard let key = Secrets.freesoundKey else { return nil }
        var components = URLComponents(string: "https://freesound.org/apiv2/search/text/")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            // CC0 only, long enough to loop without a noticeable repeat
            URLQueryItem(name: "filter", value: "license:\"Creative Commons 0\" duration:[30 TO 600]"),
            URLQueryItem(name: "sort", value: "rating_desc"),
            URLQueryItem(name: "fields", value: "id,name,username,license,previews"),
            URLQueryItem(name: "page_size", value: "5"),
            URLQueryItem(name: "token", value: key),
        ]
        guard let url = components.url,
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return Self.firstSound(from: data)
    }

    /// The first CC0 sound in a search result. The search asks for CC0 only; each
    /// sound's own licence is checked as well, since the app earns money.
    nonisolated static func firstSound(from data: Data) -> CitySound? {
        guard let result = try? JSONDecoder().decode(SearchResponse.self, from: data) else { return nil }
        for sound in result.results where isCC0(sound.license) {
            guard let preview = URL(string: sound.previews.previewHQMP3),
                  let page = URL(string: "https://freesound.org/s/\(sound.id)/") else { continue }
            return CitySound(name: sound.name, author: sound.username, previewURL: preview, pageURL: page)
        }
        return nil
    }

    /// Freesound names a licence by its URL or, in some responses, by its title
    nonisolated private static func isCC0(_ license: String?) -> Bool {
        guard let license else { return false }
        return ArchiveSearch.licence(fromRightsURL: license) == "CC0" || license == "Creative Commons 0"
    }

    nonisolated private struct SearchResponse: Decodable {
        struct Sound: Decodable {
            struct Previews: Decodable {
                let previewHQMP3: String
                enum CodingKeys: String, CodingKey { case previewHQMP3 = "preview-hq-mp3" }
            }
            let id: Int
            let name: String
            let username: String
            let license: String?
            let previews: Previews
        }
        let results: [Sound]
    }
}

/// The street ambience under a map tour or an old photo slideshow: quiet and looping.
/// On iPhone it mixes with other apps' sound and obeys the ringer switch.
@MainActor
final class CitySoundLoop {
    private var player: AVAudioPlayer?

    func play(_ file: URL) {
        stop()
        guard let player = try? AVAudioPlayer(contentsOf: file) else { return }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        player.numberOfLoops = -1
        player.volume = 0.3
        player.play()
        self.player = player
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
