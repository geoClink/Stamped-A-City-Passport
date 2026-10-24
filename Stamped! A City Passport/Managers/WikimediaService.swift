//
//  WikimediaService.swift
//  Stamped! A City Passport
//
//  Fetches the main CC-licensed photo and opening paragraph for any building
//  using the Wikipedia REST API. No API key required.
//
//  Falls back gracefully: if Wikipedia has no article, the UI falls back to
//  the app's asset catalog image.
//

import Foundation

// MARK: - Result model

struct WikiSummary {
    let photoURL: URL?
    let extract: String?     // First paragraph from Wikipedia article
}

// MARK: - Service

actor WikimediaService {
    static let shared = WikimediaService()

    // In-memory cache: building ID (or name, for lookups without one) → summary
    private var cache: [String: WikiSummary] = [:]

    private init() {}

    /// Pass `buildingID` for landmarks: some names are shared between cities
    /// ("Union Station" is in Los Angeles and Portland), and the ID keeps them apart.
    func summary(for buildingName: String, buildingID: String? = nil) async -> WikiSummary {
        let cacheKey = buildingID ?? buildingName
        if let cached = cache[cacheKey] { return cached }

        // Wikipedia only has a different place with this name: show nothing rather than the wrong photo
        if let buildingID, Self.skipWikipedia.contains(buildingID) {
            return WikiSummary(photoURL: nil, extract: nil)
        }

        // Try the most specific title first, then looser versions of the name
        let override = buildingID.flatMap { Self.titleOverrides[$0] }
        var candidates = [override ?? buildingName]
        candidates.append(simplify(buildingName))
        candidates.append(simplify(removingParenthetical(buildingName)))

        var result = WikiSummary(photoURL: nil, extract: nil)
        var tried = Set<String>()
        for title in candidates where !tried.contains(title) {
            tried.insert(title)
            if let found = await fetch(title: title) {
                result = found
                break
            }
        }

        cache[cacheKey] = result
        return result
    }

    // MARK: - Private

    private func fetch(title: String) async -> WikiSummary? {
        let encoded = encodedTitle(title)
        guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)") else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: wikiRequest(url))
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

            let decoded = try JSONDecoder().decode(WikiAPIResponse.self, from: data)

            // Prefer originalimage (higher resolution), fall back to thumbnail
            var photoURL = decoded.originalimage?.source.flatMap(URL.init)
                ?? decoded.thumbnail?.source.flatMap(URL.init)

            // Some articles have no lead photo, or use a logo/diagram as it
            // (e.g. One World Trade Center). Look further down the article instead.
            if photoURL == nil || isLogoOrDiagram(photoURL) {
                photoURL = await firstPhotoInArticle(encodedTitle: encoded) ?? photoURL
            }

            let extract = decoded.extract?.isEmpty == false ? decoded.extract : nil

            return WikiSummary(photoURL: photoURL, extract: extract)
        } catch {
            return nil
        }
    }

    /// First real photograph (not a logo, map or diagram) in the article's media list.
    private func firstPhotoInArticle(encodedTitle: String) async -> URL? {
        guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/media-list/\(encodedTitle)"),
              let (data, response) = try? await URLSession.shared.data(for: wikiRequest(url)),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let list = try? JSONDecoder().decode(WikiMediaList.self, from: data)
        else { return nil }

        for item in list.items where item.type == "image" {
            // srcset entries look like "//upload.wikimedia.org/..."; take the largest
            guard let src = item.srcset?.last?.src else { continue }
            let candidate = URL(string: src.hasPrefix("//") ? "https:" + src : src)
            if let candidate, !isLogoOrDiagram(candidate) { return candidate }
        }
        return nil
    }

    private func isLogoOrDiagram(_ url: URL?) -> Bool {
        guard let path = url?.absoluteString.lowercased() else { return false }
        return path.contains(".svg") || path.contains("logo") || path.contains("map")
    }

    private func encodedTitle(_ title: String) -> String {
        title.replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
    }

    // Wikipedia asks apps to identify themselves
    private func wikiRequest(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Stamped-A-City-Passport/2.3 (iOS)", forHTTPHeaderField: "User-Agent")
        return request
    }

    // "Rockefeller Center (30 Rock)" → "Rockefeller Center"
    private func removingParenthetical(_ name: String) -> String {
        guard let open = name.firstIndex(of: "(") else { return name }
        return String(name[..<open]).trimmingCharacters(in: .whitespaces)
    }

    // Strip common prefixes that don't match Wikipedia titles
    // e.g. "The Empire State Building" → "Empire State Building"
    private func simplify(_ name: String) -> String {
        let prefixes = ["The ", "A ", "An "]
        for prefix in prefixes {
            if name.hasPrefix(prefix) {
                return String(name.dropFirst(prefix.count))
            }
        }
        return name
    }
}

