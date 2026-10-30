//
//  ArchitectIndex.swift
//  Stamped! A City Passport
//
//  Groups every built-in landmark by its architect, across all cities and campuses,
//  so a building page can link to an Architect page listing all their work.
//
//  The registry's `architect` field is free text: "James O'Donnell",
//  "I.M. Pei & Henry N. Cobb", "Darling and Pearson", "Alphonse Venne / Dom Bellot".
//  Many of those joined names are ONE firm ("Darling and Pearson",
//  "Skidmore, Owings & Merrill"), so splitting is deliberately conservative:
//
//  1. A trailing note in brackets is dropped: "Skidmore, Owings & Merrill (SOM)" and
//     "Cass Gilbert (Original)" group with "Skidmore, Owings & Merrill" and "Cass Gilbert".
//  2. " / " and ";" separate different parties (original and extension, say). They
//     are split only when every side looks like a person's name, or is on its own
//     the architect of another building in the app ("Maginnis & Walsh; Svigals &
//     Associates" stays whole, because "Svigals & Associates" is neither).
//  3. " & " and " and " are split only when every side looks like a person's name:
//     "Philip Johnson & John Burgee" is two people, but "Darling and Pearson",
//     "Herzog & de Meuron" and "Eliel & Eero Saarinen" each have a one-word side,
//     so they stay one name.
//  A side "looks like a person" when it has 2 to 5 words, starts with a capital,
//  has no comma, digit, "+" or leftover "/" or ";", and has no firm word
//  ("Associates", "Partners", "Design") or vague word ("Traditional", "Various").
//
//  Names are compared by a loose key, so "Bruce and Morgan" and "Bruce & Morgan",
//  or "I. M. Pei" and "I.M. Pei", land on the same page.
//

import Foundation

/// One architect or firm, as the app groups them.
struct ArchitectName: Identifiable, Hashable {
    /// The loose comparison key (see `ArchitectIndex.key(for:)`).
    let key: String
    /// The spelling to show: the one most landmarks use.
    let displayName: String
    var id: String { key }
}

enum ArchitectIndex {

    // MARK: - Lookups

    /// The architects a building page links to, in the order the registry names them.
    /// Empty when the building's architect is unknown or too vague for a page ("Traditional").
    static func architects(of building: Building) -> [ArchitectName] {
        guard let architect = building.knownArchitect else { return [] }
        return names(in: architect, standaloneKeys: index.standaloneKeys)
            .filter(isLinkable)
            .map { ArchitectName(key: key(for: $0), displayName: index.displayNames[key(for: $0)] ?? $0) }
    }

    /// Every landmark by this architect, oldest first (undated ones last).
    static func landmarks(by architect: ArchitectName) -> [(building: Building, city: CityLocation.City)] {
        (index.landmarks[architect.key] ?? []).sorted { first, second in
            // Year 0 means "no build date", so those go to the end
            let firstYear = first.building.hasKnownYear ? first.building.yearBuilt : Int.max
            let secondYear = second.building.hasKnownYear ? second.building.yearBuilt : Int.max
            if firstYear != secondYear { return firstYear < secondYear }
            return first.building.name < second.building.name
        }
    }

    // MARK: - Grouping rules (pure, so the tests can call them)

    /// The separate architect names in one registry `architect` string (see the rules at the top).
    /// `standaloneKeys` are the keys of whole architect strings in the app, used by rule 2.
    nonisolated static func names(in architect: String, standaloneKeys: Set<String> = []) -> [String] {
        let whole = removingNote(architect.trimmingCharacters(in: .whitespaces))

        // Rule 2: parties joined by " / " or ";"
        var parties = [whole]
        let sides = split(whole, on: [" / ", ";"]).map(removingNote)
        if sides.count > 1, sides.allSatisfy({ looksLikePerson($0) || standaloneKeys.contains(key(for: $0)) }) {
            parties = sides
        }

        // Rule 3: partners joined by " & " or " and "
        let names = parties.flatMap { party -> [String] in
            let partners = split(party, on: [" & ", " and "])
            return partners.count > 1 && partners.allSatisfy(looksLikePerson) ? partners : [party]
        }

        // A name given twice in one string is still one link
        var seen: Set<String> = []
        return names.filter { !$0.isEmpty && seen.insert(key(for: $0)).inserted }
    }

