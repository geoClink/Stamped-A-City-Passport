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

    // Library of Congress Photochrom Print Collection (no known restrictions on publication),
    // Getty Museum Open Content (CC0), and public-domain photos on Wikimedia Commons for
    // Canada, Asia and Latin America. A landmark can have several bundled images.
    private static let photochrom: [String: [Entry]] = [
        "uk_bath_abbey": [Entry(file: "pc_uk_bath_abbey", caption: "Bath Abbey, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017659171/")!)],
        "ber_reichstag": [Entry(file: "pc_ber_reichstag", caption: "Reichstag, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2002713608/")!)],
        "ber_kaiser_wilhelm": [Entry(file: "pc_ber_kaiser_wilhelm", caption: "Kaiser Wilhelm Memorial Church, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2002713617/")!)],
        "pek_temple_heaven": [Entry(file: "pc_pek_temple_heaven", caption: "Temple of Heaven, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017658059/")!)],
        "mil_duomo": [Entry(file: "pc_mil_duomo", caption: "Piazza del Duomo and Milan Cathedral, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001700886/")!)],
        "rom_pantheon": [Entry(file: "pc_rom_pantheon", caption: "The Pantheon, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017660214/")!)],
        "rom_castel_sant": [Entry(file: "pc_rom_castel_sant", caption: "Castel Sant'Angelo and bridge, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001700934/")!)],
        "bcn_catedral": [Entry(file: "pc_bcn_catedral", caption: "Barcelona Cathedral facade, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017660376/")!)],
        "cai_mosque_madrasa_sultan_hassan": [Entry(file: "pc_cai_mosque_madrasa_sultan_hassan", caption: "Sultan Hassan Mosque, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017657142/")!)],
        "crk-01": [Entry(file: "pc_crk-01", caption: "St. Fin Barre's Cathedral, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2002717384/")!)],
        "crk-07": [Entry(file: "pc_crk-07", caption: "Blackrock Castle, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2002717374/")!)],
        "nap-05": [Entry(file: "pc_nap-05", caption: "Certosa di San Martino cloister, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001700898/")!)],
        "paris-eiffel-tower": [Entry(file: "pc_paris-eiffel-tower", caption: "Eiffel Tower, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001698582/")!)],
        "paris-arc-de-triomphe": [Entry(file: "pc_paris-arc-de-triomphe", caption: "Arc de Triomphe, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001698547/")!)],
        "paris-pantheon": [Entry(file: "pc_paris-pantheon", caption: "The Panthéon, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001698512/")!)],
        "paris-sainte-chapelle": [Entry(file: "pc_paris-sainte-chapelle", caption: "Sainte-Chapelle interior, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001698536/")!)],
        "st-pauls-cathedral": [Entry(file: "pc_st-pauls-cathedral", caption: "St. Paul's Cathedral, west front, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2002696932/")!)],
        "palace-of-westminster": [Entry(file: "pc_palace-of-westminster", caption: "Houses of Parliament from the river, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2002696921/")!)],
        "tower-of-london": [Entry(file: "pc_tower-of-london", caption: "Tower of London, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2002696927/")!)],
        "ist_topkapi_palace": [Entry(file: "pc_ist_topkapi_palace", caption: "Imperial Gate, Topkapı Palace, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2003653108/")!)],
        "ist_hagia_sophia": [Entry(file: "pc_ist_hagia_sophia", caption: "Hagia Sophia, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2003653107/")!)],
        "ist_suleymaniye": [Entry(file: "pc_ist_suleymaniye", caption: "Süleymaniye Mosque, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2003653113/")!)],
        "ist_chora_mosque": [Entry(file: "pc_ist_chora_mosque", caption: "Chora (Kariye) Mosque, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2003653114/")!)],
        "schonbrunn-palace": [Entry(file: "pc_schonbrunn-palace", caption: "Schönbrunn Palace, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2002708400/")!)],
        "belem-tower": [Entry(file: "pc_belem-tower", caption: "Belém Tower, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017660300/")!)],
        "jeronimos-monastery": [Entry(file: "pc_jeronimos-monastery", caption: "Jerónimos Monastery cloister, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017660301/")!)],
        "charles-bridge": [Entry(file: "pc_charles-bridge", caption: "Charles Bridge, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017659163/")!)],
        "athens-parthenon": [Entry(file: "pc_athens-parthenon", caption: "The Parthenon, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017658100/")!)],
        "athens-zeus-temple": [Entry(file: "pc_athens-zeus-temple", caption: "Temple of Olympian Zeus, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017658102/")!)],
        "edinburgh-castle": [Entry(file: "pc_edinburgh-castle", caption: "Edinburgh Castle and Esplanade, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017660374/")!)],
        "edinburgh-holyrood": [Entry(file: "pc_edinburgh-holyrood", caption: "Holyrood Palace, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001705992/")!)],
        "florence-cathedral": [Entry(file: "pc_florence-cathedral", caption: "Florence Cathedral and campanile, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001700795/")!)],
        "venice-rialto-bridge": [Entry(file: "pc_venice-rialto-bridge", caption: "Rialto Bridge, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001701016/")!)],
        "venice-bridge-of-sighs": [Entry(file: "pc_venice-bridge-of-sighs", caption: "Bridge of Sighs, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001700996/")!)],
        "venice-grand-canal": [Entry(file: "pc_venice-grand-canal", caption: "Grand Canal, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001701076/")!)],
        "venice-st-marks": [Entry(file: "pc_venice-st-marks", caption: "St Mark's Basilica and the clock, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001701003/")!)],
        "madrid-prado": [Entry(file: "pc_madrid-prado", caption: "Museo del Prado, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017660768/")!)],
        "madrid-royal-palace": [Entry(file: "pc_madrid-royal-palace", caption: "Royal Palace, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017660761/")!)],
        "madrid-plaza-mayor": [Entry(file: "pc_madrid-plaza-mayor", caption: "Plaza Mayor, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017660767/")!)],
        "dublin-st-patricks": [Entry(file: "pc_dublin-st-patricks", caption: "St. Patrick's Cathedral, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2002717396/")!)],
        "stockholm-skansen": [Entry(file: "pc_stockholm-skansen", caption: "Skansen, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001700740/")!)],
        "brussels-manneken-pis": [Entry(file: "pc_brussels-manneken-pis", caption: "Manneken Pis, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001697919/")!)],
        "brussels-royal-palace": [Entry(file: "pc_brussels-royal-palace", caption: "Royal Palace of Brussels, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001697910/")!)],
        "brussels-grand-place": [Entry(file: "pc_brussels-grand-place", caption: "Grand Place, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001697914/")!)],
        "at_hohensalzburg": [Entry(file: "pc_at_hohensalzburg", caption: "Hohensalzburg Fortress, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2002710952/")!)],
        "at_hellbrunn_palace": [Entry(file: "pc_at_hellbrunn_palace", caption: "Hellbrunn Palace, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2002710960/")!)],
        "es_real_alcazar_seville": [Entry(file: "pc_es_real_alcazar_seville", caption: "Real Alcázar, Patio de las Doncellas, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017660794/")!)],
        "es_seville_cathedral": [Entry(file: "pc_es_seville_cathedral", caption: "Seville Cathedral and Giralda, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017660791/")!)],
        "ru_peter_paul_fortress": [Entry(file: "pc_ru_peter_paul_fortress", caption: "Peter and Paul Cathedral, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001697502/")!)],
        "munich_frauenkirche": [Entry(file: "pc_munich_frauenkirche", caption: "Frauenkirche, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2002696142/")!)],
        "munich_nymphenburg_palace": [Entry(file: "pc_munich_nymphenburg_palace", caption: "Nymphenburg Palace, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017660090/")!)],
        "valencia_miguelete_tower": [Entry(file: "pc_valencia_miguelete_tower", caption: "El Miguelete, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017660342/")!)],
        "glasgow_cathedral": [Entry(file: "pc_glasgow_cathedral", caption: "Glasgow Cathedral, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001706003/")!)],
        "antwerp_city_hall": [Entry(file: "pc_antwerp_city_hall", caption: "City Hall on the Grote Markt, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001697875/")!)],
        "antwerp_het_steen": [Entry(file: "pc_antwerp_het_steen", caption: "Het Steen and the port, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001697879/")!)],
        "marseille_notre_dame_de_la_garde": [Entry(file: "pc_marseille_notre_dame_de_la_garde", caption: "Notre-Dame de la Garde, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001698450/")!)],
        "marseille_chateau_d_if": [Entry(file: "pc_marseille_chateau_d_if", caption: "Château d'If, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001698443/")!)],
        "helsinki-cathedral": [Entry(file: "pc_helsinki-cathedral", caption: "Helsinki Cathedral, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2001697412/")!)],
        "budapest-buda-castle": [Entry(file: "pc_budapest-buda-castle", caption: "Royal Castle, Buda, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2002710866/")!)],
        "hamburg_st_nicholas_church": [Entry(file: "pc_hamburg_st_nicholas_church", caption: "St. Nicholas Church (Nikolaikirche), photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017660068/")!)],
        "campus_oxford_sheldonian_theatre": [Entry(file: "pc_campus_oxford_sheldonian_theatre", caption: "Sheldonian Theatre, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2002708036/")!)],
        "campus_oxford_tom_tower": [Entry(file: "pc_campus_oxford_tom_tower", caption: "Tom Tower, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2002708037/")!)],
        "campus_oxford_magdalen_tower": [Entry(file: "pc_campus_oxford_magdalen_tower", caption: "Magdalen Tower, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2002708030/")!)],
        "campus_cambridge_kings_college_chapel": [Entry(file: "pc_campus_cambridge_kings_college_chapel", caption: "King's College, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2002696457/")!)],
        "campus_cambridge_bridge_of_sighs": [Entry(file: "pc_campus_cambridge_bridge_of_sighs", caption: "Bridge of Sighs, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2002696465/")!)],
        "campus_cambridge_senate_house": [Entry(file: "pc_campus_cambridge_senate_house", caption: "Caius College and Senate House, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2002696452/")!)],
        "campus_salamanca_escuelas_mayores": [Entry(file: "pc_campus_salamanca_escuelas_mayores", caption: "Facade of the University, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017660783/")!)],
        "campus_salamanca_casa_conchas": [Entry(file: "pc_campus_salamanca_casa_conchas", caption: "Casa de las Conchas, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2017660778/")!)],
        "campus_durham_castle": [Entry(file: "pc_campus_durham_castle", caption: "Durham Castle, photochrom, ca. 1890-1900",
                       credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2002696727/")!)],
    ]

    private static let getty: [String: [Entry]] = [
        "rom_pantheon": [Entry(file: "getty_rom_pantheon", caption: "Roma - Pantheon esterno, about 1900",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/1047R0")!)],
        "rom_castel_sant": [Entry(file: "getty_rom_castel_sant", caption: "Castel Sant'Angelo veduto dal fiume con barchetta, Roma, about 1880",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/104KC7")!)],
        "cai_great_pyramid": [Entry(file: "getty_cai_great_pyramid", caption: "Grande pyramide de Chéops — Félix Bonfils, 1870s",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/1092X4")!)],
        "cai_muhammad_ali": [Entry(file: "getty_cai_muhammad_ali", caption: "Mosque of Muhammad Ali, Cairo — Frank Mason Good, about 1870s",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/108NRR")!)],
        "cai_al_azhar": [Entry(file: "getty_cai_al_azhar", caption: "Mosquee Al Azhar (Cour des Theologiens) — G. Lekegian, about 1870–1890",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/104BTB")!)],
        "cai_mosque_madrasa_sultan_hassan": [Entry(file: "getty_cai_mosque_madrasa_sultan_hassan", caption: "The Mosque of Sultan Hassan, Cairo — Francis Frith, 1859–1860",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/1090NJ")!)],
        "nap-04": [Entry(file: "getty_nap-04", caption: "Théâtre San Carlo. Naples — Giorgio Sommer, about 1870–1890",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/107KGW")!)],
        "nap-05": [Entry(file: "getty_nap-05", caption: "Church of San Martino, Naples — Giorgio Sommer, about 1865–1875",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/104B9H")!)],
        "palace-of-westminster": [Entry(file: "getty_palace-of-westminster", caption: "Houses of Parliament — Henry W. Taunt, about 1886",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/108YY4")!)],
        "st-pauls-cathedral": [Entry(file: "getty_st-pauls-cathedral", caption: "St. Paul's Cathedral — John Leighton, 1859",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/108SMG")!)],
        "buckingham-palace": [Entry(file: "getty_buckingham-palace", caption: "Buckingham Palace — Frederic Jones, 1862–1868",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/1072SW")!)],
        "ist_hagia_sophia": [Entry(file: "getty_ist_hagia_sophia", caption: "Sancta Sophia from the Hippodrome — James Robertson, 1853",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/108ZQ6")!)],
        "ist_galata_tower": [Entry(file: "getty_ist_galata_tower", caption: "Tower of Galata, Constantinople — Abdullah Frères, 1858–1890",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/104KMS")!)],
        "athens-parthenon": [Entry(file: "getty_athens-parthenon", caption: "Athens - The Parthenon, General View from the Northwest — Francis Bedford, May 31, 1862",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/109052")!)],
        "athens-agora": [Entry(file: "getty_athens-agora", caption: "Athens, Temple of Theseus — Francis Frith, about 1860",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/108YNT")!)],
        "athens-zeus-temple": [Entry(file: "getty_athens-zeus-temple", caption: "Le temple de Zeus Olympien à Athènes — Frédéric Boissonnas, 1910",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/108MVK")!)],
        "florence-uffizi": [Entry(file: "getty_florence-uffizi", caption: "Portici degli Uffizi costruiti sul disegno di Vasari — Giacomo Brogi, about 1867",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/104KJ8")!)],
        "florence-palazzo-vecchio": [Entry(file: "getty_florence-palazzo-vecchio", caption: "Palazzo Vecchio, Florence — Fratelli Alinari, mid–late 19th century",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/1044RE")!)],
        "venice-doges-palace": [Entry(file: "getty_venice-doges-palace", caption: "Doges' Palace, Venice — Giovanni Battista Brusa, about 1870–1880",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/1048KM")!)],
        "venice-rialto-bridge": [Entry(file: "getty_venice-rialto-bridge", caption: "Rialto Bridge, Venice, about 1865–1880",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/104KCF")!)],
        "venice-grand-canal": [Entry(file: "getty_venice-grand-canal", caption: "Venezia - Canal Grande da S. Mercuola — Giovanni Battista Brusa, about 1870–1880",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/1048KH")!)],
        "venice-bridge-of-sighs": [Entry(file: "getty_venice-bridge-of-sighs", caption: "Bridge of Sighs, Venice, about 1865–1880",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/104KCD")!)],
        "madrid-royal-palace": [Entry(file: "getty_madrid-royal-palace", caption: "The Royal Palace, Madrid — Francis Frith, about 1850–1865",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/108YN6")!)],
        "mil_duomo": [Entry(file: "getty_mil_duomo", caption: "Milan Cathedral (Duomo di Milano), 1852",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/104H80")!)],
        "mil_galleria": [Entry(file: "getty_mil_galleria", caption: "Galleria Vittorio Emanuele, Milan — Deroche & Heyland, about 1877",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/1048KD")!)],
        "in_red_fort": [Entry(file: "getty_in_red_fort", caption: "The Red Fort at Delhi, 1850s–1890s",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/10A2BP")!)],
        "kyo_kinkaku_ji": [Entry(file: "getty_kyo_kinkaku_ji", caption: "Kinkaku-ji, 1850s–1890s",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/10A2K0")!)],
        "bkk_wat_arun": [Entry(file: "getty_bkk_wat_arun", caption: "Wat Arun, Bangkok — August Sachtler, about 1863–1871",
                       credit: "Getty Museum · CC0", link: URL(string: "https://www.getty.edu/art/collection/object/108PFN")!)],
    ]

    private static let worldPhotos: [String: [Entry]] = [
        "old-city-hall-toronto": [Entry(file: "wc_old-city-hall-toronto", caption: "Toronto City Hall (now Old City Hall), about 1910",
                       credit: "Toronto Public Library · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:City_Hall,_Toronto,_Canada_(1910)_-_(pcr-2198)_(5428287443).jpg")!)],
        "ca_chateau_frontenac": [Entry(file: "wc_ca_chateau_frontenac", caption: "Château Frontenac above Lower Town, Quebec City, about 1900",
                       credit: "BAnQ · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Ch%C3%A2teau_Frontenac_vers_ann%C3%A9es_1900.jpg")!)],
        "ca_citadelle_quebec": [Entry(file: "wc_ca_citadelle_quebec", caption: "Aerial view of the Citadelle of Québec, about 1900",
                       credit: "BAnQ · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Citadelle_de_Qu%C3%A9bec,_photo_W%C3%BCrtele.jpg")!)],
        "ca_funiculaire_quebec": [Entry(file: "wc_ca_funiculaire_quebec", caption: "Funicular below Château Frontenac, Quebec City, 1900",
                       credit: "Archives (Commons upload; holder unverified) · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Chateau_Frontenac_-_Funiculaire_-_1900.jpg")!)],
        "ca_petit_champlain": [Entry(file: "wc_ca_petit_champlain", caption: "Rue Petit-Champlain, Quebec City, about 1900",
                       credit: "Livernois / Commons · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Rue_Petit-Champlain,_Livernois.jpg")!)],
        "tokyo-station": [Entry(file: "wc_tokyo-station", caption: "Tokyo Station, Marunouchi building, 1914",
                       credit: "Japanese railway history (1914 scan) · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Tokyo_station_building_front_view_1914.jpg")!)],
        "kyo_fushimi_inari": [Entry(file: "wc_kyo_fushimi_inari", caption: "Torii gates at Fushimi Inari, Kyoto, about 1900",
                       credit: "Metropolitan Museum of Art · CC0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Fushimi_Inari_Taisha,_Kyoto,_Japan_MET_DP136206.jpg")!)],
        "kyo_kinkaku_ji": [Entry(file: "wc_kyo_kinkaku_ji", caption: "Kinkaku-ji garden, Kyoto, about 1900",
                       credit: "Wereldmuseum (Nationaal Museum van Wereldculturen) · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Collectie_Wereldmuseum,_RV-A181-1-13,_Foto,_%27Kinkaku-ji,_de_Gouden_Paviljoen_Tempel_in_Kyoto%27,_maker_onbekend-unknown,_ca._1900.jpg")!)],
        "osaka-castle": [Entry(file: "wc_osaka-castle", caption: "Osaka Castle walls, about 1910",
                       credit: "Japan to-day (1910 book) · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:The_Osaka_Castle.jpg")!)],
        "osaka-dotonbori": [Entry(file: "wc_osaka-dotonbori", caption: "Dotonbori street, Osaka, 1910",
                       credit: "National Diet Library, Japan · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Dotonbori_Osaka_1910.jpg")!)],
        "osaka-shinsekai": [Entry(file: "wc_osaka-shinsekai", caption: "Original Tsutenkaku tower and Shinsekai, Osaka, about 1912",
                       credit: "Commons (early postcard) · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Original_Tsutenkaku_and_Shinsekai_Luna_Park.jpg")!)],
        "pek_drum_tower": [Entry(file: "wc_pek_drum_tower", caption: "Drum Tower, Beijing, early 1900s",
                       credit: "Early postcard (Commons) · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Kou-Leou,_Le_Temple_du_Tambour,_Pekin.jpg")!)],
        "bkk_grand_palace": [Entry(file: "wc_bkk_grand_palace", caption: "Chakri Maha Prasat, Grand Palace, Bangkok, about 1900",
                       credit: "Commons (c.1900 print) · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Chakri_Maha_Prasat_1900.jpg")!)],
        "bkk_wat_phra_kaew": [Entry(file: "wc_bkk_wat_phra_kaew", caption: "Wat Phra Kaew temple complex, Bangkok, about 1870",
                       credit: "Rijksmuseum · CC0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Hoofdgebouw_van_het_tempelcomplex_van_Wat_Pra_Keo_(Tempel_van_de_Smaragdgroene_Boeddha)_in_Bangkok,_RP-F-F01197-AC.jpg")!)],
        "hanoi_temple_of_literature": [Entry(file: "wc_hanoi_temple_of_literature", caption: "Gate of the Temple of Literature, Hanoi, early 1900s",
                       credit: "Early postcard (Commons) · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Hano%C3%AF_-_Pagode_de_la_litt%C3%A9rature_-_Route_de_Sinh-Thu.jpg")!)],
        "hanoi_long_bien_bridge": [Entry(file: "wc_hanoi_long_bien_bridge", caption: "Long Biên (Paul Doumer) Bridge, Hanoi, 1915",
                       credit: "Commons (1915 photo) · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:HanoiLongBienBridge.jpg")!)],
        "hanoi_one_pillar_pagoda": [Entry(file: "wc_hanoi_one_pillar_pagoda", caption: "One Pillar Pagoda, Hanoi, 1896",
                       credit: "Firmin-André Salles (Commons) · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:One_Pillar_Pagoda,_Hanoi_(April_1896)_Firmin-Andr%C3%A9_Salles.jpg")!)],
        "hanoi_st_josephs_cathedral": [Entry(file: "wc_hanoi_st_josephs_cathedral", caption: "St. Joseph's Cathedral, Hanoi, early 1900s",
                       credit: "Early postcard (Commons) · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Hano%C3%AF_-_Cath%C3%A9drale,_sortie_de_la_Messe.jpg")!)],
        "hanoi_flag_tower": [Entry(file: "wc_hanoi_flag_tower", caption: "Flag Tower of Hanoi, about 1905",
                       credit: "Pierre Dieulefils postcard · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Hano%C3%AF_-_Tour_de_l%27ancienne_citadelle.jpg")!)],
        "hanoi_sofitel_legend_metropole": [Entry(file: "wc_hanoi_sofitel_legend_metropole", caption: "Hôtel Métropole, Hanoi, early 1900s",
                       credit: "Early postcard (Commons) · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Hano%C3%AF_-_H%C3%B4tel_M%C3%A9tropole.jpg")!)],
        "hcmc-ben-thanh-market": [Entry(file: "wc_hcmc-ben-thanh-market", caption: "Bến Thành Market, Saigon, 1920s",
                       credit: "Musée du quai Branly · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Le_grand_march%C3%A9,_Sa%C3%AFgon_(PV0016257).jpg")!)],
        "mex_met_cathedral": [Entry(file: "wc_mex_met_cathedral", caption: "Metropolitan Cathedral and Zócalo, Mexico City, 1897",
                       credit: "Commons / Internet Archive · No restrictions · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Cathedral,_City_of_Mexico._(15719792402).jpg")!)],
        "mex_bellas_artes": [Entry(file: "wc_mex_bellas_artes", caption: "Opera House (Teatro Nacional) under construction, Mexico City, about 1910",
                       credit: "Commons / Internet Archive · No restrictions · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Opera_House,_Mexico_City._(14848251970).jpg")!)],
        "casa-rosada": [Entry(file: "wc_casa-rosada", caption: "Casa Rosada, Buenos Aires, 1910",
                       credit: "Arcón de Buenos Aires · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Casa_Rosada_en_1910.jpg")!)],
        "teatro-colon": [Entry(file: "wc_teatro-colon", caption: "Teatro Colón, Buenos Aires, about 1908",
                       credit: "Archivo General de la Nación Argentina · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Teatro_Colon_(ca_1908,_AGN).jpg")!)],
        "rio-copacabana-palace": [Entry(file: "wc_rio-copacabana-palace", caption: "Copacabana Palace, Rio de Janeiro, 1923",
                       credit: "Commons (1923 photo) · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Copacabana_Palace_day_view_1923.png")!)],
        "rio-teatro-municipal": [Entry(file: "wc_rio-teatro-municipal", caption: "Theatro Municipal, Rio de Janeiro, about 1905-09",
                       credit: "Fundação Biblioteca Nacional / Domínio Público · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Teatro_municipal_rio_1905.jpg")!)],
        "br_estacao_da_luz": [Entry(file: "wc_br_estacao_da_luz", caption: "Estação da Luz, São Paulo, about 1900",
                       credit: "Pinacoteca do Estado de São Paulo · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Guilherme_Gaensly_-_Esta%C3%A7%C3%A3o_da_Luz,_c._1900.jpg")!)],
        "havana-old-havana": [Entry(file: "wc_havana-old-havana", caption: "Street in Old Havana, about 1908",
                       credit: "Detroit Publishing Co. postcard · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Havana_Vieja.jpg")!)],
        "havana-el-capitolio": [Entry(file: "wc_havana-el-capitolio", caption: "El Capitolio inauguration, Havana, 1929",
                       credit: "Postcard scan (1929) · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Havana_-_Capitol_inauguration.jpg")!)],
        "havana-malecon": [Entry(file: "wc_havana-malecon", caption: "Malecón and Morro Castle, Havana, 1902",
                       credit: "Detroit Publishing Co. postcard · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Havana_-_El_Malecon.jpg")!)],
        "havana-morro-castle": [Entry(file: "wc_havana-morro-castle", caption: "Morro Castle, Havana, 1914",
                       credit: "Detroit Publishing Co. postcard · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Habana_-_Castillo_del_Morro_(1914).jpg")!)],
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

    /// Every bundled source, oldest partnership first: a landmark's photos show in this order
    private static var allSources: [[String: [Entry]]] {
        [msu, detroit, cleveland, newYork, paris, europe, commonsPhotos, photochrom, getty, worldPhotos]
    }

    /// The bundled photos for a building, or none
    static func photos(forBuildingID id: String, bundle: Bundle = .main) -> [HistoricImage] {
        allSources.flatMap { $0[id] ?? [] }.compactMap { entry in
            guard let url = bundle.url(forResource: entry.file, withExtension: "jpg") else { return nil }
            return HistoricImage(thumbnailURL: url, largeURL: url, caption: entry.caption,
                                 isDrawing: false, credit: entry.credit, itemURL: entry.link)
        }
    }

    /// Whether a building has a bundled historic photo. A dictionary lookup only, no file access.
    static func hasPhotos(forBuildingID id: String) -> Bool {
        allSources.contains { $0[id] != nil }
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
    /// Bundled image counts for the Photochrom, Getty and world-Commons sources (for tests)
    static var photochromCount: Int { photochrom.count }
    static var gettyCount: Int { getty.count }
    static var worldPhotosCount: Int { worldPhotos.count }
}
