//
//  WikiGalleryService.swift
//  Stamped! A City Passport
//
//  Finds more free photos of a building for the gallery on its page: the photos in
//  its Wikimedia Commons category (found through Wikidata), or, when it has none,
//  the photos in its Wikipedia article. No API key required.
//
//  Only Commons files are used, so every photo is freely licensed. Each keeps its
//  author and license, which the CC licenses require the app to show.
//

import Foundation

// MARK: - Result model

nonisolated struct WikiGalleryPhoto: Identifiable, Hashable {
    let id: String           // Commons file title, e.g. "File:201708 Biosphere Montreal 03.jpg"
    let thumbnailURL: URL    // 500 px wide, for the strip on the building page
    let largeURL: URL        // Up to 1280 px wide, for the full-screen view
    let pageURL: URL?        // The file's Commons page: author, license and full details
    let artist: String
    let license: String

    /// "Ziko · CC BY-SA 4.0"
    var credit: String { "\(artist) · \(license)" }
}

// MARK: - Service

actor WikiGalleryService {
    static let shared = WikiGalleryService()

    /// Enough to swipe through without loading dozens of photos per building
    static let maxPhotos = 10

    // In-memory cache: building ID → photos (empty when there are none)
    private var cache: [String: [WikiGalleryPhoto]] = [:]

    private init() {}

    func photos(for buildingName: String, buildingID: String) async -> [WikiGalleryPhoto] {
        if let cached = cache[buildingID] { return cached }

        // The same article the hero photo comes from, so the gallery shows the same building.
        // No article (or a skipped one) means no gallery.
        let summary = await WikimediaService.shared.summary(for: buildingName, buildingID: buildingID)
        guard let title = summary.articleTitle else {
            cache[buildingID] = []
            return []
        }

        // The Commons category holds photos of the building itself. An article also shows
        // nearby places and old drawings, so it's only used when there's no category.
        var found: [WikiGalleryPhoto] = []
        if let category = await commonsCategory(title: title) {
            found = await categoryPhotos(category: category)
        }
        if found.isEmpty {
            found = await articlePhotos(title: title)
        }

        // Leave out repeats and the photo already shown at the top of the page. The hero URL
        // ends in the file name ("Name_of_file.jpg"), or a thumbnail of it ("640px-Name_of_file.jpg").
        let heroName = summary.photoURL?.lastPathComponent ?? ""
        var seen = Set<String>()
        let result = found.filter { photo in
            guard seen.insert(photo.id).inserted else { return false }
            let fileName = photo.id.replacingOccurrences(of: "File:", with: "").replacingOccurrences(of: " ", with: "_")
            return !heroName.hasSuffix(fileName)
        }
        let limited = Array(result.prefix(Self.maxPhotos))

        cache[buildingID] = limited
        return limited
    }

    // MARK: - Private

    /// Photos used in the Wikipedia article itself.
    private func articlePhotos(title: String) async -> [WikiGalleryPhoto] {
        let pages = await imagePages(host: "en.wikipedia.org", extra: [
            "titles": title,
            "redirects": "1",
            "generator": "images",
            "gimlimit": "50",
        ])
        // "shared" files live on Commons. Files stored on Wikipedia itself are often
        // non-free (used under fair use), so those are skipped.
        return pages.filter { $0.imagerepository == "shared" }.compactMap { galleryPhoto(from: $0) }
    }

    /// Every file in the building's Commons category, e.g. "Category:Montreal Biosphère".
    private func categoryPhotos(category: String) async -> [WikiGalleryPhoto] {
        let pages = await imagePages(host: "commons.wikimedia.org", extra: [
            "generator": "categorymembers",
            "gcmtitle": "Category:\(category)",
            "gcmtype": "file",
            "gcmlimit": "40",
        ])
        return pages.compactMap { galleryPhoto(from: $0) }
    }

    /// The article's Commons category, from its Wikidata item (property P373).
    private func commonsCategory(title: String) async -> String? {
        // 1. Article title → Wikidata item ID, e.g. "Q864789"
        guard let itemURL = apiURL(host: "en.wikipedia.org", [
                "action": "query", "format": "json", "formatversion": "2", "redirects": "1",
                "prop": "pageprops", "ppprop": "wikibase_item", "titles": title,
              ]),
              let itemResponse: PagePropsResponse = await get(itemURL),
              let itemID = itemResponse.query?.pages.first?.pageprops?.wikibase_item
        else { return nil }

        // 2. Wikidata item → its "Commons category" value
        guard let claimsURL = apiURL(host: "www.wikidata.org", [
                "action": "wbgetclaims", "format": "json", "entity": itemID, "property": "P373",
              ]),
              let claims: ClaimsResponse = await get(claimsURL)
        else { return nil }
        return claims.claims?["P373"]?.first?.mainsnak.datavalue?.value
    }

    /// Runs an image query on Wikipedia or Commons and returns the file pages with their details.
    private func imagePages(host: String, extra: [String: String]) async -> [ImageQueryResponse.Page] {
        var parameters = [
            "action": "query", "format": "json", "formatversion": "2",
            "prop": "imageinfo",
            "iiprop": "url|mime|size|extmetadata",
            "iiurlwidth": "500",   // a standard Wikimedia thumbnail size, sharp enough for the strip
            "iiextmetadatafilter": "Artist|LicenseShortName|NonFree",
        ]
        parameters.merge(extra) { _, new in new }
        guard let url = apiURL(host: host, parameters),
              let response: ImageQueryResponse = await get(url)
        else { return [] }
        return response.query?.pages ?? []
    }

    /// A gallery photo from a file page, or nil for anything that isn't a free photograph.
    private func galleryPhoto(from page: ImageQueryResponse.Page) -> WikiGalleryPhoto? {
        guard let info = page.imageinfo?.first,
              let mime = info.mime, Self.photoTypes.contains(mime),
              // Tiny files are usually icons or badges
              (info.width ?? 0) >= 400, (info.height ?? 0) >= 300,
              !isLogoMapOrIcon(page.title),
              info.extmetadata?["NonFree"]?.value != "true",
              let thumbnailText = info.thumburl, let thumbnail = URL(string: thumbnailText),
              let original = info.url.flatMap(URL.init),
              let license = info.extmetadata?["LicenseShortName"]?.value, !license.isEmpty
        else { return nil }

        // Thumbnail URLs end in "/500px-Name.jpg"; Wikimedia makes the 1280 px size from the same
        // URL. Smaller originals are used as they are (Wikimedia won't make a thumbnail bigger than the file).
        let large = (info.width ?? 0) > 1280
            ? URL(string: thumbnailText.replacingOccurrences(of: "/500px-", with: "/1280px-")) ?? original
            : original

        // Artist is HTML (often a link to the photographer's user page): keep the text
        let artist = plainText(info.extmetadata?["Artist"]?.value ?? "")

        return WikiGalleryPhoto(
            id: page.title,
            thumbnailURL: thumbnail,
            largeURL: large,
            pageURL: info.descriptionurl.flatMap(URL.init),
            artist: artist.isEmpty ? "Wikimedia Commons" : artist,
            license: license
        )
    }

    private static let photoTypes: Set<String> = ["image/jpeg", "image/png", "image/webp"]

    /// File names that point to a logo, map, flag, icon or drawing rather than a photo
    private func isLogoMapOrIcon(_ fileTitle: String) -> Bool {
        let name = fileTitle.lowercased()
        let words = ["logo", "map", "icon", "flag", "seal", "coat of arms", "emblem",
                     "symbol", "diagram", "floor plan", "site plan", "locator", "signature"]
        return words.contains { name.contains($0) }
    }

    // "<a href=\"…\">Ziko</a>" → "Ziko"
    private func plainText(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = ["&amp;": "&", "&quot;": "\"", "&#039;": "'", "&#39;": "'", "&nbsp;": " ", "&lt;": "<", "&gt;": ">"]
        for (entity, character) in entities {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        // Credits sometimes spread over several lines in the HTML
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Some pages hold the name twice ("Unknown authorUnknown author"): keep one copy
        let half = text.count / 2
        if half > 0, text.count.isMultiple(of: 2), text.prefix(half) == text.suffix(half) {
            text = String(text.prefix(half))
        }
        return text
    }

    private func apiURL(host: String, _ parameters: [String: String]) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/w/api.php"
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        return components.url
    }

    private func get<Response: Decodable>(_ url: URL) async -> Response? {
        var request = URLRequest(url: url)
        // Wikimedia asks apps to identify themselves
        request.setValue("Stamped-A-City-Passport/2.3 (iOS)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return try? JSONDecoder().decode(Response.self, from: data)
    }
}

// MARK: - Decodable response shapes

nonisolated private struct ImageQueryResponse: Decodable {
    let query: Query?

    struct Query: Decodable {
        let pages: [Page]
    }
    struct Page: Decodable {
        let title: String
        /// "shared" for a Commons file seen from Wikipedia, "local" for a file on the site itself
        let imagerepository: String?
        let imageinfo: [ImageInfo]?
    }
    struct ImageInfo: Decodable {
        let url: String?
        let thumburl: String?
        let descriptionurl: String?
        let mime: String?
        let width: Int?
        let height: Int?
        let extmetadata: [String: MetadataValue]?
    }
    struct MetadataValue: Decodable {
        let value: String?

        // A few metadata values are numbers rather than text; treat those as missing
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try? container.decode(String.self, forKey: .value)
        }
        private enum CodingKeys: String, CodingKey { case value }
    }
}

nonisolated private struct PagePropsResponse: Decodable {
    let query: Query?

    struct Query: Decodable {
        let pages: [Page]
    }
    struct Page: Decodable {
        let pageprops: PageProps?
    }
    struct PageProps: Decodable {
        let wikibase_item: String?
    }
}

nonisolated private struct ClaimsResponse: Decodable {
    let claims: [String: [Claim]]?

    struct Claim: Decodable {
        let mainsnak: Snak
    }
    struct Snak: Decodable {
        let datavalue: DataValue?
    }
    struct DataValue: Decodable {
        let value: String?
    }
}
