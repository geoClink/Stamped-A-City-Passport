//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import Foundation
import SwiftUI

struct CityLocation: Hashable, Sendable {
    
    enum Continent: String, CaseIterable, Hashable, Sendable, Comparable {
        case africa = "Africa"
        case asia = "Asia"
        case europe = "Europe"
        case northAmerica = "North America"
        case oceania = "Oceania"
        case southAmerica = "South America"

        static func < (lhs: Continent, rhs: Continent) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    enum Country: String, CaseIterable, Hashable, Sendable {
        case unitedStates = "United States", brazil = "Brazil", indonesia = "Indonesia", singapore = "Singapore"
        case italy = "Italy", saudiArabia = "Saudi Arabia", southkorea = "South Korea", newSouthWales = "New South Wales", egypt = "Egypt"
        case canada = "Canada", england = "England", uae = "United Arab Emirates", japan = "Japan", france = "France", mexico = "Mexico", sar = "Special Administration Region", denmark = "Denmark", germany = "Germany", netherlands = "Netherlands", israel = "Israel", china = "China", thailand = "Thailand", india = "India", spain = "Spain", ireland = "Ireland", turkey = "Turkey"
        case argentina = "Argentina", peru = "Peru", chile = "Chile", southAfrica = "South Africa", kenya = "Kenya", morocco = "Morocco", newZealand = "New Zealand", czechRepublic = "Czech Republic", austria = "Austria", portugal = "Portugal", victoria = "Victoria"
        case yemen = "Yemen"
        case greece = "Greece", hungary = "Hungary", scotland = "Scotland"
        case taiwan = "Taiwan", malaysia = "Malaysia", vietnam = "Vietnam"
        case switzerland = "Switzerland", sweden = "Sweden", colombia = "Colombia"
        case nigeria = "Nigeria", ghana = "Ghana", ethiopia = "Ethiopia"
        case qatar = "Qatar", jordan = "Jordan", oman = "Oman", philippines = "Philippines"
        case norway = "Norway", finland = "Finland", belgium = "Belgium", poland = "Poland"
        case cuba = "Cuba"
        case nepal = "Nepal", iceland = "Iceland", russia = "Russia", georgia = "Georgia"
        case sriLanka = "Sri Lanka", senegal = "Senegal", tanzania = "Tanzania", queensland = "Queensland"
        case bangladesh = "Bangladesh"

        var continent: Continent {
            switch self {
            case .unitedStates, .canada, .mexico, .cuba:
                return .northAmerica
            case .brazil, .argentina, .peru, .chile, .colombia:
                return .southAmerica
            case .italy, .england, .france, .denmark, .germany, .netherlands, .spain, .ireland, .turkey, .czechRepublic, .austria, .portugal, .greece, .hungary, .scotland, .switzerland, .sweden, .norway, .finland, .belgium, .poland, .iceland, .russia, .georgia:
                return .europe
            case .singapore, .saudiArabia, .southkorea, .uae, .japan, .sar, .israel, .china, .thailand, .india, .indonesia, .yemen, .taiwan, .malaysia, .vietnam, .qatar, .jordan, .oman, .philippines, .nepal, .sriLanka, .bangladesh:
                return .asia
            case .egypt, .southAfrica, .kenya, .morocco, .nigeria, .ghana, .ethiopia, .senegal, .tanzania:
                return .africa
            case .newSouthWales, .victoria, .newZealand, .queensland:
                return .oceania
            }
        }

        var localGreeting: String {
            switch self {
            case .unitedStates, .canada, .england, .newSouthWales, .victoria, .ireland, .southAfrica, .newZealand, .singapore, .scotland, .nigeria, .ghana, .queensland:
                return "Hello!"
            case .mexico, .spain, .argentina, .peru, .chile, .colombia, .cuba:
                return "¡Hola!"
            case .saudiArabia, .uae, .egypt, .morocco, .yemen, .qatar, .jordan, .oman:
                return "Ahlan! (أهلاً)"
            case .japan:
                return "Konnichiwa! (こんにちは)"
            case .southkorea:
                return "Annyeong! (안녕)"
            case .china, .sar, .taiwan:
                return "Ni Hao! (你好)"
            case .thailand:
                return "Sawasdee! (สวัสดี)"
            case .indonesia:
                return "Halo!"
            case .india, .nepal:
                return "Namaste! (नमस्ते)"
            case .france, .senegal:
                return "Bonjour !"
            case .italy:
                return "Ciao!"
            case .germany, .austria, .switzerland, .belgium:
                return "Hallo!"
            case .netherlands:
                return "Hoi!"
            case .denmark, .sweden:
                return "Hej!"
            case .norway:
                return "Hei!"
            case .turkey:
                return "Merhaba!"
            case .czechRepublic:
                return "Ahoj!"
            case .portugal, .brazil:
                return "Olá!"
            case .israel:
                return "Shalom! (שלום)"
            case .kenya:
                return "Jambo!"
            case .greece:
                return "Yia sas! (Γεια σας)"
            case .hungary:
                return "Szia!"
            case .malaysia:
                return "Apa khabar!"
            case .vietnam:
                return "Xin chào!"
            case .ethiopia:
                return "Selam! (ሰላም)"
            case .philippines:
                return "Kumusta!"
            case .finland:
                return "Moi!"
            case .poland:
                return "Cześć!"
            case .iceland:
                return "Halló!"
            case .russia:
                return "Privet! (Привет)"
            case .georgia:
                return "Gamarjoba! (გამარჯობა)"
            case .sriLanka:
                return "Ayubowan! (ආයුබෝවන්)"
            case .tanzania:
                return "Habari!"
            case .bangladesh:
                return "Assalamualaikum! (আস্সালামু আলাইকুম)"
            }
        }

        var congratsMessage: String {
            switch self {
            case .unitedStates, .canada, .england, .newSouthWales, .victoria, .ireland, .southAfrica, .newZealand, .singapore, .scotland, .nigeria, .ghana, .queensland:
                return "CONGRATULATIONS!"
            case .mexico, .spain, .argentina, .peru, .chile, .colombia, .cuba:
                return "¡FELICITACIONES!"
            case .saudiArabia, .uae, .egypt, .morocco, .yemen, .qatar, .jordan, .oman:
                return "MABROUK! (مبروك)"
            case .japan:
                return "OMEDETOU! (おめでとう)"
            case .southkorea:
                return "CHUKHAHAE! (축하해)"
            case .china, .sar, .taiwan:
                return "GONGXI! (恭喜)"
            case .thailand:
                return "YINDI DUAI! (ยินดีด้วย)"
            case .indonesia:
                return "SELAMAT!"
            case .india:
                return "BADHAAI HO! (बधाई हो)"
            case .nepal:
                return "BADHAI HOS! (बधाई होस्)"
            case .france, .senegal:
                return "FÉLICITATIONS !"
            case .italy:
                return "CONGRATULAZIONI!"
            case .germany, .austria, .switzerland:
                return "GLÜCKWUNSCH!"
            case .belgium:
                return "PROFICIAT!"
            case .netherlands:
                return "GEFELICITEERD!"
            case .denmark:
                return "TILLYKKE!"
            case .sweden:
                return "GRATTIS!"
            case .turkey:
                return "TEBRİKLER!"
            case .czechRepublic:
                return "GRATULACE!"
            case .portugal, .brazil:
                return "PARABÉNS!"
            case .israel:
                return "MAZEL TOV! (מזל טוב)"
            case .kenya, .tanzania:
                return "HONGERA!"
            case .greece:
                return "SYGXARITÍRIA! (ΣΥΓΧΑΡΗΤΉΡΙΑ)"
            case .hungary:
                return "GRATULÁLOK!"
            case .malaysia:
                return "TAHNIAH!"
            case .vietnam:
                return "CHÚC MỪNG!"
            case .ethiopia:
                return "ENKUAN DES ALEH! (እንኳን ደስ አለህ)"
            case .philippines:
                return "MALIGAYANG PAGBATI!"
            case .norway:
                return "GRATULERER!"
            case .finland:
                return "ONNEKSI OLKOON!"
            case .poland:
                return "GRATULACJE!"
            case .iceland:
                return "TIL HAMINGJU!"
            case .russia:
                return "POZDRAVLYAYU! (ПОЗДРАВЛЯЮ)"
            case .georgia:
                return "GAUMARJOS! (გაუმარჯოს)"
            case .sriLanka:
                return "SUBA PATHANAWA! (සුභ පැතීමයි)"
            case .bangladesh:
                return "ABHINANDAN! (অভিনন্দন)"
            }
        }
    }

