//
//  Secrets.swift
//  Stamped! A City Passport
//
//  API keys from Secrets.plist, which stays out of git (.gitignore). Each app bundles
//  its own copy: Tally-AVP/Secrets.plist for Vision Pro and Resources/Secrets.plist
//  for iPhone. Without the file (a fresh checkout) every key is nil and the features
//  that need one hide.
//

import Foundation

nonisolated enum Secrets {
    /// A personal key for testing until Europeana grants a project key, so it must
    /// never reach a shipped build. Drop the #if when the project key is in the plist.
    static let europeanaKey: String? = {
        #if DEBUG
        value("EUROPEANA_API_KEY")
        #else
        nil
        #endif
    }()
    static let freesoundKey = value("FREESOUND_API_KEY")
    static let smithsonianKey = value("SMITHSONIAN_API_KEY")

    private static let values: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [:] }
        return plist
    }()

    private static func value(_ key: String) -> String? { value(key, in: values) }

    /// A missing, blank or wrong-typed entry counts as no key
    static func value(_ key: String, in values: [String: Any]) -> String? {
        guard let text = (values[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return text
    }
}
