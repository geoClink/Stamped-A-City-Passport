//
//  HistoryTimelineService.swift
//  Stamped! A City Passport
//
//  A landmark's history over time, for the Timeline on its page:
//  - Dates from Wikidata (found through the landmark's Wikipedia article): built,
//    opened, demolished, events such as fires and renovations, heritage listings,
//    and what it replaced or was replaced by. Labels come in the device's language.
//  - "What the papers said": newspaper pages from around the year it was built,
//    from the Library of Congress's Chronicling America (US papers, 1770–1963).
//  No API key required. Both are cached in memory, like `WikiGalleryService`.
//
//  Chronicling America is slow (often 30–60 s per search), so the page asks for
//  the timeline and the newspapers separately and never waits on the newspapers.
//

import Foundation

// MARK: - Result models

/// One dated moment in a landmark's life
nonisolated struct HistoryEvent: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case built, opened, demolished, event, heritage, replaces, replacedBy
    }

    let kind: Kind
    let year: Int
    /// Wikidata's precision: 11 = day, 10 = month, 9 = year, 8 = decade, lower = century or more
    let precision: Int
    let date: Date?
    /// The event, listing or building named by Wikidata ("National Historic Landmark")
    let label: String?

    var id: String { "\(kind.rawValue)-\(year)-\(label ?? "")" }
}

/// A newspaper page that mentions the landmark
nonisolated struct NewspaperClipping: Identifiable, Hashable {
    let paper: String        // "New-York tribune (New York [N.Y.])"
    let date: Date
    /// The sentence around the landmark's name, from the page's OCR text (may contain errors)
    let quote: String
    let imageURL: URL?       // The scanned page, 400 px wide
    let pageURL: URL         // The page on loc.gov

    var id: URL { pageURL }
}

// MARK: - Service

