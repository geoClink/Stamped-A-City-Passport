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
}
