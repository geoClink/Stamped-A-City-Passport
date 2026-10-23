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

    // App names that don't match their Wikipedia article title
    private let titleOverrides: [String: String] = [
        "The Vessel (Hudson Yards)": "Vessel (structure)",
    ]

    func summary(for buildingName: String) async -> WikiSummary {
        if let cached = cache[buildingName] { return cached }

        // Try the most specific title first, then looser versions of the name
        var candidates = [titleOverrides[buildingName] ?? buildingName]
        candidates.append(simplify(buildingName))
        candidates.append(simplify(removingParenthetical(buildingName)))

        var result = WikiSummary(photoURL: nil, extract: nil)
        var tried = Set<String>()
        for title in candidates where !tried.contains(title) {
            tried.insert(title)
            if let found = await fetch(title: title) {
                result = found
                break
            }
        }

        cache[buildingName] = result
        return result
    }

    // MARK: - Private

    private func fetch(title: String) async -> WikiSummary? {
        let encoded = encodedTitle(title)
        guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)") else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: wikiRequest(url))
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

            let decoded = try JSONDecoder().decode(WikiAPIResponse.self, from: data)

            // Prefer originalimage (higher resolution), fall back to thumbnail
            var photoURL = decoded.originalimage?.source.flatMap(URL.init)
                ?? decoded.thumbnail?.source.flatMap(URL.init)

            // Some articles have no lead photo, or use a logo/diagram as it
            // (e.g. One World Trade Center). Look further down the article instead.
            if photoURL == nil || isLogoOrDiagram(photoURL) {
                photoURL = await firstPhotoInArticle(encodedTitle: encoded) ?? photoURL
            }

            let extract = decoded.extract?.isEmpty == false ? decoded.extract : nil

            return WikiSummary(photoURL: photoURL, extract: extract)
        } catch {
            return nil
        }
    }

    /// First real photograph (not a logo, map or diagram) in the article's media list.
    private func firstPhotoInArticle(encodedTitle: String) async -> URL? {
        guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/media-list/\(encodedTitle)"),
              let (data, response) = try? await URLSession.shared.data(for: wikiRequest(url)),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let list = try? JSONDecoder().decode(WikiMediaList.self, from: data)
        else { return nil }

        for item in list.items where item.type == "image" {
            // srcset entries look like "//upload.wikimedia.org/..."; take the largest
            guard let src = item.srcset?.last?.src else { continue }
            let candidate = URL(string: src.hasPrefix("//") ? "https:" + src : src)
            if let candidate, !isLogoOrDiagram(candidate) { return candidate }
        }
        return nil
    }

    private func isLogoOrDiagram(_ url: URL?) -> Bool {
        guard let path = url?.absoluteString.lowercased() else { return false }
        return path.contains(".svg") || path.contains("logo") || path.contains("map")
    }

    private func encodedTitle(_ title: String) -> String {
        title.replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
    }

    // Wikipedia asks apps to identify themselves
    private func wikiRequest(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Stamped-A-City-Passport/2.3 (iOS)", forHTTPHeaderField: "User-Agent")
        return request
    }

    // "Rockefeller Center (30 Rock)" → "Rockefeller Center"
    private func removingParenthetical(_ name: String) -> String {
        guard let open = name.firstIndex(of: "(") else { return name }
        return String(name[..<open]).trimmingCharacters(in: .whitespaces)
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

nonisolated private struct WikiAPIResponse: Decodable {
    let thumbnail: WikiImage?
    let originalimage: WikiImage?
    let extract: String?
}

nonisolated private struct WikiImage: Decodable {
    let source: String?
}

nonisolated private struct WikiMediaList: Decodable {
    let items: [Item]
    struct Item: Decodable {
        let type: String?
        let srcset: [Source]?
    }
    struct Source: Decodable {
        let src: String
    }
}
