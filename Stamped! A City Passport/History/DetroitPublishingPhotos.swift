//
//  DetroitPublishingPhotos.swift
//  Stamped! A City Passport
//
//  Photos and postcards of US cities from about 1880–1920, from the Library of Congress's
//  Detroit Publishing Company collection. The library marks them "No known restrictions on
//  publication": https://www.loc.gov/collections/detroit-publishing-company/
//

import Foundation

actor DetroitPublishingPhotos {
    static let shared = DetroitPublishingPhotos()

    /// The most photos one landmark gets from this collection
    nonisolated static let maxPhotos = 3
    nonisolated static let credit = "Library of Congress, Detroit Publishing Company Collection"

    // Building ID → photos (empty when nothing matched). Failed searches aren't cached.
    private var cache: [String: [HistoricImage]] = [:]

    private init() {}

    /// Old photos of a US landmark, or none. `cityName` is the fallback town when the
    /// address can't be read.
    func photos(buildingID: String, name: String, address: String, cityName: String) async -> [HistoricImage] {
        if let cached = cache[buildingID] { return cached }

        let town = LibraryOfCongressService.cityAndState(from: address)?.city ?? cityName
        let searchName = LibraryOfCongressService.removingParenthetical(name)
        var components = URLComponents(string: "https://www.loc.gov/collections/detroit-publishing-company/")
        components?.queryItems = [
            URLQueryItem(name: "q", value: "\(searchName) \(town)"),
            URLQueryItem(name: "fo", value: "json"),
            URLQueryItem(name: "c", value: "25"),
        ]
        guard let url = components?.url,
              let response: PublishingSearchResponse = await fetch(url)
        else { return [] }

        let photos = (response.results ?? [])
            .filter { Self.isMatch(title: $0.title ?? "", location: $0.location ?? [], name: searchName, town: town) }
            .filter { $0.accessRestricted != true }
            .compactMap(Self.image)
        let result = Array(photos.prefix(Self.maxPhotos))
        cache[buildingID] = result
        return result
    }

    /// True when a catalogue title is this landmark in this town. Titles look like
    /// "Penobscot Building, Detroit, Mich." or "[Detroit, Mich., Penobscot Building]".
    /// A one-word name ("Arcade") must be a whole part of the title, so "Euclid Arcade"
    /// doesn't count as "The Arcade".
    nonisolated static func isMatch(title: String, location: [String], name: String, town: String) -> Bool {
        let normalizedTown = LibraryOfCongressService.normalized(town)
        let parts = title.trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
            .split(separator: ",").map { LibraryOfCongressService.normalized(String($0)) }
        let inTown = location.map(LibraryOfCongressService.normalized).contains(normalizedTown)
            || parts.contains(normalizedTown)
        guard inTown else { return false }

        var names: Set<String> = [LibraryOfCongressService.normalized(name)]
        for name in names where name.hasSuffix(" building") { names.insert(String(name.dropLast(" building".count))) }
        // "Detroit Institute of Arts" may be catalogued without the town in front
        let townPrefix = normalizedTown + " "
        for name in names where name.hasPrefix(townPrefix) { names.insert(String(name.dropFirst(townPrefix.count))) }

        return parts.contains { part in
            names.contains { name in
                guard !name.isEmpty else { return false }
                if part == name || part == name + " building" { return true }
                // Several buildings in one title: "Dime, Penobscot and Ford buildings" doesn't
                // count; a longer name inside a part does: "new penobscot building"
                return name.contains(" ") && (" " + part + " ").contains(" " + name + " ")
            }
        }
    }

    /// The 640 px and 1024 px copies, with the title and year as the caption
    nonisolated private static func image(_ result: PublishingSearchResult) -> HistoricImage? {
        func side(_ url: String) -> Int {
            guard let range = url.range(of: #"w=(\d+)"#, options: .regularExpression) else { return 0 }
            return Int(url[range].dropFirst(2)) ?? 0
        }
        let jpegs = (result.imageURLs ?? []).filter { $0.contains(".jpg") }
        guard let large = jpegs.max(by: { side($0) < side($1) }),
              let largeURL = URL(string: large),
              let itemURL = result.url.flatMap(URL.init)
        else { return nil }
        let thumbnail = jpegs.filter { side($0) <= 640 }.max(by: { side($0) < side($1) }) ?? large

        var caption = (result.title ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
        if let year = result.date?.prefix(4), year.count == 4, Int(year) != nil {
            caption += caption.isEmpty ? "ca. \(year)" : ", ca. \(year)"
        }
        return HistoricImage(thumbnailURL: URL(string: thumbnail) ?? largeURL, largeURL: largeURL,
                             caption: caption.isEmpty ? nil : caption, isDrawing: false,
                             credit: credit, itemURL: itemURL)
    }

    private func fetch<T: Decodable>(_ url: URL) async -> T? {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Stamped-A-City-Passport/2.17 (iOS)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }
}

// Every field is optional and decoded with try?, as loc.gov's data can be oddly typed

nonisolated private struct PublishingSearchResponse: Decodable {
    let results: [PublishingSearchResult]?

    enum CodingKeys: String, CodingKey { case results }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try? container.decode([PublishingSearchResult].self, forKey: .results)
    }
}

nonisolated private struct PublishingSearchResult: Decodable {
    let title: String?
    let url: String?
    /// "1907-01-01"; the collection's dates are approximate
    let date: String?
    let location: [String]?
    let accessRestricted: Bool?
    /// 150 px, GIF, 640 px and 1024 px copies, each ending in "#h=…&w=…"
    let imageURLs: [String]?

    enum CodingKeys: String, CodingKey {
        case title, url, date, location
        case accessRestricted = "access_restricted"
        case imageURLs = "image_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try? container.decode(String.self, forKey: .title)
        url = try? container.decode(String.self, forKey: .url)
        date = try? container.decode(String.self, forKey: .date)
        location = try? container.decode([String].self, forKey: .location)
        accessRestricted = try? container.decode(Bool.self, forKey: .accessRestricted)
        imageURLs = try? container.decode([String].self, forKey: .imageURLs)
    }
}
