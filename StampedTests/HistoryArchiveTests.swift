//
//  HistoryArchiveTests.swift
//  StampedTests
//
//  Matching archive records to landmarks, from saved copies of each archive's replies:
//  the wrong building's photo, or one with the wrong licence, must never get through.
//

import XCTest
@testable import Stamped_

final class HistoryArchiveTests: XCTestCase {

    private func json(_ object: Any) throws -> Data { try JSONSerialization.data(withJSONObject: object) }

    private func image(_ name: String, credit: String = "Library of Congress, HABS X-1", isDrawing: Bool = false) -> HistoricImage {
        let url = URL(string: "https://example.org/\(name).jpg")!
        return HistoricImage(thumbnailURL: url, largeURL: url, caption: nil, isDrawing: isDrawing, credit: credit, itemURL: url)
    }

    // MARK: Europeana

    private func europeanaItem(title: String = "Eiffel Tower, Paris",
                               rights: String = "http://creativecommons.org/publicdomain/mark/1.0/",
                               preview: String? = "https://api.europeana.eu/thumbnail/a.jpg",
                               shownBy: String? = "https://museum.example/a.jpg",
                               creator: String? = "Jane Doe") -> [String: Any] {
        var item: [String: Any] = ["guid": "https://www.europeana.eu/item/1/a", "title": [title], "rights": [rights],
                                   "dataProvider": ["Musée"]]
        if let preview { item["edmPreview"] = [preview] }
        if let shownBy { item["edmIsShownBy"] = [shownBy] }
        if let creator { item["dcCreator"] = [creator] }
        return item
    }

    private func europeana(_ items: [[String: Any]], name: String = "Eiffel Tower") throws -> [HistoricImage] {
        ArchiveSearch.europeanaPhotos(from: try json(["items": items]), name: name)
    }

    func testEuropeanaCreditNamesAuthorMuseumLicenceAndSource() throws {
        let photos = try europeana([europeanaItem()])
        XCTAssertEqual(photos.first?.credit, "Jane Doe · Musée · Public domain · Europeana")
        XCTAssertEqual(photos.first?.largeURL.absoluteString, "https://museum.example/a.jpg")
    }

    func testEuropeanaDropsClosedLicences() throws {
        let photos = try europeana([
            europeanaItem(rights: "http://creativecommons.org/licenses/by-nc/4.0/"),
            europeanaItem(rights: "http://rightsstatements.org/vocab/InC/1.0/"),
        ])
        XCTAssertTrue(photos.isEmpty)
    }

    func testEuropeanaDropsTitlesThatDontNameTheLandmark() throws {
        let photos = try europeana([europeanaItem(title: "Tower of the Eiffel company offices")])
        XCTAssertTrue(photos.isEmpty)
    }

    func testEuropeanaTitleMatchIgnoresCaseAndAccents() throws {
        XCTAssertEqual(try europeana([europeanaItem(title: "LA SAGRADA FAMILIA, 1910")], name: "Sagrada Família").count, 1)
    }

    /// The app can't load plain http, so those originals fall back to Europeana's https preview
    func testEuropeanaUsesThePreviewForPlainHTTPOriginals() throws {
        let photo = try XCTUnwrap(try europeana([europeanaItem(shownBy: "http://museum.example/a.jpg")]).first)
        XCTAssertEqual(photo.largeURL.scheme, "https")
    }

    func testEuropeanaStopsAtTheLimitAndSurvivesBadData() throws {
        let many = (0..<20).map { europeanaItem(shownBy: "https://museum.example/\($0).jpg") }
        XCTAssertEqual(try europeana(many).count, ArchiveSearch.maxPhotos)
        XCTAssertTrue(ArchiveSearch.europeanaPhotos(from: Data("<html>".utf8), name: "x").isEmpty)
        XCTAssertTrue(try europeana([europeanaItem(preview: nil, shownBy: nil)]).isEmpty)
    }

    // MARK: Smithsonian

