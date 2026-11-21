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
        (msu[id] ?? detroit[id] ?? []).compactMap { entry in
            guard let url = bundle.url(forResource: entry.file, withExtension: "jpg") else { return nil }
            return HistoricImage(thumbnailURL: url, largeURL: url, caption: entry.caption,
                                 isDrawing: false, credit: entry.credit, itemURL: entry.link)
        }
    }

    /// How many MSU buildings have bundled photos (for tests)
    static var buildingCount: Int { msu.count }
    /// How many Detroit landmarks have bundled photos (for tests)
    static var detroitBuildingCount: Int { detroit.count }
}
