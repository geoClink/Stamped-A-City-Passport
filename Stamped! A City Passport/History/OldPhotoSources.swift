//
//  OldPhotoSources.swift
//  Stamped! A City Passport
//
//  Old photos of a landmark from every archive the app can use, best first:
//  1. Library of Congress building surveys (US only, no key)
//  2. Wikimedia Commons (anywhere, no key; see HeritageService)
//  3. Europeana (Europe's museums and libraries; key in Secrets.plist)
//  4. Smithsonian Open Access (CC0; key in Secrets.plist)
//  5. Digital Public Library of America (US libraries and museums; key in Secrets.plist)
//  Only openly licensed photos: public domain, CC0, CC BY or CC BY-SA, each credited.
//  A photo is used only when its title names the landmark.
//

import Foundation

enum OldPhotoSources {
    /// Photos dated this year or later aren't "old"
    nonisolated static let oldBefore = 1960

    /// The most photos a landmark's gallery shows
    nonisolated static let maxGalleryPhotos = 12

    /// The first archive that has something: enough for a slideshow or a photo on the map
    static func photos(for building: Building, cityName: String) async -> [HistoricImage] {
        if LibraryOfCongressService.cityAndState(from: building.address) != nil {
            let survey = await LibraryOfCongressService.shared.images(
                buildingID: building.id, name: building.name,
                address: building.address, cityName: cityName).filter { !$0.isDrawing }
            if !survey.isEmpty { return survey }
        }
        let commons = await HeritageService.shared.oldPhotos(for: building)
        if !commons.isEmpty { return commons }
        let europeana = await ArchiveSearch.shared.europeana(name: building.name, city: cityName)
        if !europeana.isEmpty { return europeana }
        let smithsonian = await ArchiveSearch.shared.smithsonian(name: building.name, city: cityName)
        if !smithsonian.isEmpty { return smithsonian }
        return await ArchiveSearch.shared.dpla(name: building.name, city: cityName)
    }

    /// Every archive at once, for a landmark's gallery. The Library of Congress only covers
    /// the US: `inUnitedStates` says so when the caller knows, else the address decides.
    /// Its measured drawings are included when `includingDrawings`.
    static func gallery(for building: Building, cityName: String, inUnitedStates: Bool? = nil,
                        includingDrawings: Bool = true) async -> [HistoricImage] {
        let searchSurveys = inUnitedStates ?? (LibraryOfCongressService.cityAndState(from: building.address) != nil)
        async let survey = searchSurveys
            ? LibraryOfCongressService.shared.images(buildingID: building.id, name: building.name,
                                                     address: building.address, cityName: cityName)
            : []
        async let commons = HeritageService.shared.oldPhotos(for: building)
        async let europeana = ArchiveSearch.shared.europeana(name: building.name, city: cityName)
        async let smithsonian = ArchiveSearch.shared.smithsonian(name: building.name, city: cityName)
        async let dpla = ArchiveSearch.shared.dpla(name: building.name, city: cityName)
        let surveyImages = await survey.filter { includingDrawings || !$0.isDrawing }
        return await merged([surveyImages, commons, europeana, smithsonian, dpla])
    }

    /// The lists in order, each photo once, up to the gallery's limit
    nonisolated static func merged(_ lists: [[HistoricImage]], limit: Int = maxGalleryPhotos) -> [HistoricImage] {
        var seen = Set<URL>()
        return Array(lists.joined().filter { seen.insert($0.largeURL).inserted }.prefix(limit))
    }

    /// Photos that need no author credit next to them (public domain, CC0, US-government
    /// surveys). Reads the credit's parts one by one: an author or museum whose name merely
    /// contains "Public Domain" or "Library of Congress" doesn't free a CC BY photo.
    nonisolated static func needsNoCredit(_ image: HistoricImage) -> Bool {
        let parts = image.credit.components(separatedBy: " · ").map { $0.lowercased() }
        if parts.contains(where: { $0.hasPrefix("cc by") || $0.hasPrefix("cc-by") }) { return false }
        return image.credit.hasPrefix("Library of Congress, ")
            || parts.contains { $0 == "public domain" || $0 == "cc0" || $0.hasPrefix("cc0 ") }
    }
}