    public enum City: String, CaseIterable, Hashable, Sendable, Identifiable, Codable {
        case boston = "Boston", chicago = "Chicago", denver = "Denver", detroit = "Detroit", minnesota = "Minnesota", stLouis = "St. Louis", austin = "Austin", cupertino = "Cupertino", asheville = "Asheville"
        case cleveland = "Cleveland", pittsburgh = "Pittsburgh", philadelphia = "Philadelphia"
        case miami = "Miami", seattle = "Seattle", portland = "Portland", orlando = "Orlando", honolulu = "Honolulu"
        case washingtonDC = "Washington D.C.", losangeles = "Los Angeles", dallas = "Dallas", nashville = "Nashville"
        case houston = "Houston", phoenix = "Phoenix", sanFrancisco = "San Francisco", newYork = "New York", atlanta = "Atlanta", newOrleans = "New Orleans", lasVegas = "Las Vegas", buffalo = "Buffalo"
        case pohang = "Pohang", riyadh = "Riyadh", naples = "Naples", tangerang = "Tangerang"
        case surabaya = "Surabaya", centralJakarta = "Central Jakarta", batam = "Batam", bali = "Bali"
        case sãoPaulo = "São Paulo", rioDeJaneiro = "Rio de Janeiro", recife = "Recife"
        case portoAlegre = "Porto Alegre", manaus = "Manaus", fortaleza = "Fortaleza"
        case curitiba = "Curitiba", campinas = "Campinas", brasília = "Brasília", paris = "Paris"
        case montreal = "Montreal", victoria = "Victoria", toronto = "Toronto", vancouver = "Vancouver", london = "London", tokyo = "Tokyo", seoul = "Seoul", cairo = "Cairo", sydney = "Sydney", mexicoCity = "Mexico City", rome = "Rome", barcelona = "Barcelona", berlin = "Berlin", amsterdam = "Amsterdam", shanghai = "Shanghai", beijing = "Beijing", bangkok = "Bangkok", mumbai = "Mumbai", milan = "Milan", copenhagen = "Copenhagen", telAviv = "Tel Aviv", bath = "Bath"
        case singapore = "Singapore", dubai = "Dubai", hongKong = "Hong Kong", cork = "Cork", kyoto = "Kyoto", istanbul = "Istanbul", abuDhabi = "Abu Dhabi"
        case buenosAires = "Buenos Aires", lima = "Lima", santiago = "Santiago"
        case capeTown = "Cape Town", nairobi = "Nairobi", marrakech = "Marrakech"
        case melbourne = "Melbourne", auckland = "Auckland", queenstown = "Queenstown"
        case prague = "Prague", vienna = "Vienna", lisbon = "Lisbon", bengaluru = "Bengaluru"
        case sanaa = "Sana'a"
        case athens = "Athens", budapest = "Budapest", edinburgh = "Edinburgh"
        case florence = "Florence", venice = "Venice", madrid = "Madrid", dublin = "Dublin"
        case osaka = "Osaka", johannesburg = "Johannesburg"
        case taipei = "Taipei", kualaLumpur = "Kuala Lumpur", hoChiMinhCity = "Ho Chi Minh City"
        case zurich = "Zurich", stockholm = "Stockholm", bogota = "Bogotá"
        case casablanca = "Casablanca", lagos = "Lagos", accra = "Accra", addisAbaba = "Addis Ababa"
        case doha = "Doha", amman = "Amman", muscat = "Muscat", manila = "Manila"
        case oslo = "Oslo", helsinki = "Helsinki", brussels = "Brussels", warsaw = "Warsaw"
        case havana = "Havana"
        case newDelhi = "New Delhi", jaipur = "Jaipur", xian = "Xi'an", chengdu = "Chengdu"
        case medellin = "Medellín", cartagena = "Cartagena", fukuoka = "Fukuoka", chiangMai = "Chiang Mai"
        case salzburg = "Salzburg", nice = "Nice", seville = "Seville", guadalajara = "Guadalajara"
        case quebecCity = "Quebec City", brisbane = "Brisbane"
        case kathmandu = "Kathmandu", reykjavik = "Reykjavik", stPetersburg = "St. Petersburg"
        case tbilisi = "Tbilisi", colombo = "Colombo", dakar = "Dakar", zanzibar = "Zanzibar"
        case bilbao = "Bilbao", valencia = "Valencia", rotterdam = "Rotterdam", chandigarh = "Chandigarh", glasgow = "Glasgow"
        case columbusIndiana = "Columbus, Indiana", oakPark = "Oak Park", palmSprings = "Palm Springs", fortWorth = "Fort Worth"
        case kansasCity = "Kansas City", savannah = "Savannah", charleston = "Charleston", baltimore = "Baltimore", sanDiego = "San Diego"
        case dhaka = "Dhaka"
        // BEGIN CAMPUSES (generated by tools/campus-data/build_campuses.py)
        case uniMelbourne = "University of Melbourne"
        case uniSydney = "University of Sydney"
        case utAustin = "University of Texas at Austin"
        case ucl = "University College London"
        case kingsLondon = "King's College London"
        case sorbonne = "University of Paris (Sorbonne)"
        case uniPadua = "University of Padua"
        case kuLeuven = "KU Leuven"
        case aalto = "Aalto University"
        case uppsala = "Uppsala University"
        case floridaSouthern = "Florida Southern College"
        case bostonCollege = "Boston College"
        case clemson = "Clemson University"
        case duke = "Duke University"
        case floridaState = "Florida State University"
        case georgiaTech = "Georgia Institute of Technology"
        case uLouisville = "University of Louisville"
        case uMiami = "University of Miami"
        case ncState = "North Carolina State University"
        case uncChapelHill = "University of North Carolina at Chapel Hill"
        case uPittsburgh = "University of Pittsburgh"
        case smu = "Southern Methodist University"
        case syracuse = "Syracuse University"
        case virginiaTech = "Virginia Tech"
        case wakeForest = "Wake Forest University"
        case uArizona = "University of Arizona"
        case arizonaState = "Arizona State University"
        case byu = "Brigham Young University"
        case uHouston = "University of Houston"
        case iowaState = "Iowa State University"
        case uKansas = "University of Kansas"
        case kansasState = "Kansas State University"
        case oklahomaState = "Oklahoma State University"
        case texasTech = "Texas Tech University"
        case westVirginia = "West Virginia University"
        case baylor = "Baylor University"
        case uCincinnati = "University of Cincinnati"
        case cuBoulder = "University of Colorado Boulder"
        case tcu = "Texas Christian University"
        case ucf = "University of Central Florida"
        case uUtah = "University of Utah"
        case uIllinois = "University of Illinois Urbana-Champaign"
        case uIndiana = "Indiana University Bloomington"
        case uIowa = "University of Iowa"
        case uMaryland = "University of Maryland, College Park"
        case michiganState = "Michigan State University"
        case uMinnesota = "University of Minnesota Twin Cities"
        case uNebraska = "University of Nebraska–Lincoln"
        case northwestern = "Northwestern University"
        case ohioState = "Ohio State University"
        case pennState = "Pennsylvania State University"
        case purdue = "Purdue University"
        case rutgers = "Rutgers University–New Brunswick"
        case uWisconsin = "University of Wisconsin–Madison"
        case uOregon = "University of Oregon"
        case uSouthernCalifornia = "University of Southern California"
        case uAlabama = "University of Alabama"
        case uArkansas = "University of Arkansas"
        case auburn = "Auburn University"
        case uFlorida = "University of Florida"
        case uGeorgia = "University of Georgia"
        case lsu = "Louisiana State University"
        case olemiss = "University of Mississippi"
        case mizzou = "University of Missouri"
        case uOklahoma = "University of Oklahoma"
        case uSouthCarolina = "University of South Carolina"
        case vanderbilt = "Vanderbilt University"
        case uKentucky = "University of Kentucky"
        case msState = "Mississippi State University"
        case uTennessee = "University of Tennessee"
        case texasAM = "Texas A&M University"
        case oxford = "University of Oxford"
        case cambridge = "University of Cambridge"
        case stAndrews = "University of St Andrews"
        case uniGlasgow = "University of Glasgow"
        case uniEdinburgh = "University of Edinburgh"
        case durhamUni = "Durham University"
        case trinityDublin = "Trinity College Dublin"
        case wayneState = "Wayne State University"
        case westernMichigan = "Western Michigan University"
        case grandValleyState = "Grand Valley State University"
        case yale = "Yale University"
        case harvard = "Harvard University"
        case mit = "Massachusetts Institute of Technology"
        case princeton = "Princeton University"
        case cornell = "Cornell University"
        case columbia = "Columbia University"
        case upenn = "University of Pennsylvania"
        case brown = "Brown University"
        case dartmouth = "Dartmouth College"
        case georgetown = "Georgetown University"
        case johnsHopkins = "Johns Hopkins University"
        case nyu = "New York University"
        case carnegieMellon = "Carnegie Mellon University"
        case uChicago = "University of Chicago"
        case notreDame = "University of Notre Dame"
        case uMichigan = "University of Michigan"
        case illinoisTech = "Illinois Institute of Technology"
        case uVirginia = "University of Virginia"
        case rice = "Rice University"
        case emory = "Emory University"
        case tulane = "Tulane University"
        case washU = "Washington University in St. Louis"
        case stanford = "Stanford University"
        case berkeley = "University of California, Berkeley"
        case ucla = "University of California, Los Angeles"
        case uWashington = "University of Washington"
        case mcgill = "McGill University"
        case uToronto = "University of Toronto"
        case ubc = "University of British Columbia"
        case unam = "National Autonomous University of Mexico"
        case caltech = "California Institute of Technology"
        // END CAMPUSES

