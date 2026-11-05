//
//  HeritageService.swift
//  Stamped! A City Passport
//
//  Why a landmark matters, and more old photos of it. No API keys.
//  - National Register of Historic Places: the listing's reference number from
//    Wikidata (P649), linked to its official record and nomination on NPGallery.
//  - UNESCO World Heritage: the site ID from Wikidata (P757), then the site's name,
//    year inscribed and short description from UNESCO's open data (CC BY-SA 3.0 IGO).
//  - Old photos from Wikimedia Commons: files in the landmark's Commons category
//    (Wikidata P373) dated before 1960, public domain or CC0/CC BY/CC BY-SA only.
//  Cached in memory, like `HistoryTimelineService`.
//

import Foundation

nonisolated struct Heritage: Hashable, Sendable {
    /// National Register of Historic Places reference number, e.g. "82001192"
    var nrhpID: String?
    var unesco: UNESCOSite?

    var isEmpty: Bool { nrhpID == nil && unesco == nil }

    var nrhpURL: URL? {
        nrhpID.flatMap { URL(string: "https://npgallery.nps.gov/AssetDetail/NRIS/\($0)") }
    }
}

nonisolated struct UNESCOSite: Hashable, Sendable {
    let id: String
    let name: String
    let summary: String
    let yearInscribed: Int?

    var url: URL? { URL(string: "https://whc.unesco.org/en/list/\(id)/") }
}

