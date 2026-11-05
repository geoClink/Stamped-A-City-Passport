//
//  CitySounds.swift
//  Tally-AVP
//
//  City sounds for Step into the Past: a CC0 street ambience from Freesound, played
//  softly all around the viewer while the old photos fade. CC0 needs no credit, but
//  the sound and its author are named on the panel anyway. Key in Secrets.plist.
//

import Foundation

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
            URLQueryItem(name: "fields", value: "id,name,username,previews"),
            URLQueryItem(name: "page_size", value: "5"),
            URLQueryItem(name: "token", value: key),
        ]
        guard let url = components.url,
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let result = try? JSONDecoder().decode(SearchResponse.self, from: data),
              let first = result.results.first,
              let preview = URL(string: first.previews.previewHQMP3),
              let page = URL(string: "https://freesound.org/s/\(first.id)/")
        else { return nil }
        return CitySound(name: first.name, author: first.username, previewURL: preview, pageURL: page)
    }

    private struct SearchResponse: Decodable {
        struct Sound: Decodable {
            struct Previews: Decodable {
                let previewHQMP3: String
                enum CodingKeys: String, CodingKey { case previewHQMP3 = "preview-hq-mp3" }
            }
            let id: Int
            let name: String
            let username: String
            let previews: Previews
        }
        let results: [Sound]
    }
}
