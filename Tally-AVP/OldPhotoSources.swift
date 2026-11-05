//
//  OldPhotoSources.swift
//  Tally-AVP
//
//  Old photos of a landmark from every archive the app can use, best first:
//  1. Library of Congress building surveys (US only, no key)
//  2. Wikimedia Commons (anywhere, no key; see HeritageService)
//  3. Europeana (Europe's museums and libraries; key in Secrets.plist)
//  4. Smithsonian Open Access (CC0; key in Secrets.plist)
//  Only openly licensed photos: public domain, CC0, CC BY or CC BY-SA, each credited.
//  A photo is used only when its title names the landmark.
//

import Foundation

enum OldPhotoSources {
    /// Photos dated this year or later aren't "old"
    nonisolated static let oldBefore = 1960

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
        return await ArchiveSearch.shared.smithsonian(name: building.name)
    }

    /// Photos that need no author credit next to them (public domain, CC0, US-government surveys)
    static func needsNoCredit(_ image: HistoricImage) -> Bool {
        image.credit.hasPrefix("Library of Congress")
            || image.credit.localizedCaseInsensitiveContains("public domain") || image.credit.contains("CC0")
    }
}

actor ArchiveSearch {
    static let shared = ArchiveSearch()
    static let maxPhotos = 6

    private var europeanaCache: [String: [HistoricImage]] = [:]
    private var smithsonianCache: [String: [HistoricImage]] = [:]

    // MARK: Europeana

    func europeana(name: String, city: String) async -> [HistoricImage] {
        guard let key = Secrets.europeanaKey else { return [] }
        let cacheKey = "\(name)|\(city)"
        if let cached = europeanaCache[cacheKey] { return cached }

        let quotedName = name.replacingOccurrences(of: "\"", with: "")
        // Short names ("City Hall") need the city too, or they match every city's
        let query = quotedName.count >= 12
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
        guard let url = components.url, let response: EuropeanaResponse = await get(url) else { return [] }

        var photos: [HistoricImage] = []
        for item in response.items ?? [] where photos.count < Self.maxPhotos {
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
        europeanaCache[cacheKey] = photos
        return photos
    }

    /// A short licence name for the credit, or nil for anything not openly licensed
    nonisolated static func licence(fromRightsURL url: String) -> String? {
        let lower = url.lowercased()
        if lower.contains("/nc") || lower.contains("-nc") || lower.contains("/nd") || lower.contains("-nd") { return nil }
        if lower.contains("publicdomain/mark") { return "Public domain" }
        if lower.contains("publicdomain/zero") { return "CC0" }
        if lower.contains("licenses/by-sa") { return "CC BY-SA" }
        if lower.contains("licenses/by/") { return "CC BY" }
        return nil
    }

    // MARK: Smithsonian

    func smithsonian(name: String) async -> [HistoricImage] {
        guard let key = Secrets.smithsonianKey else { return [] }
        if let cached = smithsonianCache[name] { return cached }

        let quotedName = name.replacingOccurrences(of: "\"", with: "")
        var components = URLComponents(string: "https://api.si.edu/openaccess/api/v1.0/search")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: key),
            URLQueryItem(name: "q", value: "\"\(quotedName)\" AND online_media_type:\"Images\" AND type:edanmdm"),
            URLQueryItem(name: "rows", value: "30"),
        ]
        guard let url = components.url, let response: SmithsonianResponse = await get(url) else { return [] }

        var photos: [HistoricImage] = []
        for row in response.response.rows where photos.count < Self.maxPhotos {
            // The record must be about this landmark, and old when it's dated
            guard row.title.localizedCaseInsensitiveContains(name) else { continue }
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
        smithsonianCache[name] = photos
        return photos
    }

    // MARK: Network

    private func get<Response: Decodable>(_ url: URL) async -> Response? {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Stamped-A-City-Passport/2.10 (visionOS)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return try? JSONDecoder().decode(Response.self, from: data)
    }

    private struct EuropeanaResponse: Decodable {
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

    private struct SmithsonianResponse: Decodable {
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