        var id: String { self.rawValue }
        var name: String { self.rawValue }

        var country: Country {
            switch self {
            case .detroit, .chicago, .houston, .boston, .sanFrancisco, .denver, .phoenix, .newYork, .cleveland, .pittsburgh, .philadelphia, .atlanta, .miami, .seattle, .portland, .washingtonDC, .losangeles, .newOrleans, .lasVegas, .orlando, .dallas, .nashville, .buffalo, .minnesota, .stLouis, .austin, .cupertino, .honolulu, .asheville:
                return .unitedStates
            case .montreal, .toronto, .vancouver,.victoria:
                return .canada
            case .pohang, .seoul: return .southkorea
            case .tokyo, .kyoto: return .japan
            case .riyadh: return .saudiArabia
            case .tangerang, .surabaya, .centralJakarta, .batam, .bali:
                return .indonesia
            case .london, .bath: return .england
            case .paris: return .france
            case .naples, .milan, .rome: return .italy
            case .sãoPaulo, .rioDeJaneiro, .recife, .portoAlegre, .manaus, .fortaleza, .curitiba, .campinas, .brasília:
                return .brazil
            case .mexicoCity: return .mexico
            case .sydney: return .newSouthWales
            case .melbourne : return .victoria
            case .cairo: return .egypt
            case .singapore: return .singapore
            case .dubai, .abuDhabi: return .uae
            case .hongKong: return .sar
            case .shanghai, .beijing: return .china
            case .bangkok: return .thailand
            case .mumbai, .bengaluru: return .india
            case .copenhagen: return .denmark
            case .telAviv: return .israel
            case .amsterdam: return .netherlands
            case .barcelona: return .spain
            case .berlin: return .germany
            case .cork: return .ireland
            case .istanbul: return .turkey
            case .buenosAires: return .argentina
            case .lima: return .peru
            case .santiago: return .chile
            case .capeTown: return .southAfrica
            case .nairobi: return .kenya
            case .marrakech: return .morocco
            case .auckland, .queenstown: return .newZealand
            case .prague: return .czechRepublic
            case .vienna: return .austria
            case .lisbon: return .portugal
            case .sanaa: return .yemen
            case .athens: return .greece
            case .budapest: return .hungary
            case .edinburgh: return .scotland
            case .florence, .venice: return .italy
            case .madrid: return .spain
            case .dublin: return .ireland
            case .osaka: return .japan
            case .johannesburg: return .southAfrica
            case .taipei: return .taiwan
            case .kualaLumpur: return .malaysia
            case .hoChiMinhCity: return .vietnam
            case .zurich: return .switzerland
            case .stockholm: return .sweden
            case .bogota: return .colombia
            case .casablanca: return .morocco
            case .lagos: return .nigeria
            case .accra: return .ghana
            case .addisAbaba: return .ethiopia
            case .doha: return .qatar
            case .amman: return .jordan
            case .muscat: return .oman
            case .manila: return .philippines
            case .oslo: return .norway
            case .helsinki: return .finland
            case .brussels: return .belgium
            case .warsaw: return .poland
            case .havana: return .cuba
            case .newDelhi, .jaipur: return .india
            case .xian, .chengdu: return .china
            case .medellin, .cartagena: return .colombia
            case .fukuoka: return .japan
            case .chiangMai: return .thailand
            case .salzburg: return .austria
            case .nice: return .france
            case .seville: return .spain
            case .guadalajara: return .mexico
            case .quebecCity: return .canada
            case .brisbane: return .queensland
            case .kathmandu: return .nepal
            case .reykjavik: return .iceland
            case .stPetersburg: return .russia
            case .tbilisi: return .georgia
            case .colombo: return .sriLanka
            case .dakar: return .senegal
            case .zanzibar: return .tanzania
            case .bilbao, .valencia: return .spain
            case .rotterdam: return .netherlands
            case .chandigarh: return .india
            case .glasgow: return .scotland
            case .columbusIndiana, .oakPark, .palmSprings, .fortWorth, .kansasCity, .savannah, .charleston, .baltimore, .sanDiego: return .unitedStates
            case .dhaka: return .bangladesh
            // BEGIN CAMPUSES (generated by tools/campus-data/build_campuses.py)
            case .kuLeuven: return .belgium
            case .mcgill, .uToronto, .ubc: return .canada
            case .ucl, .kingsLondon, .oxford, .cambridge, .durhamUni: return .england
            case .aalto: return .finland
            case .sorbonne: return .france
            case .trinityDublin: return .ireland
            case .uniPadua: return .italy
            case .unam: return .mexico
            case .uniSydney: return .newSouthWales
            case .stAndrews, .uniGlasgow, .uniEdinburgh: return .scotland
            case .uppsala: return .sweden
            case .utAustin, .floridaSouthern, .bostonCollege, .clemson, .duke, .floridaState, .georgiaTech, .uLouisville, .uMiami, .ncState, .uncChapelHill, .uPittsburgh, .smu, .syracuse, .virginiaTech, .wakeForest, .uArizona, .arizonaState, .byu, .uHouston, .iowaState, .uKansas, .kansasState, .oklahomaState, .texasTech, .westVirginia, .baylor, .uCincinnati, .cuBoulder, .tcu, .ucf, .uUtah, .uIllinois, .uIndiana, .uIowa, .uMaryland, .michiganState, .uMinnesota, .uNebraska, .northwestern, .ohioState, .pennState, .purdue, .rutgers, .uWisconsin, .uOregon, .uSouthernCalifornia, .uAlabama, .uArkansas, .auburn, .uFlorida, .uGeorgia, .lsu, .olemiss, .mizzou, .uOklahoma, .uSouthCarolina, .vanderbilt, .uKentucky, .msState, .uTennessee, .texasAM, .wayneState, .westernMichigan, .grandValleyState, .yale, .harvard, .mit, .princeton, .cornell, .columbia, .upenn, .brown, .dartmouth, .georgetown, .johnsHopkins, .nyu, .carnegieMellon, .uChicago, .notreDame, .uMichigan, .illinoisTech, .uVirginia, .rice, .emory, .tulane, .washU, .stanford, .berkeley, .ucla, .uWashington, .caltech: return .unitedStates
            case .uniMelbourne: return .victoria
            // END CAMPUSES
            }
        }
    }
}

extension CityLocation.Continent {
    var iconName: String {
        switch self {
        case .africa:       return "globe.europe.africa.fill"
        case .asia:         return "globe.central.south.asia.fill"
        case .europe:       return "globe.europe.africa.fill"
        case .northAmerica: return "globe.americas.fill"
        case .southAmerica: return "globe.americas.fill"
        case .oceania:      return "globe.asia.australia.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .africa:       return .yellow
        case .asia:         return .red
        case .europe:       return .blue
        case .northAmerica: return .green
        case .southAmerica: return .orange
        case .oceania:      return .teal
        }
    }