actor HeritageService {
    static let shared = HeritageService()

    /// The most Commons photos used for one landmark
    nonisolated static let maxPhotos = 6
    /// Photos dated this year or later aren't "old"
    nonisolated static let oldBefore = 1960

    private var heritageCache: [String: Heritage] = [:]
    private var categoryCache: [String: String?] = [:]
    private var photoCache: [String: [HistoricImage]] = [:]

    private init() {}

    // MARK: Listings

    func heritage(for building: Building) async -> Heritage {
        if let cached = heritageCache[building.id] { return cached }
        guard let facts = await wikidataFacts(for: building) else { return Heritage() }
        var heritage = Heritage(nrhpID: facts.nrhp)
        if let whs = facts.whs {
            heritage.unesco = await unescoSite(id: whs)
        }
        heritageCache[building.id] = heritage
        return heritage
    }

    /// UNESCO's own name and summary, in the device's language when UNESCO has it
    private func unescoSite(id: String) async -> UNESCOSite? {
        // Wikidata sometimes gives a component ("1047-001"); UNESCO lists the whole site
        let siteID = String(id.prefix { $0 != "-" })
        guard siteID.allSatisfy(\.isNumber), !siteID.isEmpty else { return nil }
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        let suffix = ["en", "fr", "es", "ru", "ar", "zh"].contains(language) ? language : "en"
        var components = URLComponents(string: "https://data.unesco.org/api/explore/v2.1/catalog/datasets/whc001/records")!
        components.queryItems = [
            URLQueryItem(name: "where", value: "id_no=\"\(siteID)\""),
            URLQueryItem(name: "limit", value: "1"),
        ]
        guard let url = components.url,
              let response: UNESCOResponse = await get(url),
              let record = response.results.first else { return nil }
        let name = record.string("name_\(suffix)") ?? record.string("name_en") ?? ""
        let summary = record.string("short_description_\(suffix)") ?? record.string("short_description_en") ?? ""
        return UNESCOSite(id: siteID, name: Self.plainText(name), summary: Self.plainText(summary),
                          yearInscribed: record.string("date_inscribed").flatMap { Int($0) })
    }

    // MARK: Commons photos

    /// Old photos from the landmark's Commons category, oldest first
    func oldPhotos(for building: Building) async -> [HistoricImage] {
        if let cached = photoCache[building.id] { return cached }
        guard let category = await commonsCategory(for: building) else { return [] }

        // Naming the year it was built finds the construction and opening photos
        var search = "deepcat:\"\(category.replacingOccurrences(of: "\"", with: ""))\" filetype:bitmap"
        // yearBuilt 0 means unknown (`hasKnownYear` is main-actor only)
        if building.yearBuilt != 0 {
            search += " (\(building.yearBuilt - 1) OR \(building.yearBuilt) OR \(building.yearBuilt + 1))"
        }
        var components = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        components.queryItems = [
            "action": "query", "format": "json", "formatversion": "2",
            "generator": "search", "gsrsearch": search, "gsrnamespace": "6", "gsrlimit": "50",
            "prop": "imageinfo", "iiprop": "url|extmetadata", "iiurlwidth": "800",
            "iiextmetadatafilter": "DateTimeOriginal|LicenseShortName|Artist|ImageDescription",
        ].map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url, let response: CommonsResponse = await get(url) else { return [] }
        let result = Self.commonsPhotos(from: response)
        photoCache[building.id] = result
        return result
    }

    /// The photos in a Commons search result that are old, free to use and creditable, oldest first
    nonisolated static func commonsPhotos(from data: Data) -> [HistoricImage] {
        guard let response = try? JSONDecoder().decode(CommonsResponse.self, from: data) else { return [] }
        return commonsPhotos(from: response)
    }

    nonisolated private static func commonsPhotos(from response: CommonsResponse) -> [HistoricImage] {
        var photos: [(year: Int, image: HistoricImage)] = []
        for page in response.query?.pages ?? [] {
            guard let info = page.imageinfo?.first,
                  let thumb = info.thumburl.flatMap(URL.init), let full = info.url.flatMap(URL.init),
                  let pageURL = info.descriptionurl.flatMap(URL.init),
                  let meta = info.extmetadata,
                  let year = Self.year(in: Self.plainText(meta["DateTimeOriginal"]?.value ?? "")),
                  year < Self.oldBefore,
                  let licence = meta["LicenseShortName"]?.value, Self.isFreeForCommercialUse(licence)
            else { continue }
            let artist = Self.plainText(meta["Artist"]?.value ?? "")
            // CC BY and CC BY-SA require the author's name
            if artist.isEmpty, licence.lowercased().hasPrefix("cc"), !licence.lowercased().contains("cc0") { continue }
            let credit = [artist.isEmpty ? nil : artist, licence, "Wikimedia Commons"]
                .compactMap { $0 }.joined(separator: " · ")
            let caption = Self.plainText(meta["ImageDescription"]?.value ?? "")
            photos.append((year, HistoricImage(thumbnailURL: thumb, largeURL: full,
                                               caption: caption.isEmpty ? nil : String(caption.prefix(140)),
                                               isDrawing: false, credit: credit, itemURL: pageURL)))
        }
        return Array(photos.sorted { $0.year < $1.year }.prefix(Self.maxPhotos).map(\.image))
    }

    private func commonsCategory(for building: Building) async -> String? {
        if let cached = categoryCache[building.id] { return cached }
        let category = await wikidataFacts(for: building)?.category
        categoryCache[building.id] = category
        return category
    }

    // MARK: Wikidata

    private struct Facts { var nrhp: String?; var whs: String?; var category: String? }

    private func wikidataFacts(for building: Building) async -> Facts? {
        guard let itemID = await HistoryTimelineService.shared.wikidataItemID(for: building),
              itemID.range(of: #"^Q\d+$"#, options: .regularExpression) != nil else { return nil }
        let query = """
        SELECT ?nrhp ?whs ?cat WHERE {
          OPTIONAL { wd:\(itemID) wdt:P649 ?nrhp. }
          OPTIONAL { wd:\(itemID) wdt:P757 ?whs. }
          OPTIONAL { wd:\(itemID) wdt:P373 ?cat. }
        } LIMIT 1
        """
        var components = URLComponents(string: "https://query.wikidata.org/sparql")!
        components.queryItems = [URLQueryItem(name: "query", value: query), URLQueryItem(name: "format", value: "json")]
        guard let url = components.url, let response: SPARQLResponse = await get(url),
              let row = response.results.bindings.first else { return nil }
        return Facts(nrhp: row["nrhp"]?.value, whs: row["whs"]?.value, category: row["cat"]?.value)
    }

    // MARK: Helpers

    /// Public domain, CC0, CC BY and CC BY-SA allow use in an app that earns money
    nonisolated static func isFreeForCommercialUse(_ licence: String) -> Bool {
        let text = licence.lowercased()
        // NonCommercial (NC) licences can't be used in a paid app, and NoDerivatives (ND)
        // ones can't be cropped or faded. "Not public domain" is what it says.
        if text.range(of: #"\b(nc|nd|not|non-?commercial)\b"#, options: .regularExpression) != nil { return false }
        return text.contains("public domain") || text.hasPrefix("pd") || text.contains("cc0")
            || text.hasPrefix("cc by") || text.hasPrefix("cc-by")
    }

    /// The first plausible year in a date text ("1931-05-01", "circa 1930", "May 1931")
    nonisolated static func year(in text: String) -> Int? {
        guard let range = text.range(of: #"\b1[5-9]\d\d\b"#, options: .regularExpression) else { return nil }
        return Int(text[range])
    }

    /// Commons and UNESCO texts contain HTML tags and entities
    nonisolated static func plainText(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (entity, character) in ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&nbsp;": " ", "&lt;": "<", "&gt;": ">"] {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        return text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func get<Response: Decodable>(_ url: URL) async -> Response? {
        var request = URLRequest(url: url, timeoutInterval: 20)
        // Wikimedia asks apps to identify themselves
        request.setValue("Stamped-A-City-Passport/2.10", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return try? JSONDecoder().decode(Response.self, from: data)
    }
}

// MARK: - Responses

nonisolated private struct SPARQLResponse: Decodable {
    struct Results: Decodable { let bindings: [[String: Value]] }
    struct Value: Decodable { let value: String }
    let results: Results
}

nonisolated private struct UNESCOResponse: Decodable {
    let results: [[String: JSONValue]]
}

nonisolated private extension Dictionary where Key == String, Value == JSONValue {
    func string(_ key: String) -> String? {
        if case .string(let text)? = self[key], !text.isEmpty, text != "None" { return text }
        return nil
    }
}

/// UNESCO records mix strings, numbers, lists and nulls; only the strings are used
nonisolated private enum JSONValue: Decodable {
    case string(String), other
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) { self = .string(text) } else { self = .other }
    }
}

nonisolated private struct CommonsResponse: Decodable {
    struct Query: Decodable { let pages: [Page] }
    struct Page: Decodable { let imageinfo: [Info]? }
    struct Info: Decodable {
        let url: String?
        let thumburl: String?
        let descriptionurl: String?
        let extmetadata: [String: Meta]?
    }
    struct Meta: Decodable {
        let value: String?
        // Some fields hold numbers or lists; those are skipped rather than failing the page
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try? container.decode(String.self, forKey: .value)
        }
        private enum CodingKeys: String, CodingKey { case value }
    }
    let query: Query?
}
