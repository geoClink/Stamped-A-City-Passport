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
//  Europeana and the Rijksmuseum: photos, prints and paintings each marked Public Domain or
//  CC0 by the institution that holds them, credited to it and linked to the record.
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
        "paris-louvre-pyramid": carnavalet(151759, "The Pavillon de l'Horloge in the Louvre's Cour Carrée, before the pyramid"),
    ]

    /// A public-domain or CC0 image found through Europeana, credited to the institution that holds it
    private static func europeana(_ file: String, _ page: String, _ caption: String,
                                  provider: String, licence: String) -> [Entry] {
        [Entry(file: file, caption: caption, credit: "\(provider) · \(licence) · Europeana", link: URL(string: page)!)]
    }

    /// A public-domain Rijksmuseum photo
    private static func rijksmuseum(_ file: String, _ page: String, _ caption: String) -> [Entry] {
        [Entry(file: file, caption: caption, credit: "Rijksmuseum · Public domain", link: URL(string: page)!)]
    }

    /// Building ID → its Europeana or Rijksmuseum image
    private static let europe: [String: [Entry]] = [
        "rom_colosseum": europeana("eu_rom_colosseum", "https://www.europeana.eu/item/2020903/KMS1776", "View of the interior of the Colosseum, painting by C. W. Eckersberg, 1816",
                         provider: "National Gallery of Denmark", licence: "Public domain"),
        "bcn_hospital_sant_pau": europeana("eu_bcn_hospital_sant_pau", "https://www.europeana.eu/item/773/https___catalonica_bnc_cat_catalonicahub_lod_oai_mdc_csuc_cat_bcsalvany____932_ent0", "Pavilions of the Hospital de Sant Pau, 1912",
                         provider: "Digital Memory of Catalonia", licence: "Public domain"),
        "bcn_santa_maria_mar": europeana("eu_bcn_santa_maria_mar", "https://www.europeana.eu/item/773/https___catalonica_bnc_cat_catalonicahub_lod_oai_mdc_csuc_cat_bcsalvany____6707_ent0", "The bell tower of Santa Maria del Mar, 1921",
                         provider: "Digital Memory of Catalonia", licence: "Public domain"),
        "nap-01": europeana("eu_nap-01", "https://www.europeana.eu/item/2020903/KKSgb2908", "Castel dell'Ovo, drawing, 1839",
                         provider: "National Gallery of Denmark", licence: "Public domain"),
        "athens-acropolis": europeana("eu_athens-acropolis", "https://www.europeana.eu/item/2059209/5476_11204625163_c41e7f75da_o_jpg", "The Temple of Athena Nike on the Acropolis, engraving, 1890",
                         provider: "The British Library", licence: "Public domain"),
        "florence-ponte-vecchio": europeana("eu_florence-ponte-vecchio", "https://www.europeana.eu/item/90402/RP_P_1954_519", "Ponte Vecchio, etching, 1914",
                         provider: "Rijksmuseum", licence: "Public domain"),
        "dublin-ha-penny-bridge": europeana("eu_dublin-ha-penny-bridge", "https://www.europeana.eu/item/2063628/IRE_280_001", "The Ha'penny Bridge, watercolour, 1818",
                         provider: "National Library of Ireland", licence: "Public domain"),
        "zurich-grossmunster": europeana("eu_zurich-grossmunster", "https://www.europeana.eu/item/2059209/5534_11147967504_776f935195_o_jpg", "The Grossmünster, engraving, 1881",
                         provider: "The British Library", licence: "Public domain"),
        "munich_feldherrnhalle": europeana("eu_munich_feldherrnhalle", "https://www.europeana.eu/item/90402/RP_F_F01131_B", "Odeonsplatz with the Feldherrnhalle and the Theatinerkirche, 1897",
                         provider: "Rijksmuseum", licence: "Public domain"),
        "hamburg_kunsthalle": europeana("eu_hamburg_kunsthalle", "https://www.europeana.eu/item/90402/RP_F_F05966", "The Hamburger Kunsthalle, stereo photograph, ca. 1876",
                         provider: "Rijksmuseum", licence: "Public domain"),
        "valencia_torres_de_serranos": europeana("eu_valencia_torres_de_serranos", "https://www.europeana.eu/item/343/https___hispana_mcu_es_lod_oai_bivaldi_gva_es_9778_ent0", "Torres de Serranos, ca. 1888",
                         provider: "Valencian Digital Library", licence: "Public domain"),
        "valencia_mercado_de_colon": europeana("eu_valencia_mercado_de_colon", "https://www.europeana.eu/item/343/https___hispana_mcu_es_lod_oai_bivaldi_gva_es_9096_ent0", "Mercado de Colón, postcard, ca. 1920",
                         provider: "Valencian Digital Library", licence: "Public domain"),
        "rotterdam_laurenskerk": europeana("eu_rotterdam_laurenskerk", "https://www.europeana.eu/item/90402/RP_P_1914_186", "The Laurenskerk, print, 1906",
                         provider: "Rijksmuseum", licence: "Public domain"),
        "granada_alhambra": europeana("eu_granada_alhambra", "https://www.europeana.eu/item/10501/bib_rnod_35599", "The Court of the Lions, Alhambra, print, ca. 1838",
                         provider: "National Library of Portugal", licence: "Public domain"),
        "granada_generalife": europeana("eu_granada_generalife", "https://www.europeana.eu/item/773/https___catalonica_bnc_cat_catalonicahub_lod_oai_mdc_csuc_cat_gravatsBRUB____430_ent0", "Garden of the Generalife, photograph by Schwartz, 19th century",
                         provider: "Digital Memory of Catalonia", licence: "Public domain"),
        "marseille_palais_longchamp": europeana("eu_marseille_palais_longchamp", "https://www.europeana.eu/item/2024903/photography_ProvidedCHO_KU_Leuven_9989063160101488", "Palais Longchamp, lantern slide, ca. 1862",
                         provider: "Catholic University of Leuven", licence: "Public domain"),
        "ams_royal_palace": rijksmuseum("rijks_ams_royal_palace", "https://www.rijksmuseum.nl/nl/collectie/object/RP-F-00-936--eaebcbbbac09da96efbbca7a4f98ccc3", "The Royal Palace on Dam Square, April 21, 1879"),
        "ams_centraal": rijksmuseum("rijks_ams_centraal", "https://www.rijksmuseum.nl/nl/collectie/object/RP-F-00-765--45909940d1e510bd8bcb9f031f652b4f", "Centraal Station and the Sint-Nicolaaskerk, ca. 1880–1900"),
        "ams_westerkerk": rijksmuseum("rijks_ams_westerkerk", "https://www.rijksmuseum.nl/nl/collectie/object/RP-F-00-775--f245b4943d7e5c7f1a473ca8daa89aa1", "The Prinsengracht with the Westerkerk, ca. 1880–1900"),
        "ams_beurs_van_berlage": rijksmuseum("rijks_ams_beurs_van_berlage", "https://www.rijksmuseum.nl/nl/collectie/object/BI-B-71-10--2dd641a55b302c344ef6d5722a23afa3", "The Damrak façade of the Beurs van Berlage, 1903"),
        "ber_brandenburg_gate": europeana("eu_ber_brandenburg_gate", "https://www.europeana.eu/item/90402/RP_F_F19927", "The Brandenburg Gate, 1891",
                         provider: "Rijksmuseum", licence: "Public domain"),
        "ams_rijksmuseum": europeana("eu_ams_rijksmuseum", "https://www.europeana.eu/item/90402/RP_F_2006_22_41", "The Rijksmuseum from the Singelgracht, 1904",
                         provider: "Rijksmuseum", licence: "Public domain"),
        "ams_scheepvaartmuseum": europeana("eu_ams_scheepvaartmuseum", "https://www.europeana.eu/item/90402/RP_P_1915_553", "'s Lands Zeemagazijn (now the Maritime Museum), print, ca. 1825",
                         provider: "Rijksmuseum", licence: "Public domain"),
        "bcn_palau_musica": europeana("eu_bcn_palau_musica", "https://www.europeana.eu/item/773/https___catalonica_bnc_cat_catalonicahub_lod_oai_mdc_csuc_cat_bcsalvany____1280_ent0", "A corridor in the Palau de la Música Catalana, 1913",
                         provider: "Digital Memory of Catalonia", licence: "Public domain"),
        "tower-of-london": europeana("eu_tower-of-london", "https://www.europeana.eu/item/90402/RP_P_1884_A_8130", "The chapel in the Tower of London, print, ca. 1830",
                         provider: "Rijksmuseum", licence: "Public domain"),
        "stephansdom": europeana("eu_stephansdom", "https://www.europeana.eu/item/15508/https___id_kulturpool_at_e492ba7b_70be_496d_a817_1ef628e6e22d_cho", "St. Stephen's Cathedral, drawing, 1905",
                         provider: "The Albertina Museum", licence: "Public domain"),
        "belem-tower": europeana("eu_belem-tower", "https://www.europeana.eu/item/10501/bib_rnod_30767", "Torre de Belém, 1897",
                         provider: "National Library of Portugal", licence: "Public domain"),
        "jeronimos-monastery": europeana("eu_jeronimos-monastery", "https://www.europeana.eu/item/10501/bib_rnod_42384", "The cloister of the Jerónimos Monastery, print, ca. 1840",
                         provider: "National Library of Portugal", licence: "Public domain"),
        "edinburgh-castle": europeana("eu_edinburgh-castle", "https://www.europeana.eu/item/2059209/5528_11306574955_bf4c9f9fbe_o_jpg", "Edinburgh Castle, engraving, 1885",
                         provider: "The British Library", licence: "Public domain"),
        "venice-st-marks": europeana("eu_venice-st-marks", "https://www.europeana.eu/item/2059209/5521_11213900526_5fcfb404f1_o_jpg", "St Mark's Basilica, engraving, 1891",
                         provider: "The British Library", licence: "Public domain"),
        "helsinki-market-square": europeana("eu_helsinki-market-square", "https://www.europeana.eu/item/90402/RP_F_2007_357_77", "The Societetshuset (City Hall) on the Market Square, 1898",
                         provider: "Rijksmuseum", licence: "Public domain"),
        "warsaw-old-town": europeana("eu_warsaw-old-town", "https://www.europeana.eu/item/0940415/_nnTtVS7", "Old Town Market Square on a weekday, 1903",
                         provider: "Mazowsze Digital Library", licence: "Public domain"),
        "warsaw-royal-castle": europeana("eu_warsaw-royal-castle", "https://www.europeana.eu/item/0940405/_nnhRc1Z", "The Knights' Hall in the Royal Castle, 1929",
                         provider: "Digital Library of the Warsaw University", licence: "Public domain"),
        "es_torre_del_oro": europeana("eu_es_torre_del_oro", "https://www.europeana.eu/item/991/https___catalonica_bnc_cat_catalonicahub_lod_oai_cdm21055_contentdm_oclc_org_vistes____1177_ent0", "Torre del Oro, print, ca. 1820",
                         provider: "Cartographic and Geological Institute of Catalonia", licence: "Public domain"),
        "ru_peterhof_palace": europeana("eu_ru_peterhof_palace", "https://www.europeana.eu/item/90402/RP_F_2007_357_37", "Peterhof Palace and its fountains, 1898",
                         provider: "Rijksmuseum", licence: "Public domain"),
        "munich_st_michaels_church": europeana("eu_munich_st_michaels_church", "https://www.europeana.eu/item/15508/https___id_kulturpool_at_e607b697_734b_4767_b75f_122d94ad20b5_cho", "In front of St. Michael's Church, painting, 1853",
                         provider: "The Albertina Museum", licence: "Public domain"),
        "munich_glyptothek": europeana("eu_munich_glyptothek", "https://www.europeana.eu/item/90402/RP_F_2004_262_24_2", "The Glyptothek, ca. 1865",
                         provider: "Rijksmuseum", licence: "Public domain"),
        "hamburg_city_hall": europeana("eu_hamburg_city_hall", "https://www.europeana.eu/item/2048429/item_UPRVACYHOJL5F47QDTULS4FKLANZCOGM", "Hamburg City Hall, print, 1902",
                         provider: "Museum of Arts and Crafts, Hamburg", licence: "CC0"),
        "valencia_cathedral": europeana("eu_valencia_cathedral", "https://www.europeana.eu/item/343/https___hispana_mcu_es_lod_oai_bivaldi_gva_es_9783_ent0", "The Puerta del Palau of Valencia Cathedral, ca. 1870",
                         provider: "Valencian Digital Library", licence: "Public domain"),
        "valencia_lonja_de_la_seda": europeana("eu_valencia_lonja_de_la_seda", "https://www.europeana.eu/item/343/https___hispana_mcu_es_lod_oai_bivaldi_gva_es_7325_ent0", "La Lonja, ca. 1870",
                         provider: "Valencian Digital Library", licence: "Public domain"),
        "valencia_torres_de_quart": europeana("eu_valencia_torres_de_quart", "https://www.europeana.eu/item/343/https___hispana_mcu_es_lod_oai_bivaldi_gva_es_11047_ent0", "Torres de Quart, postcard, ca. 1912",
                         provider: "Valencian Digital Library", licence: "Public domain"),
        "valencia_palace_marques_de_dos_aguas": europeana("eu_valencia_palace_marques_de_dos_aguas", "https://www.europeana.eu/item/343/https___hispana_mcu_es_lod_oai_bivaldi_gva_es_9179_ent0", "Palace of the Marqués de Dos Aguas, postcard, 1927",
                         provider: "Valencian Digital Library", licence: "Public domain"),
        "antwerp_cathedral_of_our_lady": europeana("eu_antwerp_cathedral_of_our_lady", "https://www.europeana.eu/item/90402/RP_T_2003_13", "Cathedral of Our Lady, drawing, ca. 1890",
                         provider: "Rijksmuseum", licence: "Public domain"),
        "antwerp_vleeshuis": europeana("eu_antwerp_vleeshuis", "https://www.europeana.eu/item/90402/RP_P_1968_266", "The Vleeshuis, print, 1912",
                         provider: "Rijksmuseum", licence: "Public domain"),
        "porto_clerigos_tower": europeana("eu_porto_clerigos_tower", "https://www.europeana.eu/item/10501/bib_rnod_30182", "Torre dos Clérigos, ca. 1885",
                         provider: "National Library of Portugal", licence: "Public domain"),
        "uk_roman_baths": europeana("eu_uk_roman_baths", "https://www.europeana.eu/item/90402/RP_F_2009_123_3", "Visitors at the Roman Baths, 1921",
                         provider: "Rijksmuseum", licence: "Public domain"),
    ]

    /// A public-domain image on Wikimedia Commons, credited to the institution that holds the original
    private static func commons(_ file: String, _ page: String, _ caption: String,
                                institution: String, licence: String) -> [Entry] {
        [Entry(file: file, caption: caption, credit: "\(institution) · \(licence) · Wikimedia Commons", link: URL(string: page)!)]
    }

    /// Building ID → its Wikimedia Commons image (Sydney: State Library of NSW and National Library of Australia)
    private static let commonsPhotos: [String: [Entry]] = [
        "syd_harbour_bridge": commons("commons_syd_harbour_bridge", "https://commons.wikimedia.org/wiki/File:SLNSW_42880_View_of_the_Sydney_Harbour_Bridge_from_the_north_side_showing_the_arch_completed_and_Dorman_Longs_workshop_in_foreground.jpg", "The arch just completed, seen from the north side, August 1930",
                       institution: "State Library of New South Wales", licence: "Public domain"),
        "syd_qvb": commons("commons_syd_qvb", "https://commons.wikimedia.org/wiki/File:SLNSW_796856_Victoria_Markets_Queen_Victoria_Building_Sydney.jpg", "Queen Victoria Markets (now the QVB), ca. 1900–1927",
                       institution: "State Library of New South Wales", licence: "Public domain"),
        "syd_art_gallery": commons("commons_syd_art_gallery", "https://commons.wikimedia.org/wiki/File:National_Art_Gallery_of_New_South_Wales,_ca._1900-1910_-_Star_Photo_Co._(3572499330).jpg", "National Art Gallery of New South Wales, ca. 1900–1910",
                       institution: "State Library of New South Wales", licence: "Public domain"),
        "syd_st_marys": commons("commons_syd_st_marys", "https://commons.wikimedia.org/wiki/File:Construction,_St._Mary%27s_Cathedral,_Sydney,_1920s.jpg", "St Mary's Cathedral under construction, 1920s",
                       institution: "State Library of New South Wales", licence: "No restrictions"),
        "syd_customs_house": commons("commons_syd_customs_house", "https://commons.wikimedia.org/wiki/File:Customs_House_Circular_Quay_Sydney.jpg", "Customs House, Circular Quay, 1913",
                       institution: "National Library of Australia", licence: "Public domain"),
        "syd_town_hall": commons("commons_syd_town_hall", "https://commons.wikimedia.org/wiki/File:Town_Hall,_Sydney,_Inauguration_of_Australian_Commonwealth.jpg", "Sydney Town Hall lit up for the inauguration of the Commonwealth, January 1, 1901",
                       institution: "State Library of New South Wales", licence: "Public domain"),
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
        (msu[id] ?? detroit[id] ?? cleveland[id] ?? newYork[id] ?? paris[id] ?? europe[id] ?? commonsPhotos[id] ?? []).compactMap { entry in
            guard let url = bundle.url(forResource: entry.file, withExtension: "jpg") else { return nil }
            return HistoricImage(thumbnailURL: url, largeURL: url, caption: entry.caption,
                                 isDrawing: false, credit: entry.credit, itemURL: entry.link)
        }
    }

    /// Whether a building has a bundled historic photo. A dictionary lookup only, no file access.
    static func hasPhotos(forBuildingID id: String) -> Bool {
        msu[id] != nil || detroit[id] != nil || cleveland[id] != nil || newYork[id] != nil
            || paris[id] != nil || europe[id] != nil || commonsPhotos[id] != nil
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
    /// How many landmarks have a bundled Europeana or Rijksmuseum image (for tests)
    static var europeBuildingCount: Int { europe.count }
    /// How many landmarks have a bundled Wikimedia Commons image (for tests)
    static var commonsBuildingCount: Int { commonsPhotos.count }
}