    var iconGradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .africa:
            colors = [.yellow, .orange] // Sun and Desert
        case .asia:
            colors = [.red, .orange]   // Traditional silk/Sunrise
        case .europe:
            colors = [.blue, .indigo]  // Deep Atlantic/Royal Blue
        case .northAmerica:
            colors = [.green, .mint]   // Forests and Great Lakes
        case .southAmerica:
            colors = [.orange, .red]   // Tropical warmth
        case .oceania:
            colors = [.teal, .blue]    // Reefs and Pacific Ocean
        }
        
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Country names in the app's language

extension CityLocation.Country {
    /// The name shown on screen: iOS supplies country names in every language from the
    /// ISO code; England, Scotland and the Australian states come from Localizable.strings.
    /// English keeps the raw value, so English screens read exactly as before.
    var localizedName: String {
        guard !Self.isEnglish else { return rawValue }
        if let regionCode, let name = Self.appLocale.localizedString(forRegionCode: regionCode) {
            return name
        }
        return NSLocalizedString(rawValue, comment: "Country or region name")
    }

    /// A region name ("Australia") in the app's language, for groups that aren't one country.
    static func localizedRegion(_ code: String, english: String) -> String {
        guard !isEnglish else { return english }
        return appLocale.localizedString(forRegionCode: code) ?? english
    }

