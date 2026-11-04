//
//  CampusHistoryService.swift
//  Stamped! A City Passport
//
//  The History card's text: a university's founding year (Wikidata "inception", P571)
//  and a few sentences from its English Wikipedia article (the REST summary API, the
//  same one WikimediaService uses for buildings). No API key required.
//
//  Wikipedia text stays in English, like every other Wikipedia text in the app.
//

import Foundation
import NaturalLanguage

// MARK: - Result model

nonisolated struct CampusHistory: Equatable, Codable {
    /// e.g. 1855; nil when Wikidata has no single, clear founding year
    let foundedYear: Int?
    /// 2–4 sentences from the article's introduction
    let summary: String
    /// The full article, for "Read more on Wikipedia"
    let articleURL: URL?
}

// MARK: - Service

actor CampusHistoryService {
    static let shared = CampusHistoryService()

    // In-memory cache: article title → history. Failures aren't cached, so they're retried.
    private var cache: [String: CampusHistory] = [:]

    private init() {}

    /// The History card for a campus's article (`historyArticleTitle`), or nil when Wikipedia has nothing.
    func history(forArticle title: String) async -> CampusHistory? {
        if let cached = cache[title] { return cached }

        // A campus saved for offline use: its saved copy, without the network
        if let saved = OfflineStore.shared.history(forArticle: title) {
            cache[title] = saved
            return saved
        }

        guard let summary = await fetchSummary(title: title) else { return nil }
        let text = Self.historySentences(from: summary.extract)
        guard !text.isEmpty else { return nil }

        // The founding year is a nice extra; the card still shows without it
        var year: Int? = nil
        if let item = summary.wikibaseItem {
            year = await fetchFoundedYear(item: item)
        }

        let history = CampusHistory(foundedYear: year, summary: text, articleURL: summary.pageURL)
        cache[title] = history
        return history
    }

    // MARK: - Text

    /// The sentences the card shows. The page's header already shows the article's first
    /// two sentences, so History carries on from the third (up to four sentences). A short
    /// article with fewer than two more sentences shows its opening instead.
    nonisolated static func historySentences(from extract: String, skipping skipped: Int = 2, maximum: Int = 4) -> String {
        let sentences = splitSentences(extract)
        let rest = Array(sentences.dropFirst(skipped))
        let chosen = rest.count >= 2 ? rest : sentences
        return chosen.prefix(maximum).joined(separator: " ")
    }

    /// Splits text into sentences without breaking at "U.S." or "St." the way ". " would.
    nonisolated static func splitSentences(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { sentences.append(sentence) }
            return true
        }
        return sentences
    }

    // MARK: - Founding year

    /// The founding year from a Wikidata `wbgetclaims` reply for P571. A "preferred" value wins;
    /// otherwise every value must agree on the year (University of Maryland lists both 1856
    /// and 1858, so it gets none). Values less precise than a year are ignored.
    nonisolated static func foundedYear(fromClaims data: Data) -> Int? {
        guard let decoded = try? JSONDecoder().decode(WikidataClaims.self, from: data) else { return nil }
        let statements = (decoded.claims["P571"] ?? []).filter { $0.rank != "deprecated" }

        func year(_ statement: WikidataStatement) -> Int? {
            // Precision 9 = year, 10 = month, 11 = day; below 9 is a decade or century
            guard let value = statement.mainsnak.datavalue?.value, value.precision >= 9 else { return nil }
            // "+1855-02-12T00:00:00Z" → 1855
            let digits = value.time.drop { $0 == "+" }.prefix { $0 != "-" }
            return Int(digits)
        }

        let preferred = statements.filter { $0.rank == "preferred" }.compactMap(year)
        if preferred.count == 1 { return preferred[0] }

        let years = Set(statements.compactMap(year))
        return years.count == 1 ? years.first : nil
    }

    // MARK: - Network

    private func fetchSummary(title: String) async -> WikiPageSummary? {
        let encoded = title.replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)"),
              let (data, response) = try? await URLSession.shared.data(for: wikiRequest(url)),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(WikiPageSummary.self, from: data),
              // A "may refer to" list isn't the university's history
              decoded.type != "disambiguation"
        else { return nil }
        return decoded
    }

    private func fetchFoundedYear(item: String) async -> Int? {
        var comps = URLComponents(string: "https://www.wikidata.org/w/api.php")!
        comps.queryItems = [
            URLQueryItem(name: "action", value: "wbgetclaims"),
            URLQueryItem(name: "entity", value: item),
            URLQueryItem(name: "property", value: "P571"),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = comps.url,
              let (data, response) = try? await URLSession.shared.data(for: wikiRequest(url)),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return Self.foundedYear(fromClaims: data)
    }

    // Wikipedia and Wikidata ask apps to identify themselves (same User-Agent as WikimediaService)
    private func wikiRequest(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Stamped-A-City-Passport/2.3 (iOS)", forHTTPHeaderField: "User-Agent")
        return request
    }
}

// MARK: - Wikipedia / Wikidata response shapes

nonisolated private struct WikiPageSummary: Decodable {
    let type: String?
    let extract: String
    let wikibaseItem: String?
    let contentURLs: ContentURLs?

    var pageURL: URL? { contentURLs?.desktop?.page.flatMap(URL.init) }

    struct ContentURLs: Decodable {
        let desktop: Page?
    }
    struct Page: Decodable {
        let page: String?
    }

    enum CodingKeys: String, CodingKey {
        case type, extract
        case wikibaseItem = "wikibase_item"
        case contentURLs = "content_urls"
    }
}

nonisolated private struct WikidataClaims: Decodable {
    let claims: [String: [WikidataStatement]]
}

nonisolated private struct WikidataStatement: Decodable {
    let rank: String?
    let mainsnak: Snak

    struct Snak: Decodable {
        let datavalue: DataValue?
    }
    struct DataValue: Decodable {
        let value: TimeValue
    }
    struct TimeValue: Decodable {
        let time: String
        let precision: Int
    }
}
