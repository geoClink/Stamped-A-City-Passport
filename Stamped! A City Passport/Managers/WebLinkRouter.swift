//
//  WebLinkRouter.swift
//  Stamped! A City Passport
//
//  Opens the right city or campus when someone taps a link to its page on the Stamped! website
//  (a universal link, set up by the Associated Domains entitlement and the site's
//  .well-known/apple-app-site-association file). The site names each page after the city or
//  campus, e.g. /stamped-colleges/michigan-state-university.html, using the same slug as the
//  site's build scripts (tools/stamped/build_*_pages.py in the portfolio repo).
//

import Foundation

enum WebLinkRouter {
    static let host = "georgeclinkscalesdev.com"

    /// The city or campus a website link points at, or nil for any other page.
    static func city(from url: URL) -> CityLocation.City? {
        guard let urlHost = url.host?.lowercased(),
              urlHost == host || urlHost == "www." + host
        else { return nil }

        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2,
              ["stamped-colleges", "stamped-cities"].contains(parts[0]),
              parts[1].hasSuffix(".html")
        else { return nil }

        let pageSlug = String(parts[1].dropLast(".html".count))
        let wantsCampus = parts[0] == "stamped-colleges"
        return CityLocation.City.allCases.first { $0.isCampus == wantsCampus && slug($0.rawValue) == pageSlug }
    }

    /// The website's page name for a city or campus. Matches `slug()` in the site's build scripts:
    /// accents are dropped, anything that isn't a letter or digit becomes one hyphen, and
    /// apostrophes are removed ("King's College London" → "kings-college-london").
    static func slug(_ name: String) -> String {
        let scalars = name.decomposedStringWithCompatibilityMapping.unicodeScalars.filter(\.isASCII)
        var result = ""
        var needsHyphen = false
        for character in String(String.UnicodeScalarView(scalars)).lowercased() where character != "'" {
            if character.isLetter || character.isNumber {
                if needsHyphen && !result.isEmpty { result.append("-") }
                needsHyphen = false
                result.append(character)
            } else {
                needsHyphen = true
            }
        }
        return result
    }
}