    /// The language the app is actually showing, which can differ from the device's region.
    private static var appLocale: Locale { Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en") }
    private static var isEnglish: Bool { appLocale.language.languageCode == .english }

    /// Nil for places that aren't countries (England, Scotland, Australian states)
    private var regionCode: String? {
        switch self {
        case .unitedStates: return "US"; case .brazil: return "BR"; case .indonesia: return "ID"; case .singapore: return "SG"; case .italy: return "IT"; case .saudiArabia: return "SA"
        case .southkorea: return "KR"; case .egypt: return "EG"; case .canada: return "CA"; case .uae: return "AE"; case .japan: return "JP"; case .france: return "FR"
        case .mexico: return "MX"; case .sar: return "HK"; case .denmark: return "DK"; case .germany: return "DE"; case .netherlands: return "NL"; case .israel: return "IL"
        case .china: return "CN"; case .thailand: return "TH"; case .india: return "IN"; case .spain: return "ES"; case .ireland: return "IE"; case .turkey: return "TR"
        case .argentina: return "AR"; case .peru: return "PE"; case .chile: return "CL"; case .southAfrica: return "ZA"; case .kenya: return "KE"; case .morocco: return "MA"
        case .newZealand: return "NZ"; case .czechRepublic: return "CZ"; case .austria: return "AT"; case .portugal: return "PT"; case .yemen: return "YE"; case .greece: return "GR"
        case .hungary: return "HU"; case .taiwan: return "TW"; case .malaysia: return "MY"; case .vietnam: return "VN"; case .switzerland: return "CH"; case .sweden: return "SE"
        case .colombia: return "CO"; case .nigeria: return "NG"; case .ghana: return "GH"; case .ethiopia: return "ET"; case .qatar: return "QA"; case .jordan: return "JO"
        case .oman: return "OM"; case .philippines: return "PH"; case .norway: return "NO"; case .finland: return "FI"; case .belgium: return "BE"; case .poland: return "PL"
        case .cuba: return "CU"; case .nepal: return "NP"; case .iceland: return "IS"; case .russia: return "RU"; case .georgia: return "GE"; case .sriLanka: return "LK"
        case .senegal: return "SN"; case .tanzania: return "TZ"; case .bangladesh: return "BD"
        case .england, .scotland, .newSouthWales, .victoria, .queensland: return nil
        }
    }
}
