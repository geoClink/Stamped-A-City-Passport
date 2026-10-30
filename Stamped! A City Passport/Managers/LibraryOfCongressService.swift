//
//  LibraryOfCongressService.swift
//  Stamped! A City Passport
//
//  Historic photos and measured drawings of US landmarks from the Library of
//  Congress: the Historic American Buildings Survey and Engineering Record
//  (HABS/HAER). Free JSON API, no key. US-government survey work, so the images
//  generally have no known restrictions; each one is credited and linked.
//
//  Matching is strict on purpose: a survey is used only when its title names the
//  building and it is in the same city and state. Showing nothing is better than
//  showing a different building's photos.
//

import Foundation

// MARK: - Result model

nonisolated struct HistoricImage: Identifiable, Hashable, Sendable {
    let thumbnailURL: URL
    let largeURL: URL
    /// The survey's own caption ("View from southeast"), when it has one
    let caption: String?
    /// A measured drawing (plan, elevation, section) rather than a photo
    let isDrawing: Bool
    /// "Library of Congress, HABS MO-1140"
    let credit: String
    /// The survey's page on loc.gov
    let itemURL: URL

    var id: URL { largeURL }
}

// MARK: - Service

actor LibraryOfCongressService {
    static let shared = LibraryOfCongressService()

    /// The most images a building page shows
    static let maxImages = 6

    // In-memory cache: building ID → images (empty when the survey has nothing that matches)
    private var cache: [String: [HistoricImage]] = [:]

    private init() {}

    /// Historic images for a US landmark, or none. HABS/HAER only covers the United
    /// States, so callers check the country first (see `HistoricPhotosSection`).
    /// `cityName` is the fallback town when the address can't be read.
    func images(buildingID: String, name: String, address: String, cityName: String) async -> [HistoricImage] {
        if let cached = cache[buildingID] { return cached }

        // A network failure returns nil and isn't cached, so the next visit tries again
        guard let surveys = await surveyIDs(buildingID: buildingID, name: name, address: address, cityName: cityName) else {
            return []
        }

        var result: [HistoricImage] = []
        var failed = false
        for surveyID in surveys where result.count < Self.maxImages {
            guard let found = await images(inSurvey: surveyID) else {
                failed = true
                break
            }
            result += found
        }
        result = Array(result.prefix(Self.maxImages))
        if !failed { cache[buildingID] = result }
        return result
    }

    // MARK: - Finding the survey

    /// The surveys (loc.gov item IDs such as "mo0297") that document this building, best first.
    /// Nil when the search itself failed.
    private func surveyIDs(buildingID: String, name: String, address: String, cityName: String) async -> [String]? {
        if let known = Self.surveyOverrides[buildingID] { return known }

        // "705 Chestnut St, St. Louis, MO 63101" → St. Louis, MO. Campuses use their town.
        let place = Self.cityAndState(from: address)
        let town = place?.city ?? cityName
        let searchName = Self.removingParenthetical(name)

        var components = URLComponents(string: "https://www.loc.gov/collections/historic-american-buildings-landscapes-and-engineering-records/")
        components?.queryItems = [
            URLQueryItem(name: "q", value: "\(searchName) \(town)"),
            URLQueryItem(name: "fo", value: "json"),
            URLQueryItem(name: "c", value: "25"),
        ]
        guard let url = components?.url,
              let response: LoCSearchResponse = await fetch(url)
        else { return nil }

        // The names a survey title may use for this building. "St. Louis Union Station"
        // may be catalogued as plain "Union Station" in Saint Louis.
        var names: Set<String> = [Self.normalized(name)]
        let normalizedTown = Self.normalized(town)
        let normalizedName = Self.normalized(searchName)
        if normalizedName.hasPrefix(normalizedTown + " ") {
            names.insert(String(normalizedName.dropFirst(normalizedTown.count + 1)))
        }

        let matches = (response.results ?? []).enumerated().filter { _, result in
            Self.isMatch(result, names: names, town: normalizedTown, state: place?.state)
        }
        // The fewer parts a title has, the more likely it's the whole building rather than
        // one room of it ("U.S. Capitol, Old Senate Chamber, ..."). Ties keep search order.
        let ranked = matches.sorted { lhs, rhs in
            let lhsParts = lhs.element.titleParts.count
            let rhsParts = rhs.element.titleParts.count
            return lhsParts == rhsParts ? lhs.offset < rhs.offset : lhsParts < rhsParts
        }
        return ranked.prefix(2).compactMap { $0.element.surveyID }
    }

    /// True when a search result is this building: the title names it (as one of its
    /// comma-separated parts, so "Bellefontaine Cemetery, Wainwright Tomb" doesn't count as
    /// the Wainwright Building), ends in the same state, and is in the same town.
    nonisolated private static func isMatch(_ result: LoCSearchResult, names: Set<String>, town: String, state: String?) -> Bool {
        let parts = result.titleParts
        guard result.surveyID != nil, result.accessRestricted != true, parts.count >= 2 else { return false }

        // Titles end in the state's postal code: "..., Saint Louis, Independent City, MO"
        if let state, parts.last != state { return false }

        // Every part but the state: "Rookery Building" also matches "The Rookery"
        let nameMatches = parts.dropLast().contains { part in
            let normalizedPart = normalized(part)
            return names.contains(normalizedPart)
                || names.contains { normalizedPart == $0 + " building" || $0 == normalizedPart + " building" }
        }
        guard nameMatches else { return false }

        let places = (result.location ?? []).map(normalized) + parts.map(normalized)
        return places.contains(town)
    }

    // MARK: - Reading a survey

    /// Up to `maxImages` photos and drawings from one survey. Nil when the request failed;
    /// empty when the survey has no images or its rights text isn't "no known restrictions".
    private func images(inSurvey surveyID: String) async -> [HistoricImage]? {
        guard let url = URL(string: "https://www.loc.gov/item/\(surveyID)/?fo=json"),
              let response: LoCItemResponse = await fetch(url)
        else { return nil }

        let item = response.item
        let rights = (item?.rightsAdvisory?.text ?? "").lowercased()
        guard rights.contains("no known restrictions"),
              let itemURL = URL(string: "https://www.loc.gov/item/\(surveyID)/")
        else { return [] }

        let credit = Self.credit(notes: item?.notes ?? [], callNumber: item?.callNumber?.text)
        let title = item?.title?.text ?? ""

        var photos: [HistoricImage] = []
        var drawings: [HistoricImage] = []
        for resource in response.resources ?? [] {
            for group in resource.files ?? [] {
                // Each group is one picture in several sizes (150 px, 640 px, 1024 px, TIFF)
                let jpegs = group.filter { ($0.mimetype ?? "").hasPrefix("image/jp") && $0.url != nil }
                guard let largest = jpegs.max(by: { $0.longestSide < $1.longestSide }),
                      let largeURL = largest.url.flatMap(URL.init)
                else { continue }
                // The 640 px size is sharp enough for a thumbnail and much lighter than 1024
                let thumbnail = jpegs.filter { $0.longestSide <= 640 }.max(by: { $0.longestSide < $1.longestSide }) ?? largest
                let isDrawing = largest.type == "drawing"
                let captionText = group.first(where: { $0.use == "caption" })?.title

                let image = HistoricImage(
                    thumbnailURL: thumbnail.url.flatMap(URL.init) ?? largeURL,
                    largeURL: largeURL,
                    caption: captionText.flatMap { Self.cleanedCaption($0, surveyTitle: title) },
                    isDrawing: isDrawing,
                    credit: credit,
                    itemURL: itemURL
                )
                if isDrawing { drawings.append(image) } else { photos.append(image) }
            }
        }

        // Mostly photos, with up to two drawings when the survey has them
        let drawingCount = min(drawings.count, 2)
        let picked = photos.prefix(Self.maxImages - drawingCount) + drawings.prefix(Self.maxImages)
        return Array(picked.prefix(Self.maxImages))
    }

    // MARK: - Helpers

    private func fetch<T: Decodable>(_ url: URL) async -> T? {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Stamped-A-City-Passport/2.7 (iOS)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }

    /// "Library of Congress, HABS MO-1140", from the survey number in the notes, or the
    /// call number ("HABS MO,96-SALU,49-") when there's no survey number.
    nonisolated private static func credit(notes: [String], callNumber: String?) -> String {
        let surveyNote = notes.first { $0.hasPrefix("Survey number:") }
        let survey = surveyNote.map { $0.dropFirst("Survey number:".count).trimmingCharacters(in: .whitespaces) }
        guard let reference = survey ?? callNumber?.trimmingCharacters(in: .whitespaces), !reference.isEmpty else {
            return "Library of Congress, HABS/HAER"
        }
        return "Library of Congress, \(reference)"
    }

    /// "85. VIEW FROM SOUTHEAST - Wainwright Building, Seventh & ..." → "View from southeast"
    nonisolated private static func cleanedCaption(_ caption: String, surveyTitle: String) -> String? {
        var text = caption
        if !surveyTitle.isEmpty, let range = text.range(of: " - " + surveyTitle) {
            text = String(text[..<range.lowerBound])
        }
        // Drop the photo number at the start ("85. ")
        if let range = text.range(of: #"^\s*\d+[A-Za-z]?\.\s*"#, options: .regularExpression) {
            text.removeSubrange(range)
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        // Older captions are all capitals; read them as a sentence
        if text == text.uppercased() {
            text = text.prefix(1).uppercased() + text.dropFirst().lowercased()
        }
        return text
    }

    /// The town and state code from a US address, e.g. ("St. Louis", "MO").
    nonisolated static func cityAndState(from address: String) -> (city: String, state: String)? {
        let parts = address.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for index in parts.indices.dropFirst() {
            // "MO 63101" or just "MO"
            if parts[index].range(of: #"^[A-Z]{2}( \d{5}(-\d{4})?)?$"#, options: .regularExpression) != nil {
                return (parts[index - 1], String(parts[index].prefix(2)))
            }
        }
        return nil
    }

    /// Lowercase words without accents, punctuation or "the", so "The U.S. Capitol" and
    /// "U.S. Capitol" compare equal. "Saint" becomes "st" and "United States" becomes "us".
    nonisolated static func normalized(_ text: String) -> String {
        var folded = removingParenthetical(text)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
        // Dots and apostrophes join letters: "U.S." → "us", "Carr's" → "carrs"
        for mark in [".", "'", "\u{2019}", "\u{02BB}"] {
            folded = folded.replacingOccurrences(of: mark, with: "")
        }
        let words = folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0 != "the" }
            .map { $0 == "saint" ? "st" : $0 }
        return words.joined(separator: " ").replacingOccurrences(of: "united states", with: "us")
    }

    // "Library of Congress (Jefferson Building)" → "Library of Congress"
    nonisolated static func removingParenthetical(_ name: String) -> String {
        guard let open = name.firstIndex(of: "(") else { return name }
        return String(name[..<open]).trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Survey overrides

extension LibraryOfCongressService {
    /// Building ID → loc.gov survey IDs, for landmarks HABS catalogues under another
    /// name (often the original one) or another town. Each was checked by hand: same
    /// building, same address.
    nonisolated static let surveyOverrides: [String: [String]] = [
        "bos-04": ["ma1403"],                       // Old State House: "Old Massachusetts State House"
        "bos-06": ["ma1359"],                       // Trinity Church: "Trinity Episcopal Church, Copley Square"
        "buf_guaranty_building": ["ny0204"],        // Guaranty Building: "Prudential Building", 28 Church St
        "campus_uchicago_robie_house": ["il0039"],  // Robie House: "Frederick C. Robie House"
        "chi-08": ["il0067"],                       // Carson Pirie Scott: "Schlesinger & Mayer Department Store"
        "dc-01": ["dc0253"],                        // U.S. Capitol (the whole building, not one room)
        "detroit_guardian": ["mi0024"],             // Guardian Building: "Union Trust Building", 500 Griswold St
        "nsh_ryman_auditorium": ["tn0030"],         // Ryman Auditorium: "Union Gospel Tabernacle"
        "pdx_pioneer_courthouse": ["or0030"],       // Pioneer Courthouse: "Pioneer Post Office", 700 SW Sixth Ave
        "pit-04": ["pa1690"],                       // Fallingwater: catalogued under Ohiopyle, not Mill Run
    ]
}

// MARK: - API response types
//
// loc.gov warns its data can be incomplete or oddly typed, so every field is optional
// and decoded with try?: one bad field shouldn't throw away a whole survey.

/// A search of the HABS/HAER collection: https://www.loc.gov/collections/.../?q=...&fo=json
nonisolated private struct LoCSearchResponse: Decodable {
    let results: [LoCSearchResult]?

    enum CodingKeys: String, CodingKey { case results }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try? container.decode([LoCSearchResult].self, forKey: .results)
    }
}

nonisolated private struct LoCSearchResult: Decodable {
    let title: String?
    /// "https://www.loc.gov/item/mo0297/" for surveys; essays and other pages have other URLs
    let url: String?
    /// Lowercase place names: ["independent city", "saint louis", "missouri"]
    let location: [String]?
    let accessRestricted: Bool?

    enum CodingKeys: String, CodingKey {
        case title, url, location
        case accessRestricted = "access_restricted"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try? container.decode(String.self, forKey: .title)
        url = try? container.decode(String.self, forKey: .url)
        location = try? container.decode([String].self, forKey: .location)
        accessRestricted = try? container.decode(Bool.self, forKey: .accessRestricted)
    }

    var titleParts: [String] {
        (title ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// "mo0297", or nil when the result isn't a survey item
    var surveyID: String? {
        guard let url, let range = url.range(of: "/item/") else { return nil }
        let id = url[range.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return id.isEmpty ? nil : id
    }
}

/// One survey: https://www.loc.gov/item/mo0297/?fo=json
nonisolated private struct LoCItemResponse: Decodable {
    let item: LoCItem?
    /// "Photos from Survey HABS MO-1140", "Drawings from Survey ...", data pages
    let resources: [LoCResource]?

    enum CodingKeys: String, CodingKey { case item, resources }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        item = try? container.decode(LoCItem.self, forKey: .item)
        resources = try? container.decode([LoCResource].self, forKey: .resources)
    }
}

nonisolated private struct LoCItem: Decodable {
    let title: LoCText?
    let callNumber: LoCText?
    let rightsAdvisory: LoCText?
    /// Includes "Survey number: HABS MO-1140"
    let notes: [String]?

    enum CodingKeys: String, CodingKey {
        case title, notes
        case callNumber = "call_number"
        case rightsAdvisory = "rights_advisory"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try? container.decode(LoCText.self, forKey: .title)
        callNumber = try? container.decode(LoCText.self, forKey: .callNumber)
        rightsAdvisory = try? container.decode(LoCText.self, forKey: .rightsAdvisory)
        notes = try? container.decode([String].self, forKey: .notes)
    }
}

nonisolated private struct LoCResource: Decodable {
    /// One inner list per picture: its sizes, plus its caption
    let files: [[LoCFile]]?

    enum CodingKeys: String, CodingKey { case files }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        files = try? container.decode([[LoCFile]].self, forKey: .files)
    }
}

/// One size of one picture, or the picture's caption (use == "caption").
nonisolated private struct LoCFile: Decodable {
    let url: String?
    let mimetype: String?
    /// "colorphoto", "bw_photos", "drawing"
    let type: String?
    let width: Int?
    let height: Int?
    let use: String?
    let title: String?

    var longestSide: Int { max(width ?? 0, height ?? 0) }

    enum CodingKeys: String, CodingKey {
        case url, mimetype, type, width, height, use, title
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try? container.decode(String.self, forKey: .url)
        mimetype = try? container.decode(String.self, forKey: .mimetype)
        type = try? container.decode(String.self, forKey: .type)
        width = try? container.decode(Int.self, forKey: .width)
        height = try? container.decode(Int.self, forKey: .height)
        use = try? container.decode(String.self, forKey: .use)
        title = try? container.decode(String.self, forKey: .title)
    }
}

/// A text field that loc.gov sends as a string on some items and a list of strings on others.
nonisolated private struct LoCText: Decodable {
    let text: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let single = try? container.decode(String.self) {
            text = single
        } else {
            text = ((try? container.decode([String].self)) ?? []).joined(separator: " ")
        }
    }
}
