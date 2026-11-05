//
//  OldFilms.swift
//  Stamped! A City Passport
//
//  Old films of a city, for Step into the Past.
//

import Foundation

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
        guard let name = Self.bestVideo(in: files.result.map(\.name)),
              let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else { return nil }
        return URL(string: "https://archive.org/download/\(identifier)/\(encoded)")
    }

    nonisolated static func bestVideo(in names: [String]) -> String? {
        let mp4s = names.filter { $0.hasSuffix(".mp4") }
        return mp4s.first { $0.hasSuffix("_512kb.mp4") } ?? mp4s.first
    }

    private func get<T: Decodable>(_ url: URL) async -> T? {
        guard let (data, response) = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 20)),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    nonisolated private struct SearchResponse: Decodable {
        struct Inner: Decodable { let docs: [Doc] }
        struct Doc: Decodable { let identifier: String; let title: String }
        let response: Inner
    }

    nonisolated private struct FilesResponse: Decodable {
        struct File: Decodable { let name: String }
        let result: [File]
    }
}
