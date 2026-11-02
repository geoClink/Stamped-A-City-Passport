//
//  Building+LocalizedStyle.swift
//  Tally-AVP
//

import Foundation

extension Building {
    /// The building's style in the user's language, e.g. "Ancient Roman" -> "Römische Antike" in German.
    /// The registry only stores English, so this looks the English text up as a key in
    /// Localizable.xcstrings. A style with no entry there simply stays in English.
    var localizedStyle: String {
        String(localized: String.LocalizationValue(buildingStyle))
    }

    /// "Ancient Roman · Built 80" for a landmark subtitle, leaving out whichever part
    /// isn't recorded (natural places have no style or year), or nil when neither is.
    /// Same rule as the iPhone's knownStyle / hasKnownYear.
    var styleAndYear: String? {
        let style = knownStyle.map { String(localized: String.LocalizationValue($0)) }
        let year = hasKnownYear ? String(yearBuilt) : nil
        switch (style, year) {
        case let (style?, year?): return String(localized: "\(style) · Built \(year)")
        case let (style?, nil): return style
        case let (nil, year?): return String(localized: "Built \(year)")
        case (nil, nil): return nil
        }
    }
}