actor HistoryTimelineService {
    static let shared = HistoryTimelineService()

    /// Chronicling America's papers run from 1770 to 1963
    static let newspaperYears = 1770...1963
    static let maxClippings = 3

    // Building ID → results (empty when there are none)
    private var timelines: [String: [HistoryEvent]] = [:]
    private var clippingCache: [String: [NewspaperClipping]] = [:]
    private var itemIDs: [String: String] = [:]

    private init() {}

    // MARK: Timeline

    /// Every dated moment Wikidata knows, oldest first. Falls back to the registry's
    /// build year when Wikidata has none, so most landmarks show at least one entry.
    func timeline(for building: Building) async -> [HistoryEvent] {
        if let cached = timelines[building.id] { return cached }

        var events: [HistoryEvent] = []
        if let itemID = await wikidataItemID(for: building) {
            events = await wikidataEvents(itemID: itemID)
        }
        if building.hasKnownYear, !events.contains(where: { $0.kind == .built || $0.kind == .opened }) {
            events.append(HistoryEvent(kind: .built, year: building.yearBuilt, precision: 9, date: nil, label: nil))
        }

        // The same listing is sometimes given twice ("inscrit" with and without a date)
        var seen: Set<String> = []
        events = events.filter { seen.insert($0.id).inserted }
            .sorted { ($0.year, $0.date ?? .distantPast) < ($1.year, $1.date ?? .distantPast) }
        timelines[building.id] = events
        return events
    }

    /// The landmark's Wikidata item ("Q9188"), found through its Wikipedia article.
    /// Also used by `HeritageService` for listings and Commons photos.
    func wikidataItemID(for building: Building) async -> String? {
        if let cached = itemIDs[building.id] { return cached }
        let summary = await WikimediaService.shared.summary(for: building.name, buildingID: building.id)
        guard let title = summary.articleTitle, let itemID = await wikidataItem(title: title) else { return nil }
        itemIDs[building.id] = itemID
        return itemID
    }

    /// Article title → Wikidata item ID, e.g. "Q3079894"
    private func wikidataItem(title: String) async -> String? {
        var components = URLComponents(string: "https://en.wikipedia.org/w/api.php")!
        components.queryItems = [
            "action": "query", "format": "json", "formatversion": "2", "redirects": "1",
            "prop": "pageprops", "ppprop": "wikibase_item", "titles": title,
        ].map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url,
              let response: PagePropsResponse = await get(url)
        else { return nil }
        return response.query?.pages.first?.pageprops?.wikibase_item
    }

    private func wikidataEvents(itemID: String) async -> [HistoryEvent] {
        // Only an item ID ("Q" and digits) goes into the query
        guard itemID.range(of: #"^Q\d+$"#, options: .regularExpression) != nil else { return [] }
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        // Date properties first (built P571, opened P1619, demolished P576), then item
        // properties with an optional date qualifier: significant event P793 (point in time),
        // heritage designation P1435 (start), replaces P1365 / replaced by P1366.
        let query = """
        SELECT ?kind ?date ?prec ?itemLabel WHERE {
          { VALUES (?kind ?claim ?value) { ("built" p:P571 psv:P571) ("opened" p:P1619 psv:P1619) ("demolished" p:P576 psv:P576) }
            wd:\(itemID) ?claim ?s. ?s ?value ?v. ?v wikibase:timeValue ?date; wikibase:timePrecision ?prec. }
          UNION
          { VALUES (?kind ?claim ?value ?when) { ("event" p:P793 ps:P793 pqv:P585) ("heritage" p:P1435 ps:P1435 pqv:P580) ("replaces" p:P1365 ps:P1365 pqv:P580) ("replacedBy" p:P1366 ps:P1366 pqv:P582) }
            wd:\(itemID) ?claim ?s. ?s ?value ?item.
            OPTIONAL { ?s ?when ?v. ?v wikibase:timeValue ?date; wikibase:timePrecision ?prec. } }
          SERVICE wikibase:label { bd:serviceParam wikibase:language "\(language),en". }
        }
        """
        var components = URLComponents(string: "https://query.wikidata.org/sparql")!
        components.queryItems = [URLQueryItem(name: "query", value: query), URLQueryItem(name: "format", value: "json")]
        guard let url = components.url,
              let response: SPARQLResponse = await get(url)
        else { return [] }

        return response.results.bindings.compactMap { row in
            guard let kind = row.kind.flatMap({ HistoryEvent.Kind(rawValue: $0.value) }),
                  // Undated events ("construction") say nothing a timeline can place
                  let dateText = row.date?.value, let year = Self.year(from: dateText)
            else { return nil }
            var label = row.itemLabel?.value
            // An item with no label in any language comes back as its ID
            if let text = label, text.range(of: #"^Q\d+$"#, options: .regularExpression) != nil { label = nil }
            if kind != .built, kind != .opened, kind != .demolished, label == nil { return nil }
            return HistoryEvent(kind: kind, year: year,
                                precision: Int(row.prec?.value ?? "") ?? 9,
                                date: ISO8601DateFormatter().date(from: dateText),
                                label: label.map(Self.capitalizingFirst))
        }
    }

    /// "1929-01-01T00:00:00Z" → 1929, "-0500-01-01T00:00:00Z" → -500
    nonisolated static func year(from wikidataDate: String) -> Int? {
        let isNegative = wikidataDate.hasPrefix("-")
        let digits = wikidataDate.dropFirst(isNegative || wikidataDate.hasPrefix("+") ? 1 : 0)
            .prefix { $0.isNumber }
        guard let year = Int(digits) else { return nil }
        return isNegative ? -year : year
    }

    /// Wikidata labels are lowercase ("terrorist attack"); a timeline line starts with a capital
    nonisolated private static func capitalizingFirst(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    // MARK: Newspapers

    /// Up to three newspaper pages from the year before to the year after the landmark
    /// was built that print its name. Empty outside 1770–1963 or when no page matches.
    func clippings(for building: Building, cityName: String) async -> [NewspaperClipping] {
        if let cached = clippingCache[building.id] { return cached }
        guard building.hasKnownYear, Self.newspaperYears.contains(building.yearBuilt) else { return [] }

        let name = Self.searchName(building.name)
        let year = building.yearBuilt
        var components = URLComponents(string: "https://www.loc.gov/collections/chronicling-america/")!
        components.queryItems = [
            // Quotes make it a phrase search; without them any page with one of the words matches
            URLQueryItem(name: "q", value: "\"\(name)\""),
            URLQueryItem(name: "dates", value: "\(year - 1)/\(min(year + 1, Self.newspaperYears.upperBound))"),
            URLQueryItem(name: "fo", value: "json"),
            URLQueryItem(name: "c", value: "10"),
        ]
        guard let url = components.url,
              let response: NewspaperSearchResponse = await get(url, timeout: 90)
        else { return [] }   // Not cached, so a timeout can be tried again next time

        // The search only sends the start of each page's text, so the passage that names
        // the landmark comes from loc.gov's word-coordinates service (fast, one per page)
        let pages = Array((response.results ?? []).prefix(6))
        let found = await withTaskGroup(of: NewspaperClipping?.self) { group in
            for page in pages {
                group.addTask { await self.clipping(from: page, name: name, cityName: cityName) }
            }
            var found: [NewspaperClipping] = []
            for await clipping in group { if let clipping { found.append(clipping) } }
            return found
        }
        let clippings = Array(found.sorted { $0.date < $1.date }.prefix(Self.maxClippings))
        clippingCache[building.id] = clippings
        return clippings
    }

    private func clipping(from page: NewspaperSearchResponse.Page, name: String, cityName: String) async -> NewspaperClipping? {
        guard let dateText = page.date, let date = Self.dayFormatter.date(from: dateText),
              let pageURL = page.url.flatMap(URL.init),
              let snippetURL = page.word_coordinates_url.flatMap(URL.init),
              let response: [String: WordCoordinates] = await get(snippetURL),
              let snippet = response.values.first?.relevant_snippet
        else { return nil }
        // "[[tag]]Flatiron[[/tag]] [[tag]]building[[/tag]]" marks the matched words
        let text = snippet.replacingOccurrences(of: #"\[\[/?tag\]\]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        guard let match = text.range(of: name, options: [.caseInsensitive, .diacriticInsensitive]) else { return nil }
        // A short name ("City Hall") is printed about many cities, so it also needs the city nearby
        if name.split(separator: " ").count < 3, text.range(of: cityName, options: .caseInsensitive) == nil {
            return nil
        }
        return NewspaperClipping(paper: Self.paperName(fromTitle: page.title ?? ""),
                                 date: date,
                                 quote: Self.quote(around: match, in: text),
                                 imageURL: page.image_url?.first.flatMap(Self.pageImageURL),
                                 pageURL: pageURL)
    }

    /// "Fox Theatre (Detroit)" → "Fox Theatre"
    nonisolated static func searchName(_ name: String) -> String {
        name.replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// "Image 52 of New-York tribune (New York [N.Y.]), March 5, 1916" → "New-York tribune (New York [N.Y.])"
    nonisolated static func paperName(fromTitle title: String) -> String {
        var name = title
        if let of = name.range(of: " of ") { name = String(name[of.upperBound...]) }
        if let close = name.range(of: "), ", options: .backwards) { name = String(name[..<close.lowerBound]) + ")" }
        return name
    }

    /// About 300 characters around the match, cut at word boundaries, with "…" where trimmed
    nonisolated static func quote(around match: Range<String.Index>, in text: String) -> String {
        let start = text.index(match.lowerBound, offsetBy: -140, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(match.upperBound, offsetBy: 160, limitedBy: text.endIndex) ?? text.endIndex
        var words = text[start..<end].split(separator: " ")
        // Drop the half-words at each cut
        if start != text.startIndex, !words.isEmpty { words.removeFirst() }
        if end != text.endIndex, !words.isEmpty { words.removeLast() }
        return (start != text.startIndex ? "…" : "") + words.joined(separator: " ") + (end != text.endIndex ? "…" : "")
    }

    /// loc.gov gives a tiny IIIF thumbnail (".../full/pct:3.125/0/default.jpg"); ask for 400 px wide instead
    nonisolated static func pageImageURL(_ thumbnail: String) -> URL? {
        let resized = thumbnail.replacingOccurrences(of: #"/full/[^/]+/"#, with: "/full/400,/", options: .regularExpression)
        return URL(string: resized)
    }

    nonisolated private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: Networking

    private func get<Response: Decodable>(_ url: URL, timeout: TimeInterval = 20) async -> Response? {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        // Wikimedia and the Library of Congress ask apps to identify themselves
        request.setValue("Stamped-A-City-Passport/2.10 (\(Self.platform))", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return try? JSONDecoder().decode(Response.self, from: data)
    }

    nonisolated private static var platform: String {
        #if os(visionOS)
        "visionOS"
        #else
        "iOS"
        #endif
    }
}

// MARK: - Response models

nonisolated private struct PagePropsResponse: Decodable {
    struct Query: Decodable { let pages: [Page] }
    struct Page: Decodable { let pageprops: PageProps? }
    struct PageProps: Decodable { let wikibase_item: String? }
    let query: Query?
}

nonisolated private struct SPARQLResponse: Decodable {
    struct Results: Decodable { let bindings: [Row] }
    struct Row: Decodable { let kind, date, prec, itemLabel: Value? }
    struct Value: Decodable { let value: String }
    let results: Results
}

/// loc.gov warns its data can be incomplete, so every field is optional
nonisolated private struct NewspaperSearchResponse: Decodable {
    struct Page: Decodable {
        let title: String?
        let date: String?
        let url: String?
        let image_url: [String]?
        /// The passage around the match: { "<page file>": { "relevant_snippet": "…" } }
        let word_coordinates_url: String?
    }
    let results: [Page]?
}

nonisolated private struct WordCoordinates: Decodable {
    let relevant_snippet: String?
}
