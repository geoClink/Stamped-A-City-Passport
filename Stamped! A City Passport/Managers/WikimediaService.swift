//
//  WikimediaService.swift
//  Stamped! A City Passport
//
//  Fetches the main CC-licensed photo and opening paragraph for any building
//  using the Wikipedia REST API. No API key required.
//
//  Falls back gracefully: if Wikipedia has no article, the UI falls back to
//  the app's asset catalog image.
//

import Foundation

// MARK: - Result model

struct WikiSummary {
    let photoURL: URL?
    let extract: String?     // First paragraph from Wikipedia article
}

// MARK: - Service

actor WikimediaService {
    static let shared = WikimediaService()

    // In-memory cache: building name → summary
    private var cache: [String: WikiSummary] = [:]

    private init() {}

    func summary(for buildingName: String) async -> WikiSummary {
        if let cached = cache[buildingName] { return cached }

        let primary = await fetch(title: buildingName)
        let result: WikiSummary
        if let p = primary {
            result = p
        } else {
            let secondary = await fetch(title: simplify(buildingName))
            result = secondary ?? WikiSummary(photoURL: nil, extract: nil)
        }

        cache[buildingName] = result
        return result
    }

    // MARK: - Private

    private func fetch(title: String) async -> WikiSummary? {
        let encoded = title
            .replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title

        guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)") else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

            let decoded = try JSONDecoder().decode(WikiAPIResponse.self, from: data)

            // Prefer originalimage (higher resolution), fall back to thumbnail
            let photoURL = decoded.originalimage?.source.flatMap(URL.init)
                ?? decoded.thumbnail?.source.flatMap(URL.init)

            let extract = decoded.extract?.isEmpty == false ? decoded.extract : nil

            return WikiSummary(photoURL: photoURL, extract: extract)
        } catch {
            return nil
        }
    }

    // Strip common prefixes that don't match Wikipedia titles
    // e.g. "The Empire State Building" → "Empire State Building"
    private func simplify(_ name: String) -> String {
        let prefixes = ["The ", "A ", "An "]
        for prefix in prefixes {
            if name.hasPrefix(prefix) {
                return String(name.dropFirst(prefix.count))
            }
        }
        return name
    }
}

// MARK: - Decodable response shape

private struct WikiAPIResponse: Decodable {
    let thumbnail: WikiImage?
    let originalimage: WikiImage?
    let extract: String?
}

private struct WikiImage: Decodable {
    let source: String?
}
