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

        var continent: Continent {
            switch self {
            case .unitedStates, .canada, .mexico:
                return .northAmerica
            case .brazil, .argentina, .peru, .chile:
                return .southAmerica
            case .italy, .england, .france, .denmark, .germany, .netherlands, .spain, .ireland, .turkey, .czechRepublic, .austria, .portugal:
                return .europe
            case .singapore, .saudiArabia, .southkorea, .uae, .japan, .sar, .israel, .china, .thailand, .india, .indonesia:
                return .asia
            case .egypt, .southAfrica, .kenya, .morocco:
                return .africa
            case .newSouthWales, .victoria, .newZealand:
                return .oceania
            }
        }

        var localGreeting: String {
            switch self {
            case .unitedStates, .canada, .england, .newSouthWales, .victoria, .ireland, .southAfrica, .newZealand, .singapore:
                return "Hello!"
            case .mexico, .spain, .argentina, .peru, .chile:
                return "¡Hola!"
            case .saudiArabia, .uae, .egypt, .morocco:
                return "Ahlan! (أهلاً)"
            case .japan:
                return "Konnichiwa! (こんにちは)"
            case .southkorea:
                return "Annyeong! (안녕)"
            case .china, .sar:
                return "Ni Hao! (你好)"
            case .thailand:
                return "Sawasdee! (สวัสดี)"
            case .indonesia:
                return "Halo!"
            case .india:
                return "Namaste! (नमस्ते)"
            case .france:
                return "Bonjour !"
            case .italy:
                return "Ciao!"
            case .germany, .austria:
                return "Hallo!"
            case .netherlands:
                return "Hoi!"
            case .denmark:
                return "Hej!"
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
            }
        }

        var congratsMessage: String {
            switch self {
            case .unitedStates, .canada, .england, .newSouthWales, .victoria, .ireland, .southAfrica, .newZealand, .singapore:
                return "CONGRATULATIONS!"
            case .mexico, .spain, .argentina, .peru, .chile:
                return "¡FELICITACIONES!"
            case .saudiArabia, .uae, .egypt, .morocco:
                return "MABROUK! (مبروك)"
            case .japan:
                return "OMEDETOU! (おめでとう)"
            case .southkorea:
                return "CHUKHAHAE! (축하해)"
            case .china, .sar:
                return "GONGXI! (恭喜)"
            case .thailand:
                return "YINDI DUAI! (ยินดีด้วย)"
            case .indonesia:
                return "SELAMAT!"
            case .india:
                return "BADHAAI HO! (बधाई हो)"
            case .france:
                return "FÉLICITATIONS !"
            case .italy:
                return "CONGRATULAZIONI!"
            case .germany, .austria:
                return "GLÜCKWUNSCH!"
            case .netherlands:
                return "GEFELICITEERD!"
            case .denmark:
                return "TILLYKKE!"
            case .turkey:
                return "TEBRİKLER!"
            case .czechRepublic:
                return "GRATULACE!"
            case .portugal, .brazil:
                return "PARABÉNS!"
            case .israel:
                return "MAZEL TOV! (מזל טוב)"
            case .kenya:
                return "HONGERA!"
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
