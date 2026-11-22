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

    // BEGIN morePhotos (generated by the 2026-11-22 photo batches; edit the manifests, not this block)
    /// Building ID → old photos found in Nov 2026 on Wikimedia Commons and loc.gov (public domain, CC0, CC BY/BY-SA or no known restrictions)
    private static let morePhotos: [String: [Entry]] = [
        "antwerp_boerentoren": [Entry(file: "ma_antwerp_boerentoren", caption: "Boerentoren, Antwerp, 1930s postcard", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Boerentoren_Antwerpen_briefkaart.jpg")!)],
        "atl-05": [Entry(file: "ma_atl-05", caption: "Flatiron (English-American) Building, Atlanta, 1921", credit: "Collier's · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Collier%27s_1921_Georgia_-_Atlanta_(Flatiron_Building).jpg")!)],
        "atx-01": [Entry(file: "ma_atx-01", caption: "Texas State Capitol, Austin, postcard, 1908", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2025675656/")!)],
        "auh_qasr_al_hosn": [Entry(file: "ma_auh_qasr_al_hosn-2", caption: "Qasr Al Hosn, Abu Dhabi, ca. 1960s", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2021669976/")!), Entry(file: "ma_auh_qasr_al_hosn", caption: "Qasr Al Hosn, Abu Dhabi, 1904", credit: "Hermann Burchardt · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Qasr_Al_Hosn.jpg")!)],
        "baltimore_city_hall": [Entry(file: "ma_baltimore_city_hall", caption: "Baltimore City Hall, ca. 1900", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2016807589/")!)],
        "baltimore_fort_mchenry": [Entry(file: "ma_baltimore_fort_mchenry", caption: "Fort McHenry, Baltimore, lithograph, 1861", credit: "Library of Congress · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Fort_McHenry,_Baltimore,_Md_LCCN2003656652.jpg")!)],
        "baltimore_washington_monument": [Entry(file: "ma_baltimore_washington_monument", caption: "Washington Monument, Baltimore, engraving, 1860", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Washington_Monument,_Baltimore_1860.jpg")!)],
        "basilica-cathedral-lima": [Entry(file: "ma_basilica-cathedral-lima", caption: "Cathedral of Lima, 1868", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2006679717/")!)],
        "bcn_casa_mila": [Entry(file: "ma_bcn_casa_mila", caption: "Casa Milà under construction, Barcelona, ca. 1908-10", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Casa_Mil%C3%A0_obras.jpg")!)],
        "bd_lalbagh_fort": [Entry(file: "ma_bd_lalbagh_fort", caption: "Lalbagh Fort, Dhaka, south entrance, 1875", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Lalbagh_Fort,_south_entrance,_south_view_Dhaka_1875.jpg")!)],
        "ber_shell_haus": [Entry(file: "ma_ber_shell_haus", caption: "Shell-Haus, Berlin, May 1934", credit: "Willy Pragher, Staatsarchiv Freiburg · CC BY 4.0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Berlin-_Shell_Haus;_quer;_mit_Autobus_-_LABW_-_Staatsarchiv_Freiburg_W_134_Nr._001564.jpeg")!), Entry(file: "ma_ber_shell_haus-2", caption: "Shell-Haus, Berlin, 1930s", credit: "Willy Pragher, Staatsarchiv Freiburg · CC BY 4.0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Berlin,_Shell-Haus_-_LABW_-_Staatsarchiv_Freiburg_W_134_Nr._001558.jpg")!)],
        "blr-02": [Entry(file: "ma_blr-02", caption: "Maharaja's Palace, Bangalore, ca. 1918 postcard", credit: "TuckDB Postcards · CC BY 4.0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Maharaja%27s_Palace,_Bangalore.jpg")!)],
        "bom_elphinstone": [Entry(file: "ma_bom_elphinstone", caption: "Elphinstone College, Bombay, ca. 1899 postcard", credit: "Paper Jewels · CC BY-SA 4.0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Elphinstone_College_Postcard.jpg")!)],
        "bom_rajabai": [Entry(file: "ma_bom_rajabai", caption: "Rajabai Clock Tower, Bombay, ca. 1903 postcard", credit: "Clifton & Co. · CC BY 4.0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Rajabai-tower_0.jpg")!)],
        "bos-02": [Entry(file: "ma_bos-02", caption: "Custom House Tower, Boston, 1914", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2016814167/")!)],
        "bos-04": [Entry(file: "ma_bos-04", caption: "Old State House, Boston, ca. 1890", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2016801203/")!)],
        "bos-06": [Entry(file: "ma_bos-06", caption: "Trinity Church, Boston, ca. 1900", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2016799484/")!)],
        "bos-12": [Entry(file: "ma_bos-12", caption: "Massachusetts State House, Boston, ca. 1905", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/92508398/")!)],
        "bos-14": [Entry(file: "ma_bos-14", caption: "Faneuil Hall, Boston, ca. 1890", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2016801204/")!)],
        "br_theatre_municipal": [Entry(file: "ma_br_theatre_municipal", caption: "Theatro Municipal, São Paulo, ca. 1910", credit: "Guilherme Gaensly / Museu Paulista · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Guilherme_Gaensly_-_S%C3%A3o_Paulo._Theatro_Municipal,_Acervo_do_Museu_Paulista_da_USP.jpg")!)],
        "brussels-cinquantenaire": [Entry(file: "ma_brussels-cinquantenaire", caption: "Cinquantenaire Arcade, Brussels, early 20th century postcard", credit: "KU Leuven Libraries · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Bruxelles._Arcade_Monumentale_du_Cinquantenaire_(04),_GP120406.jpg")!), Entry(file: "ma_brussels-cinquantenaire-2", caption: "Cinquantenaire Arcade, Brussels, 1928 postcard", credit: "KU Leuven Libraries · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Bruxelles._Arcade_du_Cinquantenaire_-_Brussels._Fifty_Jubile%27s_Arcade_(02),_GP021139.jpg")!)],
        "budapest-chain-bridge": [Entry(file: "ma_budapest-chain-bridge", caption: "Széchenyi Chain Bridge, Budapest, postcard, 1906", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:19060215_budapest_kettenbrucke.jpg")!)],
        "budapest-fishermans-bastion": [Entry(file: "ma_budapest-fishermans-bastion", caption: "Fisherman's Bastion, Budapest, 1905", credit: "Brück & Sohn Kunstverlag · CC0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:06674-Budapest-1905-Fischerbastei_mit_St._Stephanskirche-Br%C3%BCck_%26_Sohn_Kunstverlag.jpg")!)],
        "budapest-parliament": [Entry(file: "ma_budapest-parliament", caption: "Hungarian Parliament Building, Budapest, 1912", credit: "Brück & Sohn Kunstverlag · CC0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:14207-Budapest-1912-Parlament_mit_Stra%C3%9Fenbahn-Br%C3%BCck_%26_Sohn_Kunstverlag.jpg")!)],
        "budapest-st-stephens": [Entry(file: "ma_budapest-st-stephens", caption: "St. Stephen's Basilica, Budapest, 1908", credit: "Brück & Sohn Kunstverlag · CC0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:09486-Budapest-1908-St._Istvan_-_Basilika-Br%C3%BCck_%26_Sohn_Kunstverlag.jpg")!)],
        "buf_grain_elevators": [Entry(file: "ma_buf_grain_elevators", caption: "Concrete-Central Elevator, Buffalo, 1919", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2007661134/")!)],
        "campus_asu_old_main": [Entry(file: "ma_campus_asu_old_main", caption: "Old Main, Tempe Normal School, ca. 1890s", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Arizona_State_University_Old_Main_circa_1890.jpg")!)],
        "campus_brown_john_hay_library": [Entry(file: "ma_campus_brown_john_hay_library", caption: "John Hay Library, Brown University, ca. 1920", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:John_Hay_Library,_1920.jpg")!)],
        "campus_brown_sayles_hall": [Entry(file: "ma_campus_brown_sayles_hall", caption: "Sayles Hall, Brown University, ca. 1894", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Brown_University%E2%80%94Sayles_Memorial_Hall.jpg")!)],
        "campus_cambridge_mathematical_bridge": [Entry(file: "ma_campus_cambridge_mathematical_bridge", caption: "Mathematical Bridge, University of Cambridge, ca. 1870", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Cambridge_University,_Mathematical_Bridge,_Queen%27s_College.jpg")!)],
        "campus_clemson_tillman_hall": [Entry(file: "ma_campus_clemson_tillman_hall", caption: "Main Building (now Tillman Hall), Clemson College, 1896", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Tillman_Hall_1896.png")!)],
        "campus_colostate_ammons_hall": [Entry(file: "ma_campus_colostate_ammons_hall", caption: "Ammons Hall, Colorado State University, ca. 1922", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Ammons_Hall_(UHPC_2596).jpg")!)],
        "campus_cornell_bailey_hall": [Entry(file: "ma_campus_cornell_bailey_hall", caption: "Bailey Hall, Cornell University, ca. 1915", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Cornell_University_-_Bailey_Hall,_College_of_Agriculture.jpg")!)],
        "campus_cornell_morrill_hall": [Entry(file: "ma_campus_cornell_morrill_hall", caption: "Morrill Hall, Cornell University, ca. 1910", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Cornell---Morrill-Hall-b.jpg")!)],
        "campus_cornell_uris_library": [Entry(file: "ma_campus_cornell_uris_library", caption: "Uris Library, Cornell University, ca. 1900", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Cornell_-_Uris_Library_(1900).jpg")!)],
        "campus_cornell_willard_straight_hall": [Entry(file: "ma_campus_cornell_willard_straight_hall", caption: "Willard Straight Hall, Cornell University, ca. 1936", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Cornell_-_Willard_Straight_Hall_1936.jpg")!)],
        "campus_cuboulder_folsom_field": [Entry(file: "ma_campus_cuboulder_folsom_field", caption: "University of Colorado stadium (Folsom Field), postcard, ca. 1924", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Folsom_Field_color_postcard_circa_1924.jpg")!)],
        "campus_emu_sherzer_hall": [Entry(file: "ma_campus_emu_sherzer_hall", caption: "Sherzer Hall, Eastern Michigan University, ca. 1907", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Science_Building_M.S.N.C.,_1907_postcard.jpg")!)],
        "campus_gatech_tech_tower": [Entry(file: "ma_campus_gatech_tech_tower", caption: "Academic Building (Tech Tower), Georgia School of Technology, 1910", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Academic_Building_and_Carnegie_Library,_Georgia_School_of_Technology.jpg")!)],
        "campus_harvard_memorial_hall": [Entry(file: "ma_campus_harvard_memorial_hall", caption: "Memorial Hall, Harvard University, ca. 1879", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:AmCyc_Harvard_University_-_Memorial_Hall.jpg")!)],
        "campus_iastate_campanile": [Entry(file: "ma_campus_iastate_campanile", caption: "Campanile, Iowa State College, ca. 1900s postcard", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2024687813/")!)],
        "campus_iastate_morrill_hall": [Entry(file: "ma_campus_iastate_morrill_hall", caption: "Morrill Hall, Iowa State College, 1908", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Morrill_Hall_(exterior),_Iowa_State_College,_Ames,_Iowa_LCCN2004678743.jpg")!)],
        "campus_kcl_kings_building": [Entry(file: "ma_campus_kcl_kings_building", caption: "King's College London, King's Building, engraving, 19th century", credit: "Wellcome Collection · CC BY 4.0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:King%27s_College,_Strand,_London._Engraving_by_J._C._Carter._Wellcome_V0013842.jpg")!)],
        "campus_ku_spooner_hall": [Entry(file: "ma_campus_ku_spooner_hall", caption: "Spooner Library, University of Kansas, 1894", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Spooner_Library,_University_of_Kansas,_Lawrence,_Kan._LCCN2014647643.jpg")!)],
        "campus_mcgill_arts_building": [Entry(file: "ma_campus_mcgill_arts_building", caption: "Arts Building, McGill University, ca. 1875", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Arts_Building,_McGill_College,_Montreal,_QC,_about_1875.jpg")!)],
        "campus_ohiostate_ohio_stadium": [Entry(file: "ma_campus_ohiostate_ohio_stadium", caption: "Ohio Stadium, Ohio State University, postcard, ca. 1930s-40s", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Stadium,_Ohio_State_University._Columbus._Ohio_(73703).jpg")!)],
        "campus_ohiostate_thompson_library": [Entry(file: "ma_campus_ohiostate_thompson_library", caption: "Ohio State University Library (now Thompson Library), ca. 1915", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2014650184/")!)],
        "campus_okstate_old_central": [Entry(file: "ma_campus_okstate_old_central", caption: "Old Central, Oklahoma A&M College, ca. 1900s", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Old_Central.jpg")!)],
        "campus_penn_houston_hall": [Entry(file: "ma_campus_penn_houston_hall", caption: "Houston Hall, University of Pennsylvania, ca. 1900", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Houston_Hall,_University_of_Pennsylvania,_Philadelphia,_PA.jpg")!)],
        "campus_pitt_cathedral_of_learning": [Entry(file: "ma_campus_pitt_cathedral_of_learning", caption: "Cathedral of Learning, Pittsburgh, ca. 1930s", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2019677506/")!)],
        "campus_pitt_thaw_hall": [Entry(file: "ma_campus_pitt_thaw_hall", caption: "Thaw Hall, University of Pittsburgh, ca. 1900s", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2016815042/")!)],
        "campus_princeton_nassau_hall": [Entry(file: "ma_campus_princeton_nassau_hall", caption: "Nassau Hall, Princeton University, ca. 1903", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Nassau_Hall,_Princeton_University-LCCN2008679655.jpg")!)],
        "campus_purdue_memorial_union": [Entry(file: "ma_campus_purdue_memorial_union", caption: "Memorial Union Building, Purdue University, postcard, ca. 1940s", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Memorial_Union_Building,_Purdue_University,_West_Lafayette,_Indiana_(77509).jpg")!)],
        "campus_syracuse_crouse_college": [Entry(file: "ma_campus_syracuse_crouse_college", caption: "Crouse College, Syracuse University, 1904", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2016804092/")!)],
        "campus_syracuse_hall_of_languages": [Entry(file: "ma_campus_syracuse_hall_of_languages", caption: "Hall of Languages, Syracuse University, 1904", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2016804093/")!)],
        "campus_ucincy_van_wormer": [Entry(file: "ma_campus_ucincy_van_wormer", caption: "Van Wormer Library, University of Cincinnati, postcard, ca. 1905", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2025673582/")!)],
        "campus_ucl_cruciform_building": [Entry(file: "ma_campus_ucl_cruciform_building", caption: "Cruciform Building, University College Hospital, London, lithograph, ca. 1906", credit: "Wellcome Collection · CC BY 4.0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:The_Cruciform_Building,_University_College_Hospital,_London;_Wellcome_L0024801.jpg")!)],
        "campus_uga_demosthenian_hall": [Entry(file: "ma_campus_uga_demosthenian_hall", caption: "Demosthenian Hall, University of Georgia, 1939", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2017886247/")!)],
        "campus_uga_lucy_cobb": [Entry(file: "ma_campus_uga_lucy_cobb", caption: "Lucy Cobb Institute, Athens, Georgia, 1939", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2017886241/")!)],
        "campus_uiowa_old_capitol": [Entry(file: "ma_campus_uiowa_old_capitol", caption: "Old Capitol, Iowa City, ca. 1903", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Old_State_Capitol_at_Iowa_City_-_History_of_Iowa.jpg")!)],
        "campus_umd_rossborough_inn": [Entry(file: "ma_campus_umd_rossborough_inn-2", caption: "Rossborough Inn, Agricultural Experiment Station, ca. 1901-1910", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Rossborough_Inn,_Agricultural_Experiment_Station,_circa_1901-1910.jpg")!), Entry(file: "ma_campus_umd_rossborough_inn", caption: "Rossborough Inn, Maryland Agricultural College, 1913", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Rossborough_Inn,_Maryland_Agricultural_College,_1913.jpg")!)],
        "campus_unc_old_well": [Entry(file: "ma_campus_unc_old_well", caption: "The Old Well, University of North Carolina, 1938", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2017888723/")!)],
        "campus_unl_memorial_stadium": [Entry(file: "ma_campus_unl_memorial_stadium", caption: "Memorial Stadium, University of Nebraska, postcard, ca. 1948", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:University_of_Nebraska_Memorial_Stadium_Postcard_(Curteich_8B-H1652,_c._1948).png")!)],
        "campus_uoft_convocation_hall": [Entry(file: "ma_campus_uoft_convocation_hall", caption: "Convocation Hall, University of Toronto, ca. 1915", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Convocation_Hall,_University_of_Toronto_(I0016654).jpg")!)],
        "campus_utokyo_akamon": [Entry(file: "ma_campus_utokyo_akamon", caption: "Akamon, Imperial University of Tokyo, ca. 1905", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Akamon_ca._1905.jpg")!)],
        "campus_utokyo_main_gate": [Entry(file: "ma_campus_utokyo_main_gate", caption: "Main Gate, Imperial University of Tokyo, ca. 1920", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Front_gate_of_Tokyo_University_c._1920.jpg")!)],
        "campus_washu_brookings_hall": [Entry(file: "ma_campus_washu_brookings_hall", caption: "Brookings Hall, Washington University in St. Louis, ca. 1905", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Brookings_Hall_at_Washington_University.jpg")!)],
        "campus_washu_francis_gymnasium": [Entry(file: "ma_campus_washu_francis_gymnasium", caption: "Francis Gymnasium, Washington University in St. Louis, ca. 1903", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:View_of_the_Physical_Culture_Building_(later_Francis_Gymnasium,_Washington_University)_during_construction_for_the_1904_World%27s_Fair,_10_December_1903.jpg")!)],
        "campus_wayne_old_main": [Entry(file: "ma_campus_wayne_old_main", caption: "Old Main, Wayne State University, ca. 1904", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Central_High_School_historic_-_Detroit_Michigan.jpg")!)],
        "campus_wisc_science_hall": [Entry(file: "ma_campus_wisc_science_hall", caption: "Science Hall and Chemical Laboratory, University of Wisconsin, ca. 1880s-1900s", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2016797697/")!)],
        "casa-loma": [Entry(file: "ma_casa-loma", caption: "Casa Loma, Toronto, ca. 1920s", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Casa_Loma,_Toronto_-_circa_1920s.jpg")!)],
        "charleston_circular_congregational_church": [Entry(file: "ma_charleston_circular_congregational_church", caption: "Circular Congregational Church, Charleston, 1930s", credit: "Historic American Buildings Survey · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Circular_Congregational_Church,_138-150_Meeting_Street,_Charleston,_Charleston_County,_SC_HABS_SC,10-CHAR,91-5.tif")!)],
        "charleston_city_market": [Entry(file: "ma_charleston_city_market", caption: "Charleston City Market, ca. 1910 postcard", credit: "Souvenir Post Card Co., New York City · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Charleston_-_Old_Market,_ca._1910_01.jpg")!)],
        "charleston_county_courthouse": [Entry(file: "ma_charleston_county_courthouse", caption: "Old County Court House, Charleston, ca. 1912 postcard", credit: "Hugh C. Leighton Co. · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Charleston_-_Old_County_Court_House.jpg")!)],
        "charleston_fort_sumter": [Entry(file: "ma_charleston_fort_sumter", caption: "Fort Sumter, Charleston, 1930s-40s postcard", credit: "Published for Mason M. Rivers, Charleston by E. C. Kropp Co. · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Charleston_-_Fort_Sumter.jpg")!)],
        "charleston_heyward_washington_house": [Entry(file: "ma_charleston_heyward_washington_house", caption: "Heyward-Washington House, Charleston, 1930s", credit: "Historic American Buildings Survey · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Thomas_Heyward_House,_18_Meeting_Street,_Charleston,_Charleston_County,_SC_HABS_SC,10-CHAR,1-1.tif")!)],
        "charleston_huguenot_church": [Entry(file: "ma_charleston_huguenot_church", caption: "Huguenot Church, Charleston, ca. 1910 postcard", credit: "S. H. Kress & Co. (publisher) · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Charleston_-_Huguenot_Church.jpg")!)],
        "charleston_st_michaels_church": [Entry(file: "ma_charleston_st_michaels_church", caption: "St. Michael's Church, Charleston, ca. 1940 postcard", credit: "Published for Martschink Sales Co. by E. C. Kropp Co., Milwa · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Charleston_-_St._Michael%27s_Church.jpg")!)],
        "charleston_st_philips_church": [Entry(file: "ma_charleston_st_philips_church", caption: "St. Philip's Church, Charleston, 1906 postcard", credit: "Raphael Tuck & Sons · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Charleston_-_St._Philip%27s_Church_01.jpg")!)],
        "chi-02": [Entry(file: "ma_chi-02", caption: "Tribune Tower, Chicago, ca. 1930", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/95508791/")!)],
        "chi-06": [Entry(file: "ma_chi-06", caption: "The Rookery, Chicago, 1891", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:1891_Rookery_building.jpg")!)],
        "chi-09": [Entry(file: "ma_chi-09", caption: "Merchandise Mart, Chicago, 1930", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2007675576/")!)],
        "chi-10": [Entry(file: "ma_chi-10", caption: "Auditorium Building and Annex, Chicago, ca. 1900", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2008678297/")!)],
        "chi-12": [Entry(file: "ma_chi-12", caption: "Wrigley Building, Chicago, 1920s", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2007675574/")!)],
        "chi-14": [Entry(file: "ma_chi-14", caption: "Carbide & Carbon Building, Chicago, 1930s", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Carbide_and_Carbon_Building,_Chicago,_1930s_(NBY_3084).jpg")!)],
        "chi-15": [Entry(file: "ma_chi-15", caption: "Robie House, Chicago, 1955", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2020714521/")!)],
        "columbus_in_first_christian_church": [Entry(file: "ma_columbus_in_first_christian_church", caption: "First Christian Church (Tabernacle Church of Christ), Columbus, Indiana, 1940s", credit: "Boston Public Library, Tichnor Brothers · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Tabernacle_Church_of_Christ,_Columbus,_Indiana_(73833).jpg")!)],
        "cph_amalienborg": [Entry(file: "ma_cph_amalienborg", caption: "Amalienborg Palace, Copenhagen, ca. 1910 postcard", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2025703900/")!)],
        "cph_grundtvig": [Entry(file: "ma_cph_grundtvig", caption: "Grundtvig's Church under construction, Copenhagen, 1926", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Grundtvig%27s_Church_under_construction,_1926.png")!)],
        "dal_adolphus_hotel": [Entry(file: "ma_dal_adolphus_hotel", caption: "Adolphus Hotel, Dallas, postcard, ca. 1920", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2018645165/")!)],
        "dc-03": [Entry(file: "ma_dc-03", caption: "Library of Congress Jefferson Building, Washington, ca. 1902", credit: "Library of Congress · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Library_of_Congress,_Washington,_D.C._-_c._1902.jpg")!)],
        "dc-08": [Entry(file: "ma_dc-08", caption: "Union Station, Washington, D.C., 1908", credit: "Library of Congress · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:D.C._Washington._Union_Station._1908._Exterior_LCCN2005693079.jpg")!)],
        "den-09": [Entry(file: "ma_den-09", caption: "Brown Palace Hotel, Denver, ca. 1906", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2025663140/")!)],
        "den-13": [Entry(file: "ma_den-13", caption: "Daniels & Fisher Tower, Denver, 1911", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/98511141/")!)],
        "dublin-castle": [Entry(file: "ma_dublin-castle", caption: "Dublin Castle and Chapel, ca. 1903", credit: "Detroit Publishing Co. · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Dublin_Castle_and_Chapel_(NBY_443262).jpg")!)],
        "edinburgh-scott-monument": [Entry(file: "ma_edinburgh-scott-monument", caption: "Scott Monument, Edinburgh, ca. 1903", credit: "Detroit Publishing Co. · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Scott%27s_Monument,_Edinburgh_(NBY_438399).jpg")!)],
        "fort_worth_flatiron_building": [Entry(file: "ma_fort_worth_flatiron_building", caption: "Flatiron Building, Fort Worth, 1914", credit: "Frey Wholesale Postcard Co. · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Flat_Iron_Building_(20088486).jpg")!)],
        "fort_worth_sinclair_building": [Entry(file: "ma_fort_worth_sinclair_building", caption: "Sinclair Building, Fort Worth, 1930s postcard", credit: "E. C. Kropp Co. (Milwaukee) · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Sinclair_Building_(20107676).jpg")!)],
        "fort_worth_tarrant_county_courthouse": [Entry(file: "ma_fort_worth_tarrant_county_courthouse", caption: "Tarrant County Courthouse, Fort Worth, ca. 1908", credit: "Frey Post Card & News Co. (Fort Worth) · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Tarrant_County_Court_House_(20088586).jpg")!)],
        "fr_promenade_des_anglais": [Entry(file: "ma_fr_promenade_des_anglais", caption: "Promenade des Anglais, Nice, 1930s postcard", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Nice-Promenade_des_Anglais-Gilleta_177.jpg")!)],
        "glasgow_city_chambers": [Entry(file: "ma_glasgow_city_chambers", caption: "George Square and Municipal Buildings, Glasgow, ca. 1905", credit: "Frederick Hartmann · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Glasgow._George_Square_and_Municipal_Buildings.jpg")!)],
        "glasgow_kelvingrove": [Entry(file: "ma_glasgow_kelvingrove", caption: "Kelvingrove Art Gallery, Glasgow, ca. 1903", credit: "Raphael Tuck & Sons · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Fine_Art_Galleries_Glasgow_(NBY_442326).jpg")!)],
        "glasgow_school_of_art": [Entry(file: "ma_glasgow_school_of_art", caption: "Glasgow School of Art, postcard, ca. 1910", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Glasgow_School_of_Art_original_postcard_c.1910._3.jpg")!)],
        "hamburg_dammtor_station": [Entry(file: "ma_hamburg_dammtor_station", caption: "Dammtor station, Hamburg, postcard, 1903", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Bf_Dammtor_1903.jpg")!), Entry(file: "ma_hamburg_dammtor_station-2", caption: "New Dammtor station, Hamburg, ca. 1900", credit: "Knackstedt & Näther · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Hamburg,_Hamburg_-_Neuer_Dammtorbahnhof_(Zeno_Ansichtskarten).jpg")!)],
        "hnl-01": [Entry(file: "ma_hnl-01", caption: "Iolani Palace, Honolulu, HABS photograph", credit: "Library of Congress, Historic American Buildings Survey", link: URL(string: "https://www.loc.gov/item/hi0047/")!)],
        "hou-10": [Entry(file: "ma_hou-10", caption: "Niels Esperson Building, Houston, night view, 1927", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2023638966/")!)],
        "ist_dolmabahce_palace": [Entry(file: "ma_ist_dolmabahce_palace", caption: "Dolmabahce Palace from the Bosphorus, ca. 1890", credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://www.loc.gov/item/2003653121/")!)],
        "ist_maidens_tower": [Entry(file: "ma_ist_maidens_tower", caption: "Maiden's Tower, Istanbul, ca. 1880", credit: "Library of Congress, Abdullah Freres", link: URL(string: "https://www.loc.gov/item/2003671218/")!)],
        "kansas_city_union_station": [Entry(file: "ma_kansas_city_union_station", caption: "Kansas City Union Station, ca. 1914", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2016818238/")!)],
        "la_bradbury_building": [Entry(file: "ma_la_bradbury_building", caption: "Bradbury Building, Broadway and Third Street, Los Angeles, 1894", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Bradbury_Building_1894.jpg")!)],
        "lk_galle_face_green": [Entry(file: "ma_lk_galle_face_green", caption: "Galle Face, Colombo, 1901", credit: "New York Public Library · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Galle_Face,_Colombo_(Ceylon)_(NYPL_Hades-2359783-4044548).jpg")!)],
        "madrid-retiro-park": [Entry(file: "ma_madrid-retiro-park", caption: "Retiro Park, Puerta de Alfonso XII, Madrid, postcard, 1930s", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Madrid,_postales_138.jpg")!)],
        "mao-palacete-provincial": [Entry(file: "ma_mao-palacete-provincial", caption: "Palacete Provincial, Manaus, early 20th century", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Pal%C3%A1cio_Provincial_Manaus_1.jpg")!)],
        "marseille_abbey_of_saint_victor": [Entry(file: "ma_marseille_abbey_of_saint_victor", caption: "Abbey of Saint-Victor, Marseille, 1937", credit: "Swedish National Heritage Board · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Abbey_of_St._Victor,_Marseille,_France_(8134272650).jpg")!)],
        "mia-01": [Entry(file: "ma_mia-01", caption: "News Building (Freedom Tower), Miami, 1925 postcard", credit: "Curt Teich & Co. · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Miami_-_News_Building.jpg")!)],
        "mia-08": [Entry(file: "ma_mia-08", caption: "Miami Biltmore Hotel, Coral Gables, ca. 1935 postcard", credit: "Curt Teich & Co. · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Coral_Gables_-_Miami_Biltmore.jpg")!)],
        "mil_castello": [Entry(file: "ma_mil_castello", caption: "Castello Sforzesco, Rocchetta courtyard, Milan, ca. 1910 postcard", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2025711759/")!)],
        "milwaukee_basilica_of_st_josaphat": [Entry(file: "ma_milwaukee_basilica_of_st_josaphat", caption: "Basilica of St. Josaphat, Milwaukee, 1930s", credit: "Historic American Buildings Survey · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Basilica_of_St._Josaphat,_601_West_Lincoln_Avenue,_Milwaukee,_Milwaukee_County,_WI_HABS_WIS,40-MILWA,28-1.tif")!)],
        "milwaukee_city_hall": [Entry(file: "ma_milwaukee_city_hall", caption: "Milwaukee City Hall, ca. 1900", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2016808468/")!)],
        "milwaukee_pfister_hotel": [Entry(file: "ma_milwaukee_pfister_hotel", caption: "Hotel Pfister, Milwaukee, ca. 1905", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2016801932/")!)],
        "montreal-city-hall": [Entry(file: "ma_montreal-city-hall", caption: "City Hall, Montreal, 1890", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2016801882/")!)],
        "msp-06": [Entry(file: "ma_msp-06", caption: "Minnesota State Capitol, St. Paul, 1908", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2016814524/")!)],
        "msp-10": [Entry(file: "ma_msp-10", caption: "James J. Hill House, St. Paul, HABS photograph", credit: "Library of Congress, Historic American Buildings Survey", link: URL(string: "https://www.loc.gov/item/mn0013/")!)],
        "nap-02": [Entry(file: "ma_nap-02", caption: "Galleria Umberto I, Naples, postcard, ca. 1890", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2025711873/")!)],
        "nc_biltmore_estate": [Entry(file: "ma_nc_biltmore_estate", caption: "Biltmore House, Asheville, ca. 1902", credit: "Library of Congress / Detroit Publishing Co. · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Biltmore_Estate_Asheville_North_Carolina.jpg")!), Entry(file: "ma_nc_biltmore_estate-2", caption: "Biltmore House, Asheville, postcard, ca. 1902", credit: "Detroit Photographic Co. · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Biltmore_House,_Asheville,_NC_(NBY_429437).jpg")!)],
        "nc_omni_grove_park_inn": [Entry(file: "ma_nc_omni_grove_park_inn", caption: "Grove Park Inn, Asheville, ca. 1913", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2003663489/")!)],
        "nola_custom_house": [Entry(file: "ma_nola_custom_house", caption: "U.S. Custom House, New Orleans, ca. 1890", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2016797867/")!)],
        "nola_gallier_hall": [Entry(file: "ma_nola_gallier_hall", caption: "City Hall (Gallier Hall), New Orleans, 1937", credit: "Library of Congress, Historic American Buildings Survey", link: URL(string: "https://www.loc.gov/item/2017887062/")!)],
        "nola_old_ursuline_convent": [Entry(file: "ma_nola_old_ursuline_convent", caption: "Old Ursuline Convent, New Orleans, ca. 1920", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2018705693/")!)],
        "nola_st_louis_cathedral": [Entry(file: "ma_nola_st_louis_cathedral", caption: "Jackson Square and St. Louis Cathedral, New Orleans, ca. 1900", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2017658694/")!)],
        "nsh_customs_house": [Entry(file: "ma_nsh_customs_house", caption: "U.S. Custom House, Nashville, engraving, 1875", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2005693132/")!)],
        "nsh_state_capitol": [Entry(file: "ma_nsh_state_capitol", caption: "Tennessee State Capitol, Nashville, 1901", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2016808691/")!)],
        "nsh_the_parthenon": [Entry(file: "ma_nsh_the_parthenon", caption: "The Parthenon, Nashville, panorama, 1909", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2007662806/")!)],
        "nyc-01": [Entry(file: "ma_nyc-01", caption: "Empire State Building, New York, postcard, 1931", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2025672526/")!)],
        "nyc-10": [Entry(file: "ma_nyc-10", caption: "Grand Central Terminal, New York, 1927", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2003677155/")!)],
        "osaka-sumiyoshi-taisha": [Entry(file: "ma_osaka-sumiyoshi-taisha", caption: "Sumiyoshi Shrine, Osaka, 1907", credit: "New York Public Library · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Sumiyoshi_Shrine,_Osaka_(NYPL_Hades-2360384-4044183).jpg")!)],
        "oslo-akershus-fortress": [Entry(file: "ma_oslo-akershus-fortress", caption: "Akershus Fortress, Oslo, early 20th century", credit: "National Library of Norway · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:139_Oslo._Akershus_-_no-nb_digifoto_20151210_00058_bldsa_PK08976.jpg")!)],
        "oslo-royal-palace": [Entry(file: "ma_oslo-royal-palace", caption: "Royal Palace, Oslo, early 20th century", credit: "National Library of Norway · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:128_Oslo._Slottet_-_no-nb_digifoto_20151029_00017_bldsa_PK10644.jpg")!)],
        "pdx_custom_house": [Entry(file: "ma_pdx_custom_house", caption: "U.S. Custom House, Portland, Oregon, ca. 1908 postcard", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:US_Custom_House,_Portland,_Oregon.jpg")!)],
        "pdx_union_station": [Entry(file: "ma_pdx_union_station", caption: "Union Station, Portland, Oregon, postcard", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:The_Union_Station,_Portland,_Oregon_(74160).jpg")!)],
        "phi-01": [Entry(file: "ma_phi-01", caption: "City Hall, Philadelphia, ca. 1905", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2016804659/")!)],
        "phi-02": [Entry(file: "ma_phi-02", caption: "Independence Hall, Philadelphia, ca. 1900", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2008679522/")!)],
        "phi-13": [Entry(file: "ma_phi-13", caption: "Masonic Temple, Philadelphia, ca. 1905", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2016805333/")!)],
        "riga_latvian_national_museum_of_art": [Entry(file: "ma_riga_latvian_national_museum_of_art", caption: "Latvian National Museum of Art, Riga, ca. 1910", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Latvian_National_Museum_of_Art.jpg")!)],
        "rom_villa_medici": [Entry(file: "ma_rom_villa_medici", caption: "Villa Medici, Rome, ca. 1900 postcard", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2025712398/")!)],
        "royal-exhibition-building": [Entry(file: "ma_royal-exhibition-building", caption: "Royal Exhibition Building, Melbourne, souvenir postcard, 1907", credit: "State Library Victoria · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Royal_Exhibition_Building_postcard_souvenir.jpg")!)],
        "san_diego_cabrillo_bridge": [Entry(file: "ma_san_diego_cabrillo_bridge", caption: "Cabrillo Bridge, San Diego, 1915 postcard", credit: "Panama-California Exposition · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Cabrillo_Bridge,_Panama-California_Exposition,_Balboa_Park.jpg")!)],
        "san_diego_old_point_loma_lighthouse": [Entry(file: "ma_san_diego_old_point_loma_lighthouse", caption: "Old Point Loma Lighthouse, San Diego, ca. 1908 postcard", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2025662529/")!)],
        "san_diego_santa_fe_depot": [Entry(file: "ma_san_diego_santa_fe_depot", caption: "Santa Fe Depot, San Diego, ca. 1923", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2025662580/")!)],
        "san_diego_us_grant_hotel": [Entry(file: "ma_san_diego_us_grant_hotel", caption: "U.S. Grant Hotel, San Diego, 1913 postcard", credit: "Detroit Publishing Co. · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:U.S._Grant_Hotel,_San_Diego,_Calif.jpg")!)],
        "savannah_andrew_low_house": [Entry(file: "ma_savannah_andrew_low_house", caption: "Andrew Low House, Savannah, 1939", credit: "Frances Benjamin Johnston · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Andrew_Low_House_01.jpg")!)],
        "savannah_christ_church": [Entry(file: "ma_savannah_christ_church", caption: "Christ Church, Savannah, 1930s-40s postcard", credit: "Boston Public Library · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Old_Christ_Church,_founded_1733,_Savannah,_Ga._(8367065477).jpg")!)],
        "savannah_city_hall": [Entry(file: "ma_savannah_city_hall", caption: "Savannah City Hall, ca. 1907", credit: "Scan by NYPL · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:City_Hall,_Savannah,_Ga_(NYPL_b12647398-68633).tiff")!)],
        "savannah_cotton_exchange": [Entry(file: "ma_savannah_cotton_exchange", caption: "Savannah Cotton Exchange, ca. 1904", credit: "Detroit Publishing Co. · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Savannah_Cotton_Exchange.png")!)],
        "savannah_green_meldrim_house": [Entry(file: "ma_savannah_green_meldrim_house", caption: "Green-Meldrim House, Savannah, ca. 1900", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2016818109/")!)],
        "savannah_independent_presbyterian_church": [Entry(file: "ma_savannah_independent_presbyterian_church", caption: "Independent Presbyterian Church, Savannah, before 1923", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Savannah_GA_Independent_Presby_PHS935.jpg")!)],
        "savannah_isaiah_davenport_house": [Entry(file: "ma_savannah_isaiah_davenport_house", caption: "Isaiah Davenport House, Savannah, 1939", credit: "Library of Congress, Historic American Buildings Survey", link: URL(string: "https://www.loc.gov/item/2017886419/")!)],
        "savannah_juliette_gordon_low_birthplace": [Entry(file: "ma_savannah_juliette_gordon_low_birthplace", caption: "Wayne-Gordon House (Juliette Gordon Low Birthplace), Savannah, 1936", credit: "Historic American Buildings Survey · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Wayne-Gordon_House_(Savannah,_Georgia).jpg")!)],
        "savannah_telfair_academy": [Entry(file: "ma_savannah_telfair_academy", caption: "Telfair Academy, Savannah, ca. 1900", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2016796087/")!)],
        "sea_pike_place": [Entry(file: "ma_sea_pike_place", caption: "Pike Place Market, Seattle, ca. 1910", credit: "No known restrictions · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Pike_Place_Market,_Seattle,_Washington_(4861196306).jpg")!)],
        "sea_smith_tower": [Entry(file: "ma_sea_smith_tower", caption: "Smith Tower, Seattle, 1914", credit: "Asahel Curtis · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Seattle_-_Smith_Tower_1914.jpg")!)],
        "sf-03": [Entry(file: "ma_sf-03", caption: "Ferry Building, San Francisco, 1901", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2025662755/")!)],
        "sf-04": [Entry(file: "ma_sf-04", caption: "Palace of Fine Arts, San Francisco, postcard, 1913", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2025662681/")!)],
        "sf-08": [Entry(file: "ma_sf-08", caption: "City Hall, San Francisco, postcard, 1922", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2025662779/")!)],
        "sf-11": [Entry(file: "ma_sf-11", caption: "Golden Gate Bridge under construction, 1934", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/99403559/")!)],
        "sf-16": [Entry(file: "ma_sf-16", caption: "Japanese Tea Garden, Golden Gate Park, San Francisco, 1904", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2003681311/")!)],
        "stl-03": [Entry(file: "ma_stl-03", caption: "Grand Union Station, St. Louis, 1894", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2003681684/")!)],
        "stl-06": [Entry(file: "ma_stl-06", caption: "Anheuser-Busch Brewery Brew House, St. Louis, HABS photograph", credit: "Library of Congress, Historic American Buildings Survey", link: URL(string: "https://www.loc.gov/item/mo0926/")!)],
        "stl-09": [Entry(file: "ma_stl-09", caption: "Soldiers Memorial, St. Louis, postcard, ca. 1940", credit: "Tichnor Brothers · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Soldiers%27_Memorial._St._Louis._Mo_(63223).jpg")!)],
        "stl-11": [Entry(file: "ma_stl-11", caption: "Old Courthouse, St. Louis, 1902", credit: "Library of Congress, Detroit Publishing Co.", link: URL(string: "https://www.loc.gov/item/2003669789/")!)],
        "stl-12": [Entry(file: "ma_stl-12", caption: "Saint Louis Art Museum, Forest Park, ca. 1910", credit: "Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Art_Museum,_Forest_Park,_St_Louis.jpg")!)],
        "stockholm-royal-palace": [Entry(file: "ma_stockholm-royal-palace", caption: "Royal Palace, Stockholm, postcard, ca. 1900", credit: "Fredrik Peterson, Boston · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:The_Royal_Castle,_Stockholm,_postcard_early_19th_century.jpg")!)],
        "taipei-longshan-temple": [Entry(file: "ma_taipei-longshan-temple", caption: "Longshan Temple, Taipei, 1920s", credit: "Taihoku tourist postcard · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:1920_to_1929_the_Li%C3%B4ng-san_Temple_in_Taihoku.jpg")!)],
        "tlv_great_synagogue": [Entry(file: "ma_tlv_great_synagogue", caption: "Great Synagogue, Tel Aviv, 1930s", credit: "PikiWiki Israel · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:110275_tel_aviv_-_the_great_synagogue_PikiWiki_Israel.png")!), Entry(file: "ma_tlv_great_synagogue-2", caption: "Great Synagogue under construction, Tel Aviv, 1927", credit: "PikiWiki Israel · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:140677_tel_aviv_great_synagogue_PikiWiki_Israel.jpg")!)],
        "tlv_pagoda": [Entry(file: "ma_tlv_pagoda", caption: "Pagoda House, Tel Aviv, 1920s-30s postcard", credit: "PikiWiki Israel · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:109844_tel_aviv_-_pagoda_house_PikiWiki_Israel.png")!)],
        "tulsa_philcade_building": [Entry(file: "ma_tulsa_philcade_building", caption: "Philcade Building, Tulsa, 1930s-40s postcard", credit: "Tichnor Bros. · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Philcade_building,_Tulsa,_Okla_(62999).jpg")!)],
        "uk_pulteney_bridge": [Entry(file: "ma_uk_pulteney_bridge", caption: "Pulteney Bridge, Bath, ca. 1902 postcard", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2025704492/")!)],
        "uk_royal_crescent": [Entry(file: "ma_uk_royal_crescent", caption: "The Royal Crescent, Bath, ca. 1930 postcard", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2025704488/")!)],
        "uk_victoria_art_gallery": [Entry(file: "ma_uk_victoria_art_gallery", caption: "Victoria Art Gallery, Bath, architect's illustration, 1898", credit: "J. M. Brydon · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Art_Gallery_and_Library,_Bath_01.jpg")!)],
        "vic-01": [Entry(file: "ma_vic-01", caption: "Parliament Buildings, Victoria BC, ca. 1905 postcard", credit: "Library of Congress, Prints and Photographs Division", link: URL(string: "https://www.loc.gov/item/2025703388/")!)],
        "yvr-01": [Entry(file: "ma_yvr-01", caption: "Marine Building, Vancouver, 1947", credit: "Major James Skitt Matthews, City of Vancouver Archives · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Marine_Building_in_1947.jpg")!)],
    ]
    // END morePhotos

    /// Every bundled source, oldest partnership first: a landmark's photos show in this order
    private static var allSources: [[String: [Entry]]] {
        [msu, detroit, cleveland, newYork, paris, europe, commonsPhotos, photochrom, getty, worldPhotos, morePhotos]
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

    /// How many landmarks got a photo from the Nov 2026 batches (for tests)
    static var morePhotosCount: Int { morePhotos.count }
    /// How many image files those landmarks have (some have two)
    static var morePhotosFileCount: Int { morePhotos.values.reduce(0) { $0 + $1.count } }

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
