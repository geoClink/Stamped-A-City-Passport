//
//  CampusArchivePhotos.swift
//  Stamped! A City Passport
//
//  Historic photos a campus archive gave us permission to show, bundled with the app.
//  Michigan State University Archives signed a Permission to Display form on 2026-11-18
//  for exactly these 17 photos (docs/msu-archives/); any other photo needs a new request.
//  Detroit Public Library (Burton Historical Collection) approved these 22 Detroit photos
//  on 2026-11-20, for as long as the app is available, credited by collection and linked
//  to each item's page (docs/detroit-public-library/). DPL takes no responsibility for copyright.
//  Cleveland Public Library neither grants nor denies permission for its Digital Gallery and
//  asks only for a credit; these 5 were published before 1931 (docs/archive-outreach/).
//  The New York Public Library marks these 4 "No Copyright - United States" (public domain)
//  in its Digital Collections; credited and linked to each item.
//  Paris Musées releases these 6 Musée Carnavalet photos under CC0 and asks for a credit to
//  Paris Musées and the museum, with a link to its collections site.
//

import Foundation

nonisolated enum CampusArchivePhotos {
    /// The credit the archive asked for
    static let msuCredit = "Michigan State University Archives"
    /// The archive asked us to link here, not to On the Banks (which will be taken down)
    static let msuLink = URL(string: "https://lib.msu.edu/ua")!

    static let dplBurtonCredit = "Burton Historical Collection, Detroit Public Library"
    static let dplAutomotiveCredit = "National Automotive History Collection, Detroit Public Library"

    private struct Entry {
        let file: String
        let caption: String
        var credit: String = msuCredit
        var link: URL = msuLink
    }

    /// A Detroit Public Library photo, linked to its own page in the digital collections
    private static func dpl(_ id: String, node: Int, _ caption: String,
                            credit: String = dplBurtonCredit) -> [Entry] {
        [Entry(file: "dpl_\(id)", caption: caption, credit: credit,
               link: URL(string: "https://digitalcollections.detroitpubliclibrary.org/node/\(node)")!)]
    }

    /// Building ID → its permitted photos
    private static let msu: [String: [Entry]] = [
        "campus_michstate_beaumont_tower": [Entry(file: "msu_A001043", caption: "Beaumont Tower being constructed, January 1929")],
        "campus_michstate_cowles_house": [Entry(file: "msu_A000483", caption: "Cowles House, ca. 1920")],
        "campus_michstate_union": [Entry(file: "msu_A000564", caption: "A side view of the Union, 1935")],
        "campus_michstate_linton_hall": [Entry(file: "msu_A006972_76", caption: "Linton Hall, ca. 1888")],
        "campus_michstate_eustace_cole_hall": [Entry(file: "msu_A006972_80", caption: "Horticultural Laboratory (Eustace–Cole Hall), ca. 1888")],
        "campus_michstate_cook_seevers_hall": [Entry(file: "msu_A006972_36", caption: "Agricultural Laboratory (now Cook Hall), ca. 1888")],
        "campus_michstate_chittenden_hall": [Entry(file: "msu_A000920", caption: "Forestry Building (Chittenden Hall)")],
        "campus_michstate_marshall_adams_hall": [Entry(file: "msu_A001314", caption: "Marshall Hall, ca. 1920")],
        "campus_michstate_morrill_hall_of_agriculture": [Entry(file: "msu_A000906", caption: "Agriculture Hall, May 15, 1911")],
        "campus_michstate_msu_museum": [Entry(file: "msu_A001570", caption: "The exterior of the museum")],
        "campus_michstate_main_library": [Entry(file: "msu_A001571", caption: "An aerial view of the Main Library")],
        "campus_michstate_spartan_stadium": [Entry(file: "msu_A000366", caption: "Aerial view of the stadium, 1939")],
        "campus_michstate_demonstration_hall": [Entry(file: "msu_A000650", caption: "Demonstration Hall")],
        "campus_michstate_jenison_fieldhouse": [Entry(file: "msu_A001064", caption: "A view of Jenison Fieldhouse")],
        "campus_michstate_munn_ice_arena": [Entry(file: "msu_A009333", caption: "Recreational skating at Munn Ice Arena, November 11, 1994")],
        "campus_michstate_abrams_planetarium": [Entry(file: "msu_A003525", caption: "Abrams Planetarium exhibits, January 23, 1964")],
        "campus_michstate_breslin_center": [Entry(file: "msu_A009957", caption: "Breslin Center construction, July 13, 1988")],
    ]

    static let cplCredit = "Cleveland Public Library Digital Gallery"

    /// A Cleveland Public Library Digital Gallery photo, linked to its own page
    private static func cpl(_ id: Int, _ caption: String) -> [Entry] {
        [Entry(file: "cpl_\(id)", caption: caption, credit: cplCredit,
               link: URL(string: "https://cplorg.contentdm.oclc.org/digital/collection/p4014coll18/id/\(id)")!)]
    }

    static let nyplCredit = "The New York Public Library Digital Collections"

    /// A New York Public Library photo, linked to its own page in the Digital Collections
    private static func nypl(_ imageID: String, item: String, _ caption: String) -> [Entry] {
        [Entry(file: "nypl_\(imageID)", caption: caption, credit: nyplCredit,
               link: URL(string: "https://digitalcollections.nypl.org/items/\(item)")!)]
    }

    /// Building ID → its New York Public Library photo
    private static let newYork: [String: [Entry]] = [
        "nyc-04": nypl("836609", item: "e629ed10-c55a-012f-832f-58d385a7bc34",
                       "Flat Iron Building, New York, Detroit Publishing Co. postcard, ca. 1913"),
        "nyc-05": nypl("1648996", item: "5e66b3e8-fffa-d471-e040-e00a180654d7",
                       "Woolworth Building under construction, July 1912, by Irving Underhill"),
        "nyc-02": nypl("482796", item: "510d47d9-4f7b-a3d9-e040-e00a18064a99",
                       "The Chrysler Building from East 39th Street, 1938, by Berenice Abbott"),
        "nyc-06": nypl("482746", item: "510d47d9-4f43-a3d9-e040-e00a18064a99",
                       "Rockefeller Center from 444 Madison Avenue, 1937, by Berenice Abbott"),
    ]

    static let parisMuseesCredit = "Musée Carnavalet, Histoire de Paris / Paris Musées"

    /// A Paris Musées (Musée Carnavalet) photo, linked to its own page in the collections
    private static func carnavalet(_ node: Int, _ caption: String) -> [Entry] {
        [Entry(file: "pm_\(node)", caption: caption, credit: parisMuseesCredit,
               link: URL(string: "https://www.parismuseescollections.paris.fr/node/\(node)")!)]
    }

    /// Building ID → its Paris Musées photo
    private static let paris: [String: [Entry]] = [
        "paris-eiffel-tower": carnavalet(78191, "Construction of the Eiffel Tower"),
        "paris-sacre-coeur": carnavalet(130586, "Construction of the Sacré-Cœur basilica, ca. 1895"),
        "paris-arc-de-triomphe": carnavalet(490926, "The Arc de Triomphe from the Avenue de la Grande Armée, 1871"),
        "paris-palais-garnier": carnavalet(490866, "The Palais Garnier under construction, with Paris Commune posters, 1871"),
        "paris-pantheon": carnavalet(91879, "Restoration work on the Panthéon, 1871"),
        "paris-sainte-chapelle": carnavalet(131587, "The Sainte-Chapelle at the Palais de Justice, ca. 1851"),
    ]

    /// Building ID → its Cleveland Public Library photo
    private static let cleveland: [String: [Entry]] = [
        "cle-02": cpl(2861, "New Union Station (Terminal Tower), postcard, 1928"),
        "cle-03": cpl(8144, "Interior of the Arcade, 1896"),
        "cle-07": cpl(2863, "New West Side Market, postcard, ca. 1912"),
        "cle-08": cpl(1517, "Cleveland Trust Bank under construction, 1907"),
        "cle-14": cpl(2009, "Federal Building and Post Office, 1911"),
    ]

    /// Building ID → its approved Detroit Public Library photo
    private static let detroit: [String: [Entry]] = [
        "detroit_first_national": dpl("bh010122", node: 47566, "First National Bank building during construction"),
        "detroit_packard_plant": dpl("na044496", node: 18666, "Packard Motor Car Company factory", credit: dplAutomotiveCredit),
        "detroit_book_tower": dpl("bh009902", node: 47350, "Book Building and Tower, June 1927"),
        "detroit_guardian": dpl("bh009962", node: 47408, "Union Trust Building (now the Guardian Building), September 17, 1928"),
        "detroit_michigan_central": dpl("EB02f233", node: 77554, "Michigan Central Station"),
        "detroit_fisher_building": dpl("bh017707", node: 54583, "Fisher Building, 1928"),
        "detroit_fox_theatre": dpl("bh007290", node: 46597, "Fox Theatre"),
        "detroit_penobscot": dpl("bh009274", node: 46993, "Penobscot Building"),
        "detroit_dia": dpl("bh023971", node: 60164, "Detroit Institute of Arts"),
        "detroit_cadillac_place": dpl("bh007538", node: 46788, "General Motors Building"),
        "detroit_masonic_temple": dpl("MR0530", node: 63402, "Masonic Temple, ca. 1928"),
        "detroit_david_stott": dpl("bh009956", node: 47402, "David Stott Building"),
        "detroit_david_whitney": dpl("bh009960", node: 47406, "David Whitney Building, 1928"),
        "detroit_book_cadillac": dpl("bh010868", node: 48260, "Book-Cadillac Hotel"),
        "detroit_buhl_building": dpl("bh028598", node: 61845, "Buhl Building, December 8, 1928"),
        "detroit_vinton": dpl("bh010452", node: 47850, "Vinton Building, 1921"),
        "detroit_cadillac_tower": dpl("bh019583", node: 56185, "Cadillac Tower, 1957"),
        "detroit_fort_shelby": dpl("bh000509", node: 40774, "Hotel Fort Shelby"),
        "detroit_united_artists": dpl("bh029791", node: 126928, "United Artists Building and Theatre, October 1, 1940"),
        "detroit_fillmore": dpl("bh007544", node: 46794, "Entrance to the State Theatre (now The Fillmore)"),
        "detroit_wright_kay": dpl("DPA3368", node: 69218, "Wright, Kay & Co., October 1892"),
        "detroit_dpl_main": dpl("EB02f192", node: 77513, "Woodward entrance of the Detroit Public Library"),
    ]

    /// The bundled photos for a building, or none
    static func photos(forBuildingID id: String, bundle: Bundle = .main) -> [HistoricImage] {
        (msu[id] ?? detroit[id] ?? cleveland[id] ?? newYork[id] ?? paris[id] ?? []).compactMap { entry in
            guard let url = bundle.url(forResource: entry.file, withExtension: "jpg") else { return nil }
            return HistoricImage(thumbnailURL: url, largeURL: url, caption: entry.caption,
                                 isDrawing: false, credit: entry.credit, itemURL: entry.link)
        }
    }

    /// How many MSU buildings have bundled photos (for tests)
    static var buildingCount: Int { msu.count }
    /// How many Detroit landmarks have bundled photos (for tests)
    static var detroitBuildingCount: Int { detroit.count }
    /// How many Cleveland landmarks have bundled photos (for tests)
    static var clevelandBuildingCount: Int { cleveland.count }
    /// How many New York landmarks have bundled photos (for tests)
    static var newYorkBuildingCount: Int { newYork.count }
    /// How many Paris landmarks have bundled photos (for tests)
    static var parisBuildingCount: Int { paris.count }
}
