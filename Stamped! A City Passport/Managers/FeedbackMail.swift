//
//  FeedbackMail.swift
//  Stamped! A City Passport
//
//  Pre-filled emails for reporting wrong info or suggesting a building or tradition. The user
//  sends them from their own mail app, so the app itself collects nothing. Every subject starts
//  with the same tag as the website's suggestion form, so one mail filter catches both.
//

import Foundation

enum FeedbackMail {
    static let address = "georgeclinkscalesdev@proton.me"
    static let tag = "[Stamped! suggestion]"

    /// A mistake or gap on a building's page.
    static func building(_ building: Building, in city: CityLocation.City) -> URL? {
        url(subject: "\(tag) \(building.name), \(city.name)", lines: [
            "Place: \(city.name)",
            "Building: \(building.name)",
            "Building id: \(building.id)",
        ], prompt: "What's wrong or missing:")
    }

    /// A mistake on a city or campus page.
    static func place(_ city: CityLocation.City) -> URL? {
        url(subject: "\(tag) \(city.name)", lines: [
            "Place: \(city.name)",
            "Country: \(city.country.rawValue)",
        ], prompt: "What's wrong or missing:")
    }

    /// A campus tradition the app doesn't have yet.
    static func tradition(for campus: CityLocation.City) -> URL? {
        url(subject: "\(tag) Tradition for \(campus.name)", lines: [
            "Place: \(campus.name)",
            "Type: Tradition",
        ], prompt: "The tradition, where on campus, and a link we can check:")
    }

    /// A general correction from Settings.
    static func general(subject: String, body: String) -> URL? {
        url(subject: "\(tag) \(subject)", lines: [], prompt: body)
    }

    /// App version, iOS version and language, so a report can be matched to the data it saw.
    static var appInfo: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let language = Locale.preferredLanguages.first ?? "?"
        let system = ProcessInfo.processInfo.operatingSystemVersion
        return "App: Stamped! \(version) (\(build)) · iOS \(system.majorVersion).\(system.minorVersion) · \(language)"
    }

    private static func url(subject: String, lines: [String], prompt: String) -> URL? {
        let body = (lines + [appInfo, "", prompt, ""]).joined(separator: "\n")
        return URL(string: "mailto:\(address)?subject=\(encoded(subject))&body=\(encoded(body))")
    }

    /// Percent-encodes everything but unreserved characters. `.urlQueryAllowed` leaves "&" and
    /// "+" alone, which cut the email short for names like "Texas A&M University".
    static func encoded(_ text: String) -> String {
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }
}