    private func smithsonianRow(title: String, access: String = "CC0", decades: [String]? = ["1920s"]) -> [String: Any] {
        var indexed: [String: Any] = [:]
        if let decades { indexed["date"] = decades }
        return ["title": title, "content": [
            "indexedStructured": indexed,
            "descriptiveNonRepeating": [
                "record_link": "https://si.edu/object/1", "data_source": "National Museum",
                "online_media": ["media": [["type": "Images", "content": "https://ids.si.edu/1", "thumbnail": "https://ids.si.edu/t1",
                                            "usage": ["access": access]]]],
            ],
        ]]
    }

    private func smithsonian(_ rows: [[String: Any]], name: String, city: String) throws -> [HistoricImage] {
        ArchiveSearch.smithsonianPhotos(from: try json(["response": ["rows": rows]]), name: name, city: city)
    }

    func testSmithsonianKeepsCC0RecordsOfTheLandmark() throws {
        let photos = try smithsonian([smithsonianRow(title: "Brooklyn Bridge at dusk")], name: "Brooklyn Bridge", city: "New York")
        XCTAssertEqual(photos.first?.credit, "National Museum · Smithsonian Institution · CC0")
    }

    func testSmithsonianDropsOtherLicencesTitlesAndNewPhotos() throws {
        XCTAssertTrue(try smithsonian([smithsonianRow(title: "Brooklyn Bridge", access: "Usage conditions apply")],
                                      name: "Brooklyn Bridge", city: "New York").isEmpty)
        XCTAssertTrue(try smithsonian([smithsonianRow(title: "Golden Gate Bridge")],
                                      name: "Brooklyn Bridge", city: "New York").isEmpty)
        XCTAssertTrue(try smithsonian([smithsonianRow(title: "Brooklyn Bridge", decades: ["1970s"])],
                                      name: "Brooklyn Bridge", city: "New York").isEmpty)
    }

    /// Every big city has a "Union Station": a short name must come with the city
    func testSmithsonianShortNamesNeedTheCity() throws {
        XCTAssertTrue(try smithsonian([smithsonianRow(title: "Union Station, Washington, D.C.")],
                                      name: "Union Station", city: "St. Louis").isEmpty)
        XCTAssertEqual(try smithsonian([smithsonianRow(title: "Union Station, St. Louis")],
                                       name: "Union Station", city: "St. Louis").count, 1)
    }

    // MARK: DPLA

    private func dplaDoc(title: Any = "Brooklyn Bridge, New York", date: Any = ["displayDate": "1910"],
                         rights: String = "http://creativecommons.org/publicdomain/mark/1.0/",
                         image: String = "https://dp.la/thumb/1.jpg", creator: Any? = nil,
                         provider: Any = ["name": "Boston Public Library"]) -> [String: Any] {
        var source: [String: Any] = ["title": title, "date": date]
        if let creator { source["creator"] = creator }
        return ["object": image, "isShownAt": "https://library.example/1", "rights": rights,
                "dataProvider": provider, "sourceResource": source]
    }

    private func dpla(_ docs: [[String: Any]], name: String = "Brooklyn Bridge", city: String = "New York") throws -> [HistoricImage] {
        ArchiveSearch.dplaPhotos(from: try json(["docs": docs]), name: name, city: city, inUnitedStates: false)
    }

    /// "No Copyright - United States" may not hold elsewhere, so only US devices show it
    func testDPLANoCopyrightUSIsForUSDevicesOnly() throws {
        let data = try json(["docs": [dplaDoc(rights: ArchiveSearch.noCopyrightUS)]])
        XCTAssertTrue(ArchiveSearch.dplaPhotos(from: data, name: "Brooklyn Bridge", city: "New York", inUnitedStates: false).isEmpty)
        let photo = try XCTUnwrap(ArchiveSearch.dplaPhotos(from: data, name: "Brooklyn Bridge", city: "New York", inUnitedStates: true).first)
        XCTAssertEqual(photo.credit, "Boston Public Library · No Copyright - United States · DPLA")
        // The label is about the US only, so its credit is never waived
        XCTAssertFalse(OldPhotoSources.needsNoCredit(photo))
        XCTAssertFalse(ArchiveSearch.dplaRights(inUnitedStates: false).contains(ArchiveSearch.noCopyrightUS))
        XCTAssertTrue(ArchiveSearch.dplaRights(inUnitedStates: true).contains(ArchiveSearch.noCopyrightUS))
    }

