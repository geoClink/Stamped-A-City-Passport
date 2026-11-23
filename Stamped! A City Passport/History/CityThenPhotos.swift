//
//  CityThenPhotos.swift
//  Stamped! A City Passport
//
//  One old, wide view of each city (a panorama, skyline or bird's-eye view), bundled in
//  Resources/CityThenArchives as cityThen_<slug>.jpg. The city page's header can fade from
//  today's photo to this one. Every image is public domain, CC0, CC BY/BY-SA or "no known
//  restrictions" and is credited and linked to its source page.
//

import Foundation

nonisolated enum CityThenPhotos {
    struct Photo: Equatable {
        let file: String
        /// "Paris from the Eiffel Tower, ca. 1900"
        let caption: String
        /// The year shown on the toggle, e.g. "1900"
        let year: String
        let credit: String
        let link: URL

        /// The bundled file, or nil if it is missing from this build
        func url(in bundle: Bundle = .main) -> URL? {
            bundle.url(forResource: file, withExtension: "jpg")
        }
    }

    /// The old view of a city (keyed by its display name), or nil when there is none
    static func photo(forCity name: String) -> Photo? { photos[name] }

    /// How many cities have an old view (for tests)
    static var count: Int { photos.count }

    // BEGIN cityThen (generated from the reviewed city manifest; edit the manifest, not this block)
    private static let photos: [String: Photo] = [
        "Amman": Photo(file: "cityThen_amman", caption: "General view of Amman, 1898", year: "1898", credit: "Library of Congress, Matson Collection", link: URL(string: "https://commons.wikimedia.org/wiki/File:East_of_Jordan_and_the_Dead_Sea._General_view_of_%27Amman_LOC_matpc.06960.jpg")!),
        "Amsterdam": Photo(file: "cityThen_amsterdam", caption: "The Westerkerk by the canal, painted by Jan van der Heyden, 1660", year: "1660", credit: "Jan van der Heyden · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:View_of_the_Westerkerk_Amsterdam_1660_Jan_van_der_Heyden.jpg")!),
        "Antwerp": Photo(file: "cityThen_antwerp", caption: "Antwerp and the Scheldt from above, ca. 1890", year: "1890", credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://commons.wikimedia.org/wiki/File:General_view,_I,_Antwerp,_Belgium-LCCN2001697872.jpg")!),
        "Athens": Photo(file: "cityThen_athens", caption: "The Acropolis above Athens, 1904", year: "1904", credit: "Alexander Lamont Henderson · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Henderson,_Alexander_Lamont_(1838-1907)_-_Athens_Panorama_1904_2.jpg")!),
        "Auckland": Photo(file: "cityThen_auckland", caption: "Auckland waterfront, 1913", year: "1913", credit: "Henry Winkelmann · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Panorama_of_Auckland_waterfront,_1996A.jpg")!),
        "Bangkok": Photo(file: "cityThen_bangkok", caption: "General view of Bangkok, ca. 1883", year: "1883", credit: "W. G. Blackie · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:General_View_of_Bangkok_c1883_by_W_G_Blackie.png")!),
        "Bath": Photo(file: "cityThen_bath", caption: "South view of Bath, by John Robert Cozens, 1773", year: "1773", credit: "Yale Center for British Art · CC0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:John_Robert_Cozens_-_South_View_of_Bath_-_B1985.36.1317_-_Yale_Center_for_British_Art.jpg")!),
        "Berlin": Photo(file: "cityThen_berlin", caption: "Berlin from the roof of the Friedrichswerder Church, by Eduard Gaertner, 1834", year: "1834", credit: "Eduard Gaertner · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Panorama_von_Berlin_vom_Dach_der_Friedrichswerderschen_Kirche_aus_1.jpg")!),
        "Bilbao": Photo(file: "cityThen_bilbao", caption: "El Arenal in Bilbao, by Luis Paret, 1783", year: "1783", credit: "Luis Paret y Alcázar · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Luis_Paret_-_View_of_El_Arenal_in_Bilbao_-_Google_Art_Project.jpg")!),
        "Bogotá": Photo(file: "cityThen_bogota", caption: "Southern panorama of Bogotá, postcard ca. 1910", year: "1910", credit: "Librería Colombiana · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Postal_-_Bogot%C3%A1_-_Panorama_sur_de_Bogot%C3%A1.jpg")!),
        "Brussels": Photo(file: "cityThen_brussels", caption: "View of Brussels, by Theodoor van Heil, ca. 1650", year: "1650", credit: "Theodoor van Heil, Hermitage Museum · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Theodoor_van_Heil_-_View_of_Brussels_(Hermitage).jpg")!),
        "Cairo": Photo(file: "cityThen_cairo", caption: "Panorama of Cairo, ca. 1860", year: "1860", credit: "Wilhelm Hammerschmidt · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Cairo-_Panorama,_No._1_(SM_stf981).png")!),
        "Cape Town": Photo(file: "cityThen_cape_town", caption: "Cape Town and Table Mountain from Table Bay, by Thomas Whitcombe, 1818", year: "1818", credit: "Thomas Whitcombe · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Thomas_Whitcombe_-_View_of_Cape_Town,_Table_Bay,_Cape_of_Good_Hope.jpg")!),
        "Colombo": Photo(file: "cityThen_colombo", caption: "A street in Colombo, ca. 1870", year: "1870", credit: "Rijksmuseum · CC0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Straatgezicht_in_Colombo,_RP-F-F18411.jpg")!),
        "Copenhagen": Photo(file: "cityThen_copenhagen", caption: "Copenhagen from above, ca. 1890", year: "1890", credit: "Detroit Photographic Co. · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:General_view,_Copenhagen,_Denmark.jpg")!),
        "Denver": Photo(file: "cityThen_denver", caption: "Denver and the Rocky Mountains, 1898", year: "1898", credit: "William Henry Jackson · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Panorama_of_Denver,_Colorado,_1898.jpg")!),
        "Detroit": Photo(file: "cityThen_detroit", caption: "Detroit from the Majestic Building, ca. 1900", year: "1900", credit: "Detroit Publishing Co., NYPL · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Panorama_from_Majestic_Building,_Detroit,_Mich_(NYPL_b12647398-68334).tiff")!),
        "Edinburgh": Photo(file: "cityThen_edinburgh", caption: "Edinburgh Castle from the Grassmarket, ca. 1870", year: "1870", credit: "George Washington Wilson · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Edinburgh_Castle_from_Grass_Market.jpg")!),
        "Florence": Photo(file: "cityThen_florence", caption: "A general view of Florence, ca. 1750", year: "1750", credit: "Rijksmuseum · CC0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Gezicht_op_de_stad_Florence_A_general_view_of_Florence,_taken_from_the_convent_of_the_capuchin_friars_(titel_op_object)_Florence_(serietitel),_RP-P-1932-447.jpg")!),
        "Fort Worth": Photo(file: "cityThen_fort_worth", caption: "Bird's-eye view of Fort Worth, postcard ca. 1915", year: "1915", credit: "Frey Wholesale Post Card Co. · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Bird%27s_Eye_View_of_Fort_Worth_(20106782).jpg")!),
        "Glasgow": Photo(file: "cityThen_glasgow", caption: "Glasgow and the Clyde, 1883", year: "1883", credit: "Paterson, 1883 · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:PATERSON(1883)_p006_GLASGOW_-_GENERAL_VIEW.jpg")!),
        "Granada": Photo(file: "cityThen_granada", caption: "The Alhambra and Granada from the Silla del Moro, ca. 1899", year: "1899", credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://commons.wikimedia.org/wiki/File:Granada._Vista_general_de_la_Alhambra_y_Grandada_desde_la_Silla_del_Moro_LCCN2017660752.jpg")!),
        "Istanbul": Photo(file: "cityThen_istanbul", caption: "Panorama of Istanbul, by Stanisław Chlebowski, ca. 1870", year: "1870", credit: "National Museum in Warsaw · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Stanis%C5%82aw_Chlebowski_-_Panorama_of_Istanbul_-_MP_1067_MNW_-_National_Museum_in_Warsaw.jpg")!),
        "Kuala Lumpur": Photo(file: "cityThen_kuala_lumpur", caption: "Kuala Lumpur, ca. 1884", year: "1884", credit: "G.R. Lambert & Co. · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Panorama_of_Kuala_Lumpur_ca._1884.jpg")!),
        "London": Photo(file: "cityThen_london", caption: "A general view of the City of London and the Thames, ca. 1750", year: "1750", credit: "Unknown British artist · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:General_view_of_City_of_London_16C.jpg")!),
        "Madrid": Photo(file: "cityThen_madrid", caption: "The Royal Palace of Madrid, by Antonio Joli, ca. 1753", year: "1753", credit: "Antonio Joli · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Antonio_Joli_P._Real_Madrid_ca.1753.jpg")!),
        "Marrakech": Photo(file: "cityThen_marrakech", caption: "Marrakech from the museum roof, 1936", year: "1936", credit: "Leo Wehrli, ETH-Bibliothek Zürich · CC BY-SA 4.0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:ETH-BIB-Marrakech,_Panorama,_vom_Museums-Dach,_nach_S%C3%BCdosten_(SE)_I-Dia_247-09090.tif")!),
        "Marseille": Photo(file: "cityThen_marseille", caption: "Marseille from Notre-Dame de la Garde, ca. 1895", year: "1895", credit: "trialsanderrors on Flickr · CC BY 2.0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Flickr_-_%E2%80%A6trialsanderrors_-_Marseille_viewed_from_Notre_Dame_de_la_Garde,_ca._1895.jpg")!),
        "Miami": Photo(file: "cityThen_miami", caption: "Air view of Miami Beach, postcard ca. 1948", year: "1948", credit: "Tichnor Brothers · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Florida_-_Air_view_of_Miami_Beach.jpg")!),
        "Milan": Photo(file: "cityThen_milan", caption: "Piazza del Duomo from the cathedral, Milan, ca. 1890", year: "1890", credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://commons.wikimedia.org/wiki/File:Panorama_from_the_cathedral,_Milan,_Italy-LCCN2001700885.jpg")!),
        "Montreal": Photo(file: "cityThen_montreal", caption: "An east view of Montreal, by Pierre-Charles Canot, 1762", year: "1762", credit: "Pierre-Charles Canot · CC0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Pierre-Charles_Canot_-_Views_of_Montreal_and_Louisburg,_An_East_View_of_Montreal_in_Canada_-_B2001.2.1499_-_Yale_Center_for_British_Art.jpg")!),
        "Naples": Photo(file: "cityThen_naples", caption: "Naples and Vesuvius from the Vomero, ca. 1870", year: "1870", credit: "Giorgio Sommer · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Panorama_du_Vomero_-_Naples.jpg")!),
        "Paris": Photo(file: "cityThen_paris", caption: "Paris and Notre-Dame from the Tour Saint-Jacques, ca. 1865", year: "1865", credit: "Charles Soulier · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Charles_Soulier,_Panorama_de_Paris_-_Pris_de_la_tour_Saint_Jacques,_ca._1865.jpg")!),
        "Pittsburgh": Photo(file: "cityThen_pittsburgh", caption: "Bird's-eye view of Pittsburgh, by Thaddeus M. Fowler, 1902", year: "1902", credit: "Thaddeus M. Fowler · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Thaddeus_M._Fowler_-_Pittsburgh,_Pennsylvania_1902.jpg")!),
        "Portland": Photo(file: "cityThen_portland", caption: "Portland, Oregon, 1888", year: "1888", credit: "C.L. Smith · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Portland,_Oregon_Panorama_1888.jpg")!),
        "Prague": Photo(file: "cityThen_prague", caption: "Prague Castle and the Old Town skyline, ca. 1926", year: "1926", credit: "Unknown photographer · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:View_of_Prague,_c1926.jpg")!),
        "Quebec City": Photo(file: "cityThen_quebec_city", caption: "A general view of Quebec from Point Levy, 1761", year: "1761", credit: "P. Canot after Richard Short · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:A_General_View_of_Quebec,_from_Point_Levy.png")!),
        "Queenstown": Photo(file: "cityThen_queenstown", caption: "Queenstown and Lake Wakatipu, 1904", year: "1904", credit: "Melvin Vanniman · CC0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Queenstown_1904_-_Melvin_Vanniman.jpg")!),
        "Riga": Photo(file: "cityThen_riga", caption: "Riga from the Daugava quay, ca. 1890", year: "1890", credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://commons.wikimedia.org/wiki/File:Panorama_by_the_quay,_Riga,_1890s.jpg")!),
        "Rome": Photo(file: "cityThen_rome", caption: "Piazza del Popolo from the Pincian Hill, Rome, ca. 1895", year: "1895", credit: "trialsanderrors on Flickr · CC BY 2.0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Flickr_-_%E2%80%A6trialsanderrors_-_Panorama_from_the_Pincian,_Rome,_Italy,_ca._1895.jpg")!),
        "Rotterdam": Photo(file: "cityThen_rotterdam", caption: "Rotterdam from the Maas, by Caspar Merian, 1659", year: "1659", credit: "Caspar Merian · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Rotterdam_Panorama_by_Caspar_Merian_1659.jpg")!),
        "Salzburg": Photo(file: "cityThen_salzburg", caption: "Salzburg and the Salzach, ca. 1890", year: "1890", credit: "Library of Congress, Photochrom Print Collection", link: URL(string: "https://commons.wikimedia.org/wiki/File:Salzburg,_general_view,_Austro-Hungary-LCCN2002710946.jpg")!),
        "San Diego": Photo(file: "cityThen_san_diego", caption: "San Diego and the bay, postcard 1903", year: "1903", credit: "Brück & Sohn Kunstverlag · CC0 · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:03988-San_Diego-1903-Panorama_San_Diego_and_Bay-Br%C3%BCck_%26_Sohn_Kunstverlag.jpg")!),
        "Seoul": Photo(file: "cityThen_seoul", caption: "Downtown Seoul from the city wall, early 1900s", year: "1902", credit: "Government-General of Chosen · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:View_of_Downtown_Keij%C5%8D_from_Seoul_City_Wall_around_early_1900s.jpg")!),
        "Seville": Photo(file: "cityThen_seville", caption: "A view of Seville from the Guadalquivir, by Manuel Barrón, 1846", year: "1846", credit: "Manuel Barrón y Carrillo · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Manuel_Barr%C3%B3n_y_Carrillo_(1814-1884)_-_A_View_of_Seville,_from_the_Guadalquivir_River_with_the_Giralda_Tower_-_20898_-_National_Trust.jpg")!),
        "Shanghai": Photo(file: "cityThen_shanghai", caption: "The Bund, Shanghai, 1927", year: "1927", credit: "Shanghai of Today (1927) · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Shanghai_of_Today,_Plate_6_-_Panorama_of_Bund.jpg")!),
        "Stockholm": Photo(file: "cityThen_stockholm", caption: "Bird's-eye view of Stockholm, by Carl Johan Billmark, 1868", year: "1868", credit: "Carl Johan Billmark · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Stockholm_panorama_1868.jpg")!),
        "Tbilisi": Photo(file: "cityThen_tbilisi", caption: "Tbilisi, ca. 1890–1910", year: "1890", credit: "Dmitri Yermakov · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Tbilisi,_general_view,_ca_1890-1910.jpg")!),
        "Tel Aviv": Photo(file: "cityThen_tel_aviv", caption: "Rothschild Boulevard, Tel Aviv, 1940s", year: "1940", credit: "Library of Congress, Matson Photograph Collection", link: URL(string: "https://commons.wikimedia.org/wiki/File:Tel_Aviv._Rothchild_Ave_1940-46.jpg")!),
        "Toronto": Photo(file: "cityThen_toronto", caption: "Toronto from above, 1856", year: "1856", credit: "Armstrong, Beere & Hime · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Toronto_1856_-_7.jpg")!),
        "Vienna": Photo(file: "cityThen_vienna", caption: "Vienna from the Belvedere, by Bernardo Bellotto, ca. 1759", year: "1759", credit: "Bernardo Bellotto · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Bernardo_Bellotto,_il_Canaletto_-_View_of_Vienna_from_the_Belvedere.jpg")!),
        "Warsaw": Photo(file: "cityThen_warsaw", caption: "Warsaw from the Royal Castle, by Bernardo Bellotto, 1773", year: "1773", credit: "Bernardo Bellotto · Public domain · Wikimedia Commons", link: URL(string: "https://commons.wikimedia.org/wiki/File:Bernardo_Bellotto_-_View_of_Warsaw_from_the_Royal_Castle_-_Google_Art_Project.jpg")!),
    ]
    // END cityThen
}