// MARK: - Title overrides

extension WikimediaService {
    /// Building ID → Wikipedia article title, for landmarks whose app name doesn't
    /// lead to the right article (or to one with a photo). Sorted by city.
    /// Found and checked with tools/photo-audit: every title gives a real photo of
    /// the landmark. A few articles sit more than 2 km from the registry
    /// coordinates because those coordinates are off (see reports/manual-review.md).
    nonisolated static let titleOverrides: [String: String] = [
        // Accra
        "accra-ghana-national-museum": "National Museum of Ghana",   // Ghana National Museum
        "accra-kwame-nkrumah-mausoleum": "Kwame Nkrumah Memorial Park", // Kwame Nkrumah Mausoleum and Memorial Park

        // Addis Ababa
        "addis-african-union": "African Union Conference Center and Office Complex", // African Union headquarters building

        // Amman
        "amman-rainbow-street": "Rainbow Street",                    // Rainbow Street, Amman

        // Amsterdam
        "ams_centraal": "Amsterdam Centraal station",                // Amsterdam Centraal Station
        "ams_arcam": "Amsterdam Centre for Architecture",            // ARCAM
        "ams_eye_film": "Eye Filmmuseum",                            // Eye Film Institute
        "ams_scheepvaartmuseum": "Het Scheepvaartmuseum",            // National Maritime Museum
        "ams_nemo": "NEMO (museum)",                                 // NEMO Science Museum

        // Asheville
        "nc_basilica_st_lawrence": "Basilica of St. Lawrence, Asheville", // Basilica of Saint Lawrence

        // Atlanta
        "atl-01": "Bank of America Plaza (Atlanta)",                 // Bank of America Plaza
        "atl-05": "Flatiron Building (Atlanta)",                     // Flatiron Building (English-American)
        "atl-08": "Swan House (Atlanta)",                            // Swan House
        "atl-07": "Fox Theatre (Atlanta)",                           // The Fox Theatre

        // Auckland
        "sky-tower-auckland": "Sky Tower (Auckland)",                // Sky Tower

        // Austin
        "atx-09": "St. Mary's Cathedral (Austin, Texas)",            // St. Mary's Cathedral

        // Bali
        "bali-ulun-danu": "Pura Ulun Danu Bratan",                   // Pura Ulun Danu Beratan
        "bali-tirta-gangga": "Tirta Gangga",                         // Tirta Gangga Water Palace
        "bali-ubud-palace": "Ubud Palace",                           // Ubud Royal Palace (Puri Saren Agung)

        // Barcelona
        "bcn_forum": "Forum Building",                               // Edifici Fòrum
        "bcn_macba": "Barcelona Museum of Contemporary Art",         // MACBA
        "bcn_santa_maria_mar": "Santa Maria del Mar, Barcelona",     // Santa Maria del Mar

        // Batam
        "batam-hang-nadim-t2": "Hang Nadim International Airport",   // Hang Nadim Terminal 2

        // Bath
        "uk_green_park_station": "Bath Green Park railway station",  // Green Park Station
        "uk_prior_park": "Prior Park",                               // Prior Park Mansion
        "uk_the_circus": "The Circus, Bath",                         // The Circus
        "uk_roman_baths": "Roman Baths (Bath)",                      // The Roman Baths

        // Beijing
        "pek_citic_tower": "China Zun",                              // CITIC Tower (China Zun)
        "pek_national_theatre": "National Centre for the Performing Arts (China)", // National Centre for the Performing Arts
        "pek_white_pagoda": "Miaoying Temple",                       // White Dagoba (Miaoying Temple)

        // Berlin
        "ber_chancellery": "Federal Chancellery of Germany",         // Federal Chancellery
        "ber_james_simon_galerie": "James Simon Gallery",            // James-Simon-Galerie

        // Bogotá
        "bogota-gold-museum": "Gold Museum, Bogotá",                 // Gold Museum (Bogotá)
        "bogota-la-candelaria": "La Candelaria, Bogotá",             // La Candelaria
        "bogota-museo-nacional": "National Museum of Colombia",      // Museo Nacional de Colombia

        // Boston
        "bos-15": "Federal Reserve Bank Building (Boston)",          // Federal Reserve Bank Building
        "bos-13": "Institute of Contemporary Art, Boston",           // Institute of Contemporary Art
        "bos-04": "Old State House (Boston)",                        // Old State House
        "bos-06": "Trinity Church (Boston)",                         // Trinity Church

        // Brasília
        "br_jk_memorial": "JK Memorial",                             // Memorial JK
        "br_pantheon_liberty": "Tancredo Neves Pantheon of the Fatherland and Freedom", // Pantheon of Liberty and Democracy

        // Brisbane
        "au_goma_brisbane": "Queensland Gallery of Modern Art",      // GOMA - Gallery of Modern Art, Brisbane

        // Budapest
        "budapest-szechenyi-bath": "Széchenyi thermal bath",         // Széchenyi Thermal Bath

        // Buffalo
        "buf_grain_elevators": "Concrete-Central Elevator",          // Concrete Central Grain Elevator
        "buf_guaranty_building": "Prudential Building (Buffalo, New York)", // Guaranty Building
        "buf_old_post_office": "Old Post Office (Buffalo, New York)", // Old Post Office (ECC City Campus)

        // Cairo
        "cai_iconic_tower": "Iconic Tower (Egypt)",                  // Iconic Tower

        // Cape Town
        "groot-constantia-manor": "Groot Constantia",                // Groot Constantia Manor House

        // Cartagena
        "co_cartagena_cathedral": "Cartagena Cathedral, Colombia",   // Cartagena Cathedral

        // Central Jakarta
        "jakarta-istiqlal": "Istiqlal Mosque, Jakarta",              // Istiqlal Mosque

        // Chengdu
        "cn_jinli_ancient_street": "Jinli",                          // Jinli Ancient Street

        // Chicago
        "chi-03": "875 North Michigan Avenue",                       // 875 North Michigan
        "chi-07": "Aqua (Chicago)",                                  // Aqua Tower
        "chi-06": "Rookery Building",                                // The Rookery

        // Cleveland
        "cle-04": "Guardian Bank Building",                          // Guardian Building (668 Euclid)
        "cle-10": "Museum of Contemporary Art Cleveland",            // Museum of Contemporary Art (MOCA)
        "cle-03": "Cleveland Arcade",                                // The Arcade

        // Colombo
        "lk_independence_memorial_hall": "Independence Memorial Hall", // Independence Memorial Hall, Colombo

        // Copenhagen
        "cph_blox": "Danish Architecture Centre",                    // BLOX (Danish Architecture Center)
        "cph_superkilen": "Superkilen",                              // Superkilen Park (Red Square)
        "cph_black_diamond": "Black Diamond (library)",              // The Black Diamond
        "cph_silo": "The Silo (Copenhagen)",                         // The Silo

        // Cork
        "crk-07": "Blackrock Castle",                                // Blackrock Castle Observatory
        "crk-11": "The Custom House, Cork",                          // Custom House (Port of Cork)

        // Cupertino
        "cup_mcclellan_ranch": "McClellan Ranch Preserve",           // McClellan Ranch Milk Barn

        // Curitiba
        "cwb-cathedral-basilica": "Cathedral Basilica Minor of Our Lady of Light, Curitiba", // Cathedral Basilica of Curitiba

        // Dakar
        "sn_grande_mosquee_dakar": "Grand Mosque of Dakar",          // Grande Mosquée de Dakar

        // Dallas
        "dal_bank_of_america": "Bank of America Plaza (Dallas)",     // Bank of America Plaza
        "dal_chase_tower": "Chase Tower (Dallas)",                   // Chase Tower
        "dal_jfk_memorial": "John Fitzgerald Kennedy Memorial",      // John F. Kennedy Memorial
        "dal_old_red": "Old Red Museum",                             // Old Red Courthouse

        // Denver
        "den-09": "Brown Palace Hotel (Denver)",                     // The Brown Palace Hotel
        "den-01": "Wells Fargo Center (Denver)",                     // Wells Fargo Center

        // Detroit
        "detroit_fox_theatre": "Fox Theatre (Detroit)",              // Fox Theatre
        "detroit_lafayette_towers": "Lafayette Towers Apartments East", // Lafayette Towers
        "detroit_michigan_central": "Michigan Central Station",      // Michigan Central
        "detroit_book_cadillac": "Westin Book Cadillac Hotel",       // Westin Book Cadillac

        // Dhaka
        "bd_shaheed_minar": "Shaheed Minar, Dhaka",                  // Shaheed Minar

        // Doha
        "doha-the-pearl": "The Pearl Island",                        // The Pearl, Qatar

        // Dubai
        "dxb_jumeirah_emirates": "Emirates Towers",                  // Jumeirah Emirates Towers
        "dxb_index_tower": "The Index (Dubai)",                      // The Index

        // Fortaleza
        "for-dragao-do-mar": "Dragão do Mar Center of Art and Culture", // Dragão do Mar Center

        // Guadalajara
        "mx_guadalajara_cathedral": "Guadalajara Cathedral",         // Guadalajara Metropolitan Cathedral

        // Havana
        "havana-morro-castle": "Castillo de los Tres Reyes Del Morro", // Morro Castle

        // Hong Kong
        "hk_bank_of_china": "Bank of China Tower (Hong Kong)",       // Bank of China Tower
        "hk_convention_centre": "Hong Kong Convention and Exhibition Centre", // HK Convention and Exhibition Centre
        "hk_lippo_centre": "Lippo Centre (Hong Kong)",               // Lippo Centre

        // Honolulu
        "hnl-06": "IBM Building (Honolulu)",                         // IBM Building

        // Houston
        "hou-07": "TC Energy Center",                                // Bank of America Center
        "hou-01": "JPMorgan Chase Tower (Houston)",                  // JPMorgan Chase Tower

        // Johannesburg
        "johannesburg-constitution-hill": "Constitution Hill, Johannesburg", // Constitution Hill

        // Kathmandu
        "np_garden_of_dreams": "Garden of Dreams",                   // Garden of Dreams, Kathmandu

        // Kyoto
        "kyo_heian_shrine": "Heian Shrine",                          // Heian Jingu Shrine
        "kyo_kyoto_kyocera_museum": "Kyoto Municipal Museum of Art", // Kyoto City Kyocera Museum of Art

        // Lagos
        "lagos-national-museum": "Nigerian National Museum",         // National Museum Lagos

        // Las Vegas
        "lv_circus_circus": "Circus Circus Las Vegas",               // Circus Circus Adventuredome
        "lv_encore": "Encore Las Vegas",                             // Encore at Wynn Las Vegas
        "lv_strator": "The Strat",                                   // The STRAT Hotel & Tower

        // Lima
        "convent-of-san-francisco": "Basilica and Convent of San Francisco, Lima", // Convent of San Francisco
        "palacio-de-gobierno": "Government Palace, Peru",            // Government Palace
        "utec-campus": "University of Engineering and Technology (Peru)", // UTEC Campus

        // Lisbon
        "portugal-pavilion": "Pavilhão de Portugal",                 // Portugal Pavilion

        // London
        "natural-history-museum": "Natural History Museum, London",  // Natural History Museum

        // Los Angeles
        "la_binoculars_building": "Binoculars Building",             // Chiat/Day 'Binoculars' Building
        "la_union_station": "Los Angeles Union Station",             // Union Station

        // Manaus
        "mao-rio-negro-palace": "Palácio Rio Negro, Manaus",         // Palácio Rio Negro

        // Manila
        "manila-national-museum-fine-arts": "National Museum of Fine Arts (Manila)", // National Museum of Fine Arts (Philippines)

        // Marrakech
        "yves-saint-laurent-museum": "Yves Saint Laurent Museum in Marrakesh", // Musée Yves Saint Laurent

        // Medellín
        "co_jardin_botanico_medellin": "Botanical Garden of Medellín", // Jardín Botánico de Medellín
        "co_metrocable_medellin": "Metrocable (Medellín)",           // Metrocable Medellín
        "co_plaza_botero": "Botero Plaza",                           // Plaza Botero

        // Miami
        "mia-06": "Bacardi Buildings (Miami)",                       // Bacardi Building
        "mia-01": "Freedom Tower (Miami)",                           // Freedom Tower

        // Milan
        "mil_feltrinelli": "Feltrinelli Porta Volta",                // Fondazione Feltrinelli
        "mil_triennale": "Triennale di Milano",                      // Palazzo dell'Arte (Triennale)

        // Minnesota
        "msp-13": "Basilica of Saint Mary (Minneapolis)",            // Basilica of Saint Mary
        "msp-03": "Cathedral of Saint Paul (Minnesota)",             // Cathedral of Saint Paul
        "msp-08": "Landmark Center (St. Paul)",                      // Landmark Center

        // Montreal
        "notre-dame-basilica": "Notre-Dame Basilica (Montreal)",     // Notre-Dame Basilica
        "montreal_schwartzs_deli": "Schwartz's",                     // Schwartz’s Deli

        // Mumbai
        "bom_t2_terminal": "Chhatrapati Shivaji Maharaj International Airport", // Chhatrapati Shivaji Maharaj T2
        "bom_national_gallery": "National Gallery of Modern Art, Mumbai", // NGMA (Sir Cowasji Jehangir Hall)

        // Nairobi
        "gtc-office-tower": "Nairobi GTC Office Tower",              // GTC Office Tower

        // Naples
        "nap-10": "Santa Chiara, Naples",                            // Basilica di Santa Chiara
        "nap-06": "Toledo station (Naples)",                         // Toledo Metro Station

        // Nashville
        "nsh_batman_building": "AT&T Building (Nashville)",          // AT&T Building
        "nsh_belmont_mansion": "Belmont Mansion (Tennessee)",        // Belmont Mansion
        "nsh_pinnacle_tower": "Symphony Place",                      // Pinnacle at Symphony Place
        "nsh_the_parthenon": "Parthenon (Nashville)",                // The Parthenon
        "nsh_union_station": "Union Station (Nashville)",            // Union Station Hotel

        // New Orleans
        "nola_contemporary_arts_center": "Contemporary Arts Center (New Orleans)", // Contemporary Arts Center
        "nola_st_louis_cathedral": "St. Louis Cathedral (New Orleans)", // St. Louis Cathedral
        "nola_custom_house": "United States Custom House (New Orleans)", // U.S. Custom House

        // New York
        "nyc_oculus": "World Trade Center station (PATH)",           // The Oculus
        "nyc-09": "Vessel (structure)",                              // The Vessel (Hudson Yards)

        // Nice
        "fr_matisse_museum_nice": "Musée Matisse (Nice)",            // Matisse Museum

        // Orlando
        "orl_lake_eola_pagoda": "Lake Eola Park",                    // Chinese Pagoda at Lake Eola

        // Paris
        "paris-sacre-coeur": "Sacré-Cœur, Paris",                    // Sacré-Cœur Basilica

        // Philadelphia
        "phi-13": "Masonic Temple (Philadelphia)",                   // Masonic Temple of Philadelphia

        // Phoenix
        "phx-05": "Chase Tower (Phoenix)",                           // Chase Tower
        "phx-09": "Orpheum Theatre (Phoenix, Arizona)",              // Orpheum Theatre
        "phx-08": "Arizona Science Center",                          // Science Center (Dorrance Planetarium)
        "phx-13": "St. Mary's Basilica (Phoenix)",                   // St. Mary's Basilica
        "phx-12": "Westward Ho (Phoenix, Arizona)",                  // Westward Ho

        // Pittsburgh
        "pit-06": "Union Trust Building (Pittsburgh)",               // Union Trust Building

        // Portland
        "pdx_custom_house": "United States Custom House (Portland, Oregon)", // Custom House
        "pdx_commonwealth_building": "Commonwealth Building (Portland, Oregon)", // The Commonwealth Building
        "pdx_union_station": "Portland Union Station",               // Union Station
        "pdx_wells_fargo": "Wells Fargo Center (Portland, Oregon)",  // Wells Fargo Center

        // Porto Alegre
        "poa-farol-santander": "Farol Santander Porto Alegre",       // Farol Santander (Old Guardianship Bank)
        "poa-piratini": "Piratini Palace",                           // Palácio Piratini
        "poa-theatro-sao-pedro": "São Pedro Theatre",                // Theatro São Pedro
        "poa-viaduto-otavio-rocha": "Otávio Rocha Viaduct",          // Viaduto Otávio Rocha

        // Quebec City
        "ca_petit_champlain": "Petit Champlain",                     // Quartier Petit-Champlain

        // Reykjavik
        "is_blue_lagoon_iceland": "Blue Lagoon (geothermal spa)",    // Blue Lagoon Iceland

        // Rio de Janeiro
        "rio-christ-redeemer": "Christ the Redeemer (statue)",       // Christ the Redeemer
        "rio-cathedral": "Rio de Janeiro Cathedral",                 // Metropolitan Cathedral of Saint Sebastian
        "rio-teatro-municipal": "Theatro Municipal (Rio de Janeiro)", // Municipal Theatre
        "rio-mam": "Museum of Modern Art, Rio de Janeiro",           // Museum of Modern Art (MAM Rio)

        // Riyadh
        "ruh-03": "Al Faisaliah Tower",                              // Al Faisaliah Center
        "ruh-02": "Al Masmak Palace",                                // Al Masmak Fortress
        "ruh-09": "KAFD metro station",                              // KAFD Metro Station
        "ruh-11": "Public Investment Fund Tower",                    // PIF Tower

        // Rome
        "rom_maxxi": "MAXXI",                                        // MAXXI Museum

        // San Francisco
        "sf-03": "San Francisco Ferry Building",                     // Ferry Building
        "sf_grace_cathedral": "Grace Cathedral, San Francisco",      // Grace Cathedral
        "sf-16": "Japanese Tea Garden (San Francisco)",              // Japanese Tea Garden
        "sf-20": "Levi's Plaza",                                     // Levi’s Plaza
        "sf-12": "Lombard Street (San Francisco)",                   // Lombard Street
        "sf-07": "Cathedral of Saint Mary of the Assumption (San Francisco)", // Saint Mary's Cathedral
        "sf-19": "Columbus Tower (San Francisco)",                   // Sentinel Building (Columbus Tower)

        // Santiago
        "bahai-temple-south-america": "Santiago Bahá'í Temple",      // Bahá'í Temple of South America
        "gabriela-mistral-cultural-center": "Centro Cultural Gabriela Mistral", // GAM (Gabriela Mistral Cultural Center)
        "museo-historico-nacional": "Museo Histórico Nacional (Chile)", // National History Museum

        // Seoul
        "ewha-campus-center": "Ewha Womans University",              // Ewha Womans University Campus Center
        "gt-tower-east": "Seocho Garak Tower East",                  // GT Tower East

        // Seville
        "es_real_alcazar_seville": "Alcázar of Seville",             // Real Alcázar of Seville

        // Shanghai
        "sha_china_art": "China Art Museum (Shanghai)",              // China Art Museum
        "sha_customs_house": "Custom House, Shanghai",               // Customs House
        "sha_peace_hotel": "Peace Hotel",                            // Fairmont Peace Hotel
        "sha_jingan_temple": "Jing'an Temple",                       // Jing’an Temple

        // Singapore
        "sg_parkroyal_pickering": "Parkroyal Collection Pickering",  // PARKROYAL COLLECTION Pickering
        "sg_victoria_theatre": "Victoria Theatre and Concert Hall",  // Victoria Theatre & Concert Hall

        // St. Louis
        "stl-05": "City Museum (St. Louis, Missouri)",               // City Museum
        "stl-07": "Fox Theatre (St. Louis)",                         // The Fox Theatre
        "stl-13": "Jewel Box (St. Louis)",                           // The Jewel Box
        "stl-11": "Old Courthouse (St. Louis)",                      // The Old Courthouse

        // Surabaya
        "sub-cheng-hoo-mosque": "Cheng Ho Mosque (Surabaya)",        // Cheng Hoo Mosque
        "sub-al-akbar-mosque": "Al-Akbar Mosque",                    // Masjid Nasional Al-Akbar
        "sub-tunjungan-plaza": "Tunjungan Plaza",                    // Tunjungan Plaza 6

        // Sydney
        "syd_customs_house": "Customs House, Sydney",                // Customs House
        "syd_mca": "Museum of Contemporary Art Australia",           // Museum of Contemporary Art (MCA)
        "syd_anitpodes_tower": "Salesforce Tower (Sydney)",          // Salesforce Tower (Sydney Place)
        "syd_st_marys": "St Mary's Cathedral, Sydney",               // St Mary's Cathedral

        // São Paulo
        "br_altino_arantes": "Altino Arantes Building",              // Farol Santander (Altino Arantes Building)
        "br_masp": "São Paulo Museum of Art",                        // MASP (São Paulo Museum of Art)
        "br_sesc_pompeia": "SESC Pompeia",                           // SESC Pompéia

        // Taipei
        "taipei-longshan-temple": "Longshan Temple (Taipei)",        // Longshan Temple, Taipei
        "taipei-elephant-mountain": "Xiangshan, Taipei",             // Xiangshan (Taipei)

        // Tangerang
        "tng-al-adzhom": "Al-Azhom Grand Mosque",                    // Al-Adzhom Grand Mosque
        "tng-soekarno-hatta-t3": "Soekarno–Hatta International Airport", // Soekarno-Hatta Terminal 3

        // Tel Aviv
        "tlv_great_synagogue": "Great Synagogue (Tel Aviv)",         // Great Synagogue
        "tlv_independence_hall": "Independence Hall (Israel)",       // Independence Hall (Dizengoff House)
        "tlv_opera_tower": "Opera Tower (Tel Aviv)",                 // Opera Tower

        // Tokyo
        "meiji-jingu": "Meiji Shrine",                               // Meiji Jingu Shrine
        "sensoji-temple": "Sensō-ji",                                // Sensō-ji Temple (Main Hall)

        // Toronto
        "brookfield-place": "Brookfield Place (Toronto)",            // Brookfield Place (Allen Lambert Galleria)
        "old-city-hall-toronto": "Old City Hall (Toronto)",          // Old City Hall

        // Vancouver
        "yvr-15": "Westcoast Building",                              // The Qube
        "yvr-14": "Woodward's Building",                             // Woodward’s Building

        // Victoria
        "vic-11": "Christ Church Cathedral (Victoria, British Columbia)", // Christ Church Cathedral
        "vic-15": "Market Square, Victoria",                         // Market Square
        "vic-07": "St. Andrew's Cathedral (Victoria, British Columbia)", // St. Andrew’s Cathedral
        "vic-09": "Old Victoria Custom House",                       // The Customs House
        "vic-06": "Greater Victoria Public Library",                 // Victoria Public Library (Central)

        // Vienna
        "dc-tower-1": "DC Towers",                                   // DC Tower 1
        "stephansdom": "St. Stephen's Cathedral, Vienna",            // St. Stephen's Cathedral

        // Washington D.C.
        "dc-06": "Washington National Cathedral",                    // National Cathedral
        "dc-08": "Washington Union Station",                         // Union Station DC

        // Xi'an
        "cn_muslim_quarter_xian": "Xi'an Muslim Quarter",            // Muslim Quarter, Xi'an

        // Zanzibar
        "tz_old_fort_zanzibar": "Old Fort of Zanzibar",              // Old Fort, Zanzibar
        "tz_stone_town": "Stone Town",                               // Stone Town, Zanzibar City
    ]

    /// Building IDs whose name only matches a *different* place on Wikipedia, and that
    /// have no article of their own. The app shows its placeholder instead of the wrong photo.
    nonisolated static let skipWikipedia: Set<String> = [
        "for-estoril",          // Fortaleza / Estoril: Wikipedia has Estoril, Portugal
        "mia-03",               // Miami / The Carlyle: Wikipedia has the New York hotel
        "orl_suntrust_center",  // Orlando / Truist Plaza (SunTrust Center): Wikipedia has Atlanta's
        "vic-10",               // Victoria / Mayfair Shopping Centre: falls back to the city article
    ]
}

// MARK: - Decodable response shape

nonisolated private struct WikiAPIResponse: Decodable {
    let thumbnail: WikiImage?
    let originalimage: WikiImage?
    let extract: String?
}

nonisolated private struct WikiImage: Decodable {
    let source: String?
}

nonisolated private struct WikiMediaList: Decodable {
    let items: [Item]
    struct Item: Decodable {
        let type: String?
        let srcset: [Source]?
    }
    struct Source: Decodable {
        let src: String
    }
}
