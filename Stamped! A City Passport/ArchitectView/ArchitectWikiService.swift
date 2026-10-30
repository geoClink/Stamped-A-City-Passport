//
//  ArchitectWikiService.swift
//  Stamped! A City Passport
//
//  The short bio and portrait on an Architect page, from the Wikipedia REST
//  summary. Mirrors `WikimediaService` (same endpoint, in-memory cache, User-Agent),
//  with one extra check: the article must describe an architect, a firm or a
//  designer. Plenty of architects share a name with someone else ("John Graham"),
//  and no bio is better than the wrong person's.
//

import Foundation

struct ArchitectSummary {
    /// The article's lead image, hosted on Wikimedia Commons. nil when there is none,
    /// or when it is only a logo or diagram.
    let photoURL: URL?
    let extract: String
    /// The full article, for the "Read on Wikipedia" link
    let articleURL: URL?
}

actor ArchitectWikiService {
    static let shared = ArchitectWikiService()

    // Architect name → summary. A name with no matching article is cached as nil,
    // so the page doesn't ask again every time it opens.
    private var cache: [String: ArchitectSummary?] = [:]

    private init() {}

    func summary(for architectName: String) async -> ArchitectSummary? {
        if let cached = cache[architectName] { return cached }

        // The plain name first, then the title Wikipedia uses when the name is shared
        // ("John Graham (architect)")
        var result: ArchitectSummary? = nil
        for title in [architectName, "\(architectName) (architect)"] {
            if let found = await fetch(title: title) {
                result = found
                break
            }
        }
        cache[architectName] = result
        return result
    }

    // MARK: - Private

    private func fetch(title: String) async -> ArchitectSummary? {
        let encoded = title.replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)") else {
            return nil
        }

        var request = URLRequest(url: url)
        // Wikipedia asks apps to identify themselves
        request.setValue("Stamped-A-City-Passport/2.3 (iOS)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(ArchitectAPIResponse.self, from: data),
              decoded.type != "disambiguation",
              Self.describesArchitect(decoded.description),
              let extract = decoded.extract, !extract.isEmpty
        else { return nil }

        // The small thumbnail is plenty for a portrait; fall back to the original
        var photoURL = decoded.thumbnail?.source.flatMap(URL.init)
            ?? decoded.originalimage?.source.flatMap(URL.init)
        // A firm's lead image is often its logo, which isn't a photo of anyone
        if let path = photoURL?.absoluteString.lowercased(), path.contains(".svg") || path.contains("logo") {
            photoURL = nil
        }

        return ArchitectSummary(
            photoURL: photoURL,
            extract: extract,
            articleURL: decoded.contentURLs?.desktop?.page.flatMap(URL.init)
        )
    }

    /// True when Wikipedia's one-line description ("American architect (1917–2019)",
    /// "Swiss architecture firm", "Danish designer") is about designing buildings.
    /// "architect" also matches "architecture" and "architectural".
    static func describesArchitect(_ description: String?) -> Bool {
        guard let description = description?.lowercased() else { return false }
        return description.contains("architect") || description.contains("designer")
    }
}

// MARK: - Decodable response shape

nonisolated private struct ArchitectAPIResponse: Decodable {
    /// "standard" for a normal article, "disambiguation" for a "may refer to" list
    let type: String?
    /// The short line under the title, e.g. "American architect (1917–2019)"
    let description: String?
    let extract: String?
    let thumbnail: ArchitectAPIImage?
    let originalimage: ArchitectAPIImage?
    let contentURLs: ContentURLs?

    enum CodingKeys: String, CodingKey {
        case type, description, extract, thumbnail, originalimage
        case contentURLs = "content_urls"
    }

    struct ContentURLs: Decodable {
        let desktop: Page?
    }
    struct Page: Decodable {
        let page: String?
    }
}

nonisolated private struct ArchitectAPIImage: Decodable {
    let source: String?
}