    func testDPLAKeepsOldOpenPhotosOfTheLandmark() throws {
        let photo = try XCTUnwrap(try dpla([dplaDoc()]).first)
        XCTAssertEqual(photo.credit, "Boston Public Library · Public domain · DPLA")
        XCTAssertEqual(photo.itemURL.absoluteString, "https://library.example/1")
    }

    /// DPLA fields come in more than one shape, depending on the library
    func testDPLAReadsListsAndPlainStrings() throws {
        let doc = dplaDoc(title: ["Other", "Brooklyn Bridge"], date: [["displayDate": "ca. 1905"]],
                          rights: "http://creativecommons.org/licenses/by/4.0/",
                          creator: ["Jane Doe"], provider: "A Library")
        XCTAssertEqual(try dpla([doc]).first?.credit, "Jane Doe · A Library · CC BY · DPLA")
    }

    func testDPLADropsClosedNewUndatedAndInsecure() throws {
        XCTAssertTrue(try dpla([
            dplaDoc(rights: "http://rightsstatements.org/vocab/InC/1.0/"),
            dplaDoc(rights: "http://rightsstatements.org/vocab/NoC-NC/1.0/"),
            dplaDoc(rights: "http://creativecommons.org/licenses/by-nc/4.0/"),
            dplaDoc(date: ["displayDate": "1975"]),
            dplaDoc(date: ["displayDate": "unknown"]),
            dplaDoc(image: "http://dp.la/thumb/1.jpg"),
            dplaDoc(title: "Golden Gate Bridge"),
        ]).isEmpty)
    }

    /// CC BY needs an author's name, and a short name needs the city
    func testDPLADropsUncreditableAndAmbiguous() throws {
        XCTAssertTrue(try dpla([dplaDoc(rights: "http://creativecommons.org/licenses/by/4.0/")]).isEmpty)
        XCTAssertTrue(try dpla([dplaDoc(title: "Union Station, Denver")], name: "Union Station", city: "St. Louis").isEmpty)
    }

    func testEverydayNamesAreAmbiguous() {
        for name in ["City Hall", "Union Station", "Old State House", "Grand Central Terminal", "The Met"] {
            XCTAssertTrue(ArchiveSearch.nameIsAmbiguous(name), name)
        }
        for name in ["Eiffel Tower", "Brooklyn Bridge", "Sagrada Família"] {
            XCTAssertFalse(ArchiveSearch.nameIsAmbiguous(name), name)
        }
    }

    // MARK: Commons

    private func commonsPage(date: String = "1931-05-01", licence: String = "CC BY-SA 4.0",
                             artist: String = "<a href=\"x\">Jane &amp; Co</a>", file: String = "a") -> [String: Any] {
        ["imageinfo": [[
            "url": "https://upload.wikimedia.org/\(file).jpg", "thumburl": "https://upload.wikimedia.org/t-\(file).jpg",
            "descriptionurl": "https://commons.wikimedia.org/wiki/File:\(file).jpg",
            "extmetadata": ["DateTimeOriginal": ["value": date], "LicenseShortName": ["value": licence],
                            "Artist": ["value": artist], "ImageDescription": ["value": "<b>View</b> north"]],
        ]]]
    }

    private func commons(_ pages: [[String: Any]]) throws -> [HistoricImage] {
        HeritageService.commonsPhotos(from: try json(["query": ["pages": pages]]))
    }

    func testCommonsCreditAndCaptionAreCleanedOfHTML() throws {
        let photo = try XCTUnwrap(try commons([commonsPage()]).first)
        XCTAssertEqual(photo.credit, "Jane & Co · CC BY-SA 4.0 · Wikimedia Commons")
        XCTAssertEqual(photo.caption, "View north")
    }