    /// The loose key two spellings of one name share: no case or accents,
    /// "and" the same as "&", and "I. M." the same as "I.M.".
    nonisolated static func key(for name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: " and ", with: " & ")
            .replacingOccurrences(of: ". ", with: ".")
            .split(separator: " ")
            .joined(separator: " ")
    }

    /// False for names that describe no one in particular ("Traditional / Unknown",
    /// "N/A (natural landmark)", "Various, reconstructed by ...", "Built by ..."): those get no page.
    nonisolated static func isLinkable(_ name: String) -> Bool {
        // Punctuation is trimmed so "Various," still counts as "various"
        guard let firstWord = name.split(separator: " ").first?
            .trimmingCharacters(in: .punctuationCharacters) else { return false }
        let vagueStarts: Set<String> = ["traditional", "unknown", "various", "natural", "medieval",
                                        "original", "royal", "internal", "built", "local", "n/a"]
        return !vagueStarts.contains(firstWord.lowercased())
    }

    // MARK: - Helpers

    /// Words that mark a firm or a vague credit rather than a person's name (rule 3).
    nonisolated private static let nonPersonWords: Set<String> = [
        "architects", "architect", "architecture", "architectural", "associates", "partners",
        "partnership", "design", "designs", "inc", "co", "company", "group", "team", "retail",
        "studio", "son", "sons", "bros", "office", "engineers", "others", "various", "traditional",
        "unknown", "original", "ancient", "medieval", "natural", "apple", "crew", "dynasty",
        "military", "concept", "et", "al", "builders", "craftsmen", "restoration", "renovation"
    ]

    nonisolated private static func looksLikePerson(_ side: String) -> Bool {
        let words = side.split(separator: " ")
        guard (2...5).contains(words.count),
              words[0].first?.isUppercase == true,
              !side.contains(where: { ",;/+".contains($0) }),
              !side.contains(where: \.isNumber),
              // "Reed and Stem" is a pair or a firm, not one person
              !side.contains(" and "), !side.contains(" & ")
        else { return false }
        return !words.contains { nonPersonWords.contains($0.lowercased().trimmingCharacters(in: .punctuationCharacters)) }
    }

    /// "Cass Gilbert (Original)" → "Cass Gilbert". Only a note at the very end is dropped.
    nonisolated private static func removingNote(_ name: String) -> String {
        guard name.hasSuffix(")"), let open = name.lastIndex(of: "(") else { return name }
        let trimmed = name[..<open].trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? name : trimmed
    }

    nonisolated private static func split(_ text: String, on separators: [String]) -> [String] {
        // Turn every separator into one marker character, then split on that
        let marker = "\u{1F}"
        var marked = text
        for separator in separators {
            marked = marked.replacingOccurrences(of: separator, with: marker)
        }
        return marked.components(separatedBy: marker)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Index

    private struct Index {
        /// Architect key → every landmark that names them
        var landmarks: [String: [(building: Building, city: CityLocation.City)]] = [:]
        /// Architect key → the spelling most landmarks use
        var displayNames: [String: String] = [:]
        /// Keys of whole architect strings, for rule 2
        var standaloneKeys: Set<String> = []
    }

    /// Built once, the first time an architect is looked up. Like `LandmarkIndex`,
    /// a building id found in two cities counts once (the first city wins).
    private static let index: Index = {
        var result = Index()
        var allLandmarks: [(building: Building, city: CityLocation.City)] = []
        var seenIDs: Set<String> = []
        for city in CityLocation.City.allCases {
            for building in city.buildings where seenIDs.insert(building.id).inserted {
                allLandmarks.append((building, city))
            }
        }

        for landmark in allLandmarks {
            if let architect = landmark.building.knownArchitect {
                result.standaloneKeys.insert(key(for: removingNote(architect)))
            }
        }

        // How often each spelling is used, to pick the display name
        var spellingCounts: [String: [String: Int]] = [:]
        for landmark in allLandmarks {
            guard let architect = landmark.building.knownArchitect else { continue }
            for name in names(in: architect, standaloneKeys: result.standaloneKeys) {
                let nameKey = key(for: name)
                result.landmarks[nameKey, default: []].append(landmark)
                spellingCounts[nameKey, default: [:]][name, default: 0] += 1
            }
        }
        for (nameKey, counts) in spellingCounts {
            // Most used first; alphabetical breaks a tie so the choice never changes between launches
            let best = counts.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }
            result.displayNames[nameKey] = best?.key
        }
        return result
    }()
}