actor ArchiveSearch {
    static let shared = ArchiveSearch()
    nonisolated static let maxPhotos = 6

    private var europeanaCache: [String: [HistoricImage]] = [:]
    private var smithsonianCache: [String: [HistoricImage]] = [:]
    private var dplaCache: [String: [HistoricImage]] = [:]

    // MARK: Europeana

    func europeana(name: String, city: String) async -> [HistoricImage] {
        guard let key = Secrets.europeanaKey else { return [] }
        let cacheKey = "\(name)|\(city)"
        if let cached = europeanaCache[cacheKey] { return cached }

        let quotedName = name.replacingOccurrences(of: "\"", with: "")
        // Short names ("City Hall") need the city too, or they match every city's
        let query = !Self.nameIsAmbiguous(quotedName)
            ? "title:\"\(quotedName)\""
            : "title:\"\(quotedName)\" AND \"\(city.replacingOccurrences(of: "\"", with: ""))\""
        var components = URLComponents(string: "https://api.europeana.eu/record/v2/search.json")!
        components.queryItems = [
            URLQueryItem(name: "wskey", value: key),
            URLQueryItem(name: "query", value: query),
            // "open" = public domain, CC0, CC BY, CC BY-SA: fine for an app that earns money
            URLQueryItem(name: "reusability", value: "open"),
            URLQueryItem(name: "media", value: "true"),
            URLQueryItem(name: "qf", value: "TYPE:IMAGE"),
            URLQueryItem(name: "qf", value: "YEAR:[1800 TO \(OldPhotoSources.oldBefore - 1)]"),
            URLQueryItem(name: "rows", value: "20"),
        ]
        guard let url = components.url, let data = await get(url) else { return [] }
        let photos = Self.europeanaPhotos(from: data, name: name)
        europeanaCache[cacheKey] = photos
        return photos
    }

    /// The openly licensed photos in a Europeana search result whose titles name the landmark
    nonisolated static func europeanaPhotos(from data: Data, name: String) -> [HistoricImage] {
        guard let response = try? JSONDecoder().decode(EuropeanaResponse.self, from: data) else { return [] }
        var photos: [HistoricImage] = []
        for item in response.items ?? [] where photos.count < Self.maxPhotos {
            guard item.title?.contains(where: { names($0, landmark: name) }) == true else { continue }
            // Europeana's preview is always https; many original links are plain http,
            // which the app can't load, so those fall back to the preview
            let preview = item.edmPreview?.first.flatMap(URL.init)
            let original = item.edmIsShownBy?.first.flatMap(URL.init).flatMap { $0.scheme == "https" ? $0 : nil }
            guard let full = original ?? preview, let thumb = preview ?? original,
                  let rights = item.rights?.first, let licence = Self.licence(fromRightsURL: rights),
                  let page = item.guid.flatMap(URL.init)
            else { continue }
            let credit = [item.dcCreator?.first, item.dataProvider?.first, licence, "Europeana"]
                .compactMap { $0 }.joined(separator: " · ")
            photos.append(HistoricImage(thumbnailURL: thumb, largeURL: full, caption: item.title?.first,
                                        isDrawing: false, credit: credit, itemURL: page))
        }
        return photos
    }

    /// True when a record's title has the landmark's name in it, ignoring case and accents
    nonisolated static func names(_ title: String, landmark: String) -> Bool {
        title.range(of: landmark, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    /// Names that are short ("The Met") or only everyday words ("Union Station", "City Hall")
    /// are shared by many cities
    nonisolated static func nameIsAmbiguous(_ name: String) -> Bool {
        name.count < 12 || name.lowercased().split { !$0.isLetter }.allSatisfy(commonNameWords.contains)
    }

    nonisolated private static let commonNameWords: Set<Substring> = [
        "the", "of", "and", "old", "new", "grand", "great", "first", "main", "central", "union", "city", "town",
        "state", "national", "public", "royal", "hall", "house", "station", "terminal", "post", "office", "court",
        "courthouse", "capitol", "library", "museum", "art", "theatre", "theater", "opera", "cathedral", "church",
        "bridge", "tower", "park", "square", "market", "hotel", "building", "university", "stadium",
    ]

    /// A short licence name for the credit, or nil for anything not openly licensed
    nonisolated static func licence(fromRightsURL url: String) -> String? {
        let lower = url.lowercased()
        guard lower.contains("creativecommons.org/") else { return nil }
        if lower.contains("/nc") || lower.contains("-nc") || lower.contains("/nd") || lower.contains("-nd") { return nil }
        if lower.contains("publicdomain/mark") { return "Public domain" }
        if lower.contains("publicdomain/zero") { return "CC0" }
        if lower.contains("licenses/by-sa") { return "CC BY-SA" }
        if lower.contains("licenses/by/") { return "CC BY" }
        return nil
    }

    // MARK: Smithsonian

    func smithsonian(name: String, city: String) async -> [HistoricImage] {
        guard let key = Secrets.smithsonianKey else { return [] }
        let cacheKey = "\(name)|\(city)"
        if let cached = smithsonianCache[cacheKey] { return cached }

        let quotedName = name.replacingOccurrences(of: "\"", with: "")
        var components = URLComponents(string: "https://api.si.edu/openaccess/api/v1.0/search")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: key),
            URLQueryItem(name: "q", value: "\"\(quotedName)\" AND online_media_type:\"Images\" AND type:edanmdm"),
            URLQueryItem(name: "rows", value: "30"),
        ]
        guard let url = components.url, let data = await get(url) else { return [] }
        let photos = Self.smithsonianPhotos(from: data, name: name, city: city)
        smithsonianCache[cacheKey] = photos
        return photos
    }

    /// The CC0 photos in a Smithsonian search result that are of this landmark
    nonisolated static func smithsonianPhotos(from data: Data, name: String, city: String) -> [HistoricImage] {
        guard let response = try? JSONDecoder().decode(SmithsonianResponse.self, from: data) else { return [] }
        var photos: [HistoricImage] = []
        for row in response.response.rows where photos.count < Self.maxPhotos {
            // The record must be about this landmark, and old when it's dated.
            // A short name must come with the city, or it's another city's "Union Station".
            guard names(row.title, landmark: name),
                  !nameIsAmbiguous(name) || names(row.title, landmark: city) else { continue }
            let decades = row.content.indexedStructured?.date ?? []
            if let decade = decades.compactMap({ Int($0.prefix(4)) }).min(), decade >= OldPhotoSources.oldBefore { continue }
            let descriptive = row.content.descriptiveNonRepeating
            guard let media = descriptive?.online_media?.media.first(where: { $0.usage?.access == "CC0" && $0.type == "Images" }),
                  let full = media.content.flatMap(URL.init),
                  let page = descriptive?.record_link.flatMap(URL.init)
            else { continue }
            let credit = [descriptive?.data_source, "Smithsonian Institution", "CC0"]
                .compactMap { $0 }.joined(separator: " · ")
            photos.append(HistoricImage(thumbnailURL: media.thumbnail.flatMap(URL.init) ?? full, largeURL: full,
                                        caption: row.title, isDrawing: false, credit: credit, itemURL: page))
        }
        return photos
    }

    // MARK: Digital Public Library of America

    func dpla(name: String, city: String) async -> [HistoricImage] {
        guard let key = Secrets.dplaKey else { return [] }
        let cacheKey = "\(name)|\(city)"
        if let cached = dplaCache[cacheKey] { return cached }

        var components = URLComponents(string: "https://api.dp.la/v2/items")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: key),
            URLQueryItem(name: "sourceResource.title", value: "\"\(name.replacingOccurrences(of: "\"", with: ""))\""),
            URLQueryItem(name: "sourceResource.type", value: "image"),
            URLQueryItem(name: "page_size", value: "30"),
        ]
        guard let url = components.url, let data = await get(url) else { return [] }
        let photos = Self.dplaPhotos(from: data, name: name, city: city)
        dplaCache[cacheKey] = photos
        return photos
    }

    /// The openly licensed old photos in a DPLA result that are of this landmark. DPLA only
    /// holds thumbnails; the full picture stays on the library's own page, linked from the
    /// credit. An undated record is left out: it may not be old at all.
    nonisolated static func dplaPhotos(from data: Data, name: String, city: String) -> [HistoricImage] {
        guard let response = try? JSONDecoder().decode(DPLAResponse.self, from: data) else { return [] }
        var photos: [HistoricImage] = []
        for doc in response.docs ?? [] where photos.count < Self.maxPhotos {
            let source = doc.sourceResource
            guard let title = source?.title?.values.first(where: { names($0, landmark: name) }),
                  !nameIsAmbiguous(name) || names(title, landmark: city),
                  let date = source?.date?.displayDate, let year = HeritageService.year(in: date),
                  year < OldPhotoSources.oldBefore,
                  let rights = doc.rights?.values.first, let licence = Self.licence(fromRightsURL: rights),
                  let image = doc.object.flatMap(URL.init), image.scheme == "https",
                  let page = doc.isShownAt.flatMap(URL.init)
            else { continue }
            let author = source?.creator?.values.first
            // CC BY and CC BY-SA require the author's name
            if author == nil, licence.hasPrefix("CC BY") { continue }
            let credit = [author, doc.dataProvider?.name, licence, "DPLA"]
                .compactMap { $0 }.joined(separator: " · ")
            photos.append(HistoricImage(thumbnailURL: image, largeURL: image, caption: title,
                                        isDrawing: false, credit: credit, itemURL: page))
        }
        return photos
    }

    // MARK: Network

    private func get(_ url: URL) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Stamped-A-City-Passport/2.10", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return data
    }

    nonisolated private struct EuropeanaResponse: Decodable {
        struct Item: Decodable {
            let guid: String?
            let title: [String]?
            let edmIsShownBy: [String]?
            let edmPreview: [String]?
            let rights: [String]?
            let dataProvider: [String]?
            let dcCreator: [String]?
        }
        let items: [Item]?
    }

    nonisolated private struct DPLAResponse: Decodable {
        /// DPLA gives a field as one string or as a list, depending on the record
        struct Strings: Decodable {
            let values: [String]
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let one = try? container.decode(String.self) {
                    values = [one]
                } else {
                    values = (try? container.decode([String].self)) ?? []
                }
            }
        }
        /// The library, as a plain name or as {"name": ...}
        struct Provider: Decodable {
            let name: String?
            private enum CodingKeys: String, CodingKey { case name }
            init(from decoder: Decoder) throws {
                if let text = try? decoder.singleValueContainer().decode(String.self) {
                    name = text
                } else {
                    name = try? decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .name)
                }
            }
        }
        /// One date, or a list of them
        struct DateField: Decodable {
            struct One: Decodable { let displayDate: String? }
            let displayDate: String?
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let one = try? container.decode(One.self) {
                    displayDate = one.displayDate
                } else {
                    displayDate = (try? container.decode([One].self))?.first?.displayDate
                }
            }
        }
        struct Source: Decodable {
            let title: Strings?
            let creator: Strings?
            let date: DateField?
        }
        struct Doc: Decodable {
            let object: String?
            let isShownAt: String?
            let rights: Strings?
            let dataProvider: Provider?
            let sourceResource: Source?
        }
        let docs: [Doc]?
    }

    nonisolated private struct SmithsonianResponse: Decodable {
        struct Inner: Decodable { let rows: [Row] }
        struct Row: Decodable {
            let title: String
            let content: Content
        }
        struct Content: Decodable {
            let descriptiveNonRepeating: Descriptive?
            let indexedStructured: Indexed?
        }
        struct Descriptive: Decodable {
            let record_link: String?
            let data_source: String?
            let online_media: OnlineMedia?
        }
        struct OnlineMedia: Decodable { let media: [Media] }
        struct Media: Decodable {
            struct Usage: Decodable { let access: String? }
            let type: String?
            let content: String?
            let thumbnail: String?
            let usage: Usage?
        }
        struct Indexed: Decodable { let date: [String]? }
        let response: Inner
    }
}