    func testCommonsDropsNewUndatedAndUnfreePhotos() throws {
        XCTAssertTrue(try commons([commonsPage(date: "1966-01-01"), commonsPage(date: "2014"), commonsPage(date: "unknown"),
                                   commonsPage(licence: "CC BY-NC 2.0"), commonsPage(licence: "CC BY-ND 2.0")]).isEmpty)
    }

    /// CC BY and CC BY-SA require the author's name, so with none the photo can't be used
    func testCommonsDropsAttributionPhotosWithNoAuthor() throws {
        XCTAssertTrue(try commons([commonsPage(artist: "<span></span>")]).isEmpty)
        XCTAssertEqual(try commons([commonsPage(licence: "Public domain", artist: "")]).count, 1)
    }

    func testCommonsPutsTheOldestFirstAndStopsAtTheLimit() throws {
        let photos = try commons([commonsPage(date: "1950", file: "new"), commonsPage(date: "circa 1880", file: "old")])
        XCTAssertEqual(photos.first?.largeURL.lastPathComponent, "old.jpg")
        let many = (0..<10).map { commonsPage(file: "f\($0)") }
        XCTAssertEqual(try commons(many).count, HeritageService.maxPhotos)
    }

    func testYearIsReadFromCommonDateForms() {
        XCTAssertEqual(HeritageService.year(in: "1931-05-01"), 1931)
        XCTAssertEqual(HeritageService.year(in: "circa 1930"), 1930)
        XCTAssertEqual(HeritageService.year(in: "May 1931"), 1931)
        XCTAssertNil(HeritageService.year(in: "2014-05-01"))
        XCTAssertNil(HeritageService.year(in: "unknown"))
    }

    // MARK: Library of Congress

    private func result(_ title: String, id: String = "mo0297", location: [String] = ["saint louis", "missouri"],
                        restricted: Bool = false) throws -> LoCSearchResult {
        let data = try json(["title": title, "url": "https://www.loc.gov/item/\(id)/", "location": location,
                             "access_restricted": restricted])
        return try JSONDecoder().decode(LoCSearchResult.self, from: data)
    }

    private func matches(_ result: LoCSearchResult, _ name: String, town: String = "St. Louis", state: String? = "MO") -> Bool {
        LibraryOfCongressService.isMatch(result, names: [LibraryOfCongressService.normalized(name)],
                                         town: LibraryOfCongressService.normalized(town), state: state)
    }

    func testSurveyMatchesTheBuildingInItsTownAndState() throws {
        XCTAssertTrue(matches(try result("Wainwright Building, 709 Chestnut Street, Saint Louis, Independent City, MO"), "Wainwright Building"))
        // "Rookery Building" and "The Rookery" are the same survey
        XCTAssertTrue(matches(try result("Rookery, 209 South LaSalle, Saint Louis, MO"), "Rookery Building"))
    }

    func testSurveyOfAnotherBuildingOrPlaceIsRefused() throws {
        // Named in the title, but it's a tomb in a cemetery
        XCTAssertFalse(matches(try result("Bellefontaine Cemetery, Wainwright Tomb, Saint Louis, MO"), "Wainwright Building"))
        XCTAssertFalse(matches(try result("Wainwright Building, Saint Louis, IL"), "Wainwright Building"))
        XCTAssertFalse(matches(try result("Union Station, Denver, CO", location: ["denver", "colorado"]), "Union Station", state: nil))
        XCTAssertFalse(matches(try result("Wainwright Building, Saint Louis, MO", restricted: true), "Wainwright Building"))
    }

    func testAddressesAndNamesAreRead() {
        XCTAssertEqual(LibraryOfCongressService.cityAndState(from: "705 Chestnut St, St. Louis, MO 63101")?.state, "MO")
        XCTAssertNil(LibraryOfCongressService.cityAndState(from: "Champ de Mars, 75007 Paris, France"))
        XCTAssertEqual(LibraryOfCongressService.normalized("The U.S. Capitol"), LibraryOfCongressService.normalized("U.S. Capitol"))
        XCTAssertEqual(LibraryOfCongressService.removingParenthetical("Library of Congress (Jefferson Building)"), "Library of Congress")
    }

