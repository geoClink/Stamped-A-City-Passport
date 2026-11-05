//
//  Secrets.swift
//  Tally-AVP
//
//  API keys from Secrets.plist, which stays out of git (.gitignore). Without the
//  file (a fresh checkout) every key is nil and the features that need one hide.
//

import Foundation

nonisolated enum Secrets {
    static let europeanaKey = value("EUROPEANA_API_KEY")
    static let freesoundKey = value("FREESOUND_API_KEY")
    static let smithsonianKey = value("SMITHSONIAN_API_KEY")

    private static let values: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [:] }
        return plist
    }()

    private static func value(_ key: String) -> String? {
        guard let text = values[key] as? String, !text.isEmpty else { return nil }
        return text
    }
}