    // MARK: The gallery

    func testGalleryKeepsArchiveOrderDropsRepeatsAndStopsAtTheLimit() {
        let merged = OldPhotoSources.merged([[image("a"), image("b")], [image("b"), image("c")], [], [image("d")]], limit: 3)
        XCTAssertEqual(merged.map(\.largeURL.lastPathComponent), ["a.jpg", "b.jpg", "c.jpg"])
    }

    // MARK: On This Day

    private func feed(_ events: [(Int, String, [String])]) throws -> Data {
        try json(["events": events.map { year, text, titles in
            ["year": year, "text": text, "pages": titles.map { ["titles": ["normalized": $0]] }] as [String: Any]
        }])
    }

    func testOnThisDayPutsLandmarksBeforeCities() throws {
        let data = try feed([(2000, "Something in Paris.", ["Paris"]),
                             (1889, "The Eiffel Tower opens.", ["Eiffel Tower"]),
                             (1900, "A dog is born.", ["Dog"])])
        let events = OnThisDayService.matchingEvents(in: data, landmarks: ["Paris": ["Eiffel Tower"]], cities: ["Paris"])
        XCTAssertEqual(events.map(\.year), [1889, 2000])
        XCTAssertEqual(events.first?.landmarkName, "Eiffel Tower")
        XCTAssertEqual(events.last?.cityName, "Paris")
    }

    /// A short name in the text alone isn't enough ("The Met" could mean anything)
    func testOnThisDayNeedsAnArticleForShortNames() throws {
        let data = try feed([(1900, "The Met was founded.", ["Weather"])])
        XCTAssertTrue(OnThisDayService.matchingEvents(in: data, landmarks: ["New York": ["The Met"]], cities: []).isEmpty)
    }

    func testOnThisDayStopsAtTheLimitAndSurvivesBadData() throws {
        let data = try feed((0..<9).map { (1900 + $0, "x", ["Paris"]) })
        XCTAssertEqual(OnThisDayService.matchingEvents(in: data, landmarks: [:], cities: ["Paris"]).count, OnThisDayService.maxEvents)
        XCTAssertTrue(OnThisDayService.matchingEvents(in: Data(), landmarks: [:], cities: []).isEmpty)
    }

    // MARK: Freesound

    private func sounds(_ license: String?) throws -> Data {
        var sound: [String: Any] = ["id": 7, "name": "Street", "username": "jo",
                                    "previews": ["preview-hq-mp3": "https://cdn.freesound.org/7.mp3"]]
        if let license { sound["license"] = license }
        return try json(["results": [sound]])
    }

    func testCitySoundMustBeCC0() throws {
        XCTAssertEqual(CitySoundService.firstSound(from: try sounds("http://creativecommons.org/publicdomain/zero/1.0/"))?.author, "jo")
        XCTAssertNotNil(CitySoundService.firstSound(from: try sounds("Creative Commons 0")))
        XCTAssertNil(CitySoundService.firstSound(from: try sounds("https://creativecommons.org/licenses/by-nc/4.0/")))
        XCTAssertNil(CitySoundService.firstSound(from: try sounds("https://creativecommons.org/licenses/by/4.0/")))
        XCTAssertNil(CitySoundService.firstSound(from: try sounds(nil)))
    }
}

final class OldFilmTests: XCTestCase {
    func testTheSmallStreamingCopyIsPreferred() {
        XCTAssertEqual(OldFilmService.bestVideo(in: ["a.ogv", "a.mp4", "a_512kb.mp4"]), "a_512kb.mp4")
        XCTAssertEqual(OldFilmService.bestVideo(in: ["a.ogv", "a.mp4"]), "a.mp4")
        XCTAssertNil(OldFilmService.bestVideo(in: ["a.ogv"]))
    }
}
