//
//  QuizLogic.swift
//  Stamped! A City Passport
//
//  The quiz's rules as plain functions: which questions a building can have,
//  how wrong answers are picked, and how a spoken answer is matched to an
//  option. Nothing here touches the screen, so StampedTests can check it.
//

import Foundation

enum QuizLogic {

    // MARK: - Question Choice

    /// One kind of question the quiz can ask about a building. A photo question
    /// is a `.name` question that shows the photo instead of the data card
    /// (QuestionType is shared with the Vision Pro quiz, so it gets no new case).
    struct Choice: Equatable {
        let type: QuestionType
        var showsPhoto = false
        /// How often this choice comes up compared with the others (1 = normal)
        var weight: Double = 1
    }

    /// "How many floors?" gets old fast, so it comes up less than the rest.
    static let floorsWeight = 0.35
    /// Photo questions are the most fun, so they come up a little more often.
    static let photoWeight = 1.5

    /// Every question that has a real answer for this building.
    /// `hasPhoto` means a Wikipedia photo is known to exist for it.
    static func choices(for building: Building, hasPhoto: Bool) -> [Choice] {
        var choices = [Choice(type: .name)]
        if hasPhoto {
            choices.append(Choice(type: .name, showsPhoto: true, weight: photoWeight))
        }
        if building.knownStyle != nil {
            choices.append(Choice(type: .style))
        }
        // "When was this lake built?" has no answer, so skip year questions there.
        if building.hasKnownYear {
            choices.append(Choice(type: .year))
        }
        if building.knownArchitect != nil {
            choices.append(Choice(type: .architect))
        }
        if asksAboutFloors(building) {
            choices.append(Choice(type: .stories, weight: floorsWeight))
        }
        return choices
    }

    /// 0 means the floor count isn't known, and "1 floor" is too easy to guess.
    static func asksAboutFloors(_ building: Building) -> Bool {
        building.numberOfStories >= 2
    }

    /// Picks one choice at random, where a weight of 2 is twice as likely as 1.
    static func pick<G: RandomNumberGenerator>(from choices: [Choice], using generator: inout G) -> Choice {
        let total = choices.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return choices.first ?? Choice(type: .name) }
        var roll = Double.random(in: 0..<total, using: &generator)
        for choice in choices {
            roll -= choice.weight
            if roll < 0 { return choice }
        }
        return choices.last ?? Choice(type: .name)
    }

    // MARK: - Year Distractors

    /// Wrong years are 5–40 years from the real one, so the answer can't be
    /// spotted as "the only year from the right century".
    static let yearOffsets = 5...40
    /// Wrong years are at least this far from each other, so 1929 and 1930 never sit side by side.
    static let minimumYearGap = 3

    /// `count` wrong years near `answer`: all different, never the answer,
    /// never in the future and never before year 1.
    static func yearDistractors<G: RandomNumberGenerator>(
        for answer: Int,
        count: Int = 3,
        currentYear: Int = Calendar.current.component(.year, from: Date()),
        using generator: inout G
    ) -> [Int] {
        // Every year 5–40 years before or after the answer that could be real
        let candidates = yearOffsets.flatMap { [answer - $0, answer + $0] }
            .filter { $0 >= 1 && $0 <= currentYear }
            .shuffled(using: &generator)

        var picked: [Int] = []
        for year in candidates where picked.count < count {
            // Skip years too close to one already picked
            if picked.allSatisfy({ abs($0 - year) >= minimumYearGap }) {
                picked.append(year)
            }
        }
        return picked
    }

    // MARK: - Floor Distractors

    /// `count` wrong floor counts near `answer` (closer for short buildings,
    /// wider for skyscrapers), all different and never the answer.
    static func floorDistractors<G: RandomNumberGenerator>(
        for answer: Int,
        count: Int = 3,
        using generator: inout G
    ) -> [Int] {
        // A 3-floor building gets 1–6; a 60-floor tower gets 40–80.
        let spread = max(3, answer / 3)
        let candidates = (max(1, answer - spread)...(answer + spread))
            .filter { $0 != answer }
            .shuffled(using: &generator)
        return Array(candidates.prefix(count))
    }

    // MARK: - Style Distractors

    /// Well-known styles with a rough peak year, used only when a city has too
    /// few styles of its own to fill four options.
    static let fallbackStyles: [(style: String, year: Int)] = [
        ("Romanesque", 1100), ("Gothic", 1250), ("Renaissance", 1500),
        ("Baroque", 1680), ("Neoclassical", 1800), ("Gothic Revival", 1850),
        ("Victorian", 1870), ("Beaux-Arts", 1900), ("Art Nouveau", 1900),
        ("Art Deco", 1930), ("Modernist", 1950), ("Brutalist", 1965),
        ("Postmodern", 1985), ("Contemporary", 2010)
    ]

    /// Styles count as "the same era" when their buildings are this close in years.
    static let sameEraYears = 75

    /// `count` wrong styles. Styles from the city whose buildings are from a
    /// similar era come first, then the city's other styles, then well-known
    /// styles from `fallbackStyles` if the city still doesn't have enough.
    /// `pool` is every building's (style, year) in the city; year nil means unknown.
    static func styleDistractors<G: RandomNumberGenerator>(
        for answer: String,
        answerYear: Int?,
        pool: [(style: String, year: Int?)],
        count: Int = 3,
        using generator: inout G
    ) -> [String] {
        // Years between each other style's closest building and the answer
        // (Int.max when either year is unknown)
        var eraDistance: [String: Int] = [:]
        for entry in pool where !sameText(entry.style, answer) {
            var distance = Int.max
            if let answerYear, let year = entry.year {
                distance = abs(year - answerYear)
            }
            eraDistance[entry.style] = min(eraDistance[entry.style] ?? Int.max, distance)
        }

        let sameEra = eraDistance.filter { $0.value <= sameEraYears }.map(\.key)
        let otherEras = eraDistance.keys.filter { !sameEra.contains($0) }
        // Fallbacks nearest in era first, and none that overlap the answer
        // ("Gothic" is too close to call when the answer is "Gothic Revival")
        let fallbacks = fallbackStyles
            .filter { !overlaps($0.style, answer) }
            .sorted { abs($0.year - (answerYear ?? $0.year)) < abs($1.year - (answerYear ?? $1.year)) }
            .map(\.style)

        let ordered = sameEra.shuffled(using: &generator)
            + otherEras.shuffled(using: &generator)
            + fallbacks
        return uniqueDistractors(for: answer, from: ordered, count: count, shuffle: false, using: &generator)
    }

    // MARK: - Generic Distractors

    /// Up to `count` options from `candidates` that are not the answer, not
    /// blank and not repeated (ignoring case and accents). With `shuffle` off
    /// the candidates' order is kept, so earlier ones are preferred.
    static func uniqueDistractors<G: RandomNumberGenerator>(
        for answer: String,
        from candidates: [String],
        count: Int = 3,
        shuffle: Bool = true,
        using generator: inout G
    ) -> [String] {
        let ordered = shuffle ? candidates.shuffled(using: &generator) : candidates
        var picked: [String] = []
        for candidate in ordered where picked.count < count {
            let trimmed = candidate.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !sameText(trimmed, answer),
                  !picked.contains(where: { sameText($0, trimmed) }) else { continue }
            picked.append(trimmed)
        }
        return picked
    }

    // MARK: - After the Answer

    /// One line of facts about the building, shown after each answer:
    /// "Notre-Dame Basilica · Gothic Revival · 1829 · James O'Donnell"
    static func factLine(for building: Building) -> String {
        var facts = [building.name]
        if let style = building.knownStyle { facts.append(style) }
        if building.hasKnownYear { facts.append(String(building.yearBuilt)) }
        if let architect = building.knownArchitect { facts.append(architect) }
        return facts.joined(separator: " · ")
    }

    // MARK: - Voice Matching

    /// Small words people often drop or that every name shares
    private static let fillerWords: Set<String> = ["the", "of", "and", "a", "an", "de", "la", "le", "st", "saint"]

    /// The option the person said, or nil if nothing matched clearly.
    /// Ignores case, accents and punctuation, so saying "notre dame basilica"
    /// matches "Notre-Dame Basilica". With `isNumeric` (year and floor
    /// questions) the number itself must be said, so "12" matches "12 floors"
    /// but "2" does not.
    static func voiceMatch(spoken: String, options: [String], isNumeric: Bool = false) -> String? {
        let spokenWords = words(in: spoken)
        guard !spokenWords.isEmpty else { return nil }
        let spokenText = spokenWords.joined(separator: " ")
        let spokenNumbers = numbers(in: spoken)

        var best: (option: String, score: Double)?
        for option in options {
            let optionWords = words(in: option)
            guard !optionWords.isEmpty else { continue }

            var score: Double = 0
            if isNumeric {
                guard let number = numbers(in: option).first else { continue }
                let saidNumber = spokenNumbers.contains(number)
                    || (" " + spokenText + " ").contains(" " + spelledOut(number) + " ")
                score = saidNumber ? 1 : 0
            } else if (" " + spokenText + " ").contains(" " + optionWords.joined(separator: " ") + " ") {
                score = 1
            } else {
                // Partial credit for names: share of the option's key words that were said
                let keyWords = optionWords.filter { !fillerWords.contains($0) }
                guard !keyWords.isEmpty else { continue }
                let said = keyWords.filter { spokenWords.contains($0) }.count
                score = Double(said) / Double(keyWords.count)
                // Long names can miss one word; short names must be said in full
                let needed = keyWords.count >= 4 ? 0.75 : 1
                if score < needed { score = 0 }
            }

            // Prefer the fuller match, then the longer name ("Union Station Tower" over "Union Station")
            if score > 0, score > (best?.score ?? 0)
                || (score == best?.score && option.count > (best?.option.count ?? 0)) {
                best = (option, score)
            }
        }
        return best?.option
    }

    /// Lowercased words without accents or punctuation ("St. Paul's" → ["st", "pauls"])
    static func words(in text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .lowercased()
            // Apostrophes join a word rather than split it
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Every run of digits in the text ("12階" and "12 floors" both give [12])
    private static func numbers(in text: String) -> [Int] {
        text.split { !("0"..."9").contains($0) }.compactMap { Int($0) }
    }

    private static func spelledOut(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        let spelled = formatter.string(from: NSNumber(value: number)) ?? ""
        // "twenty-one" is heard as "twenty one"
        return words(in: spelled).joined(separator: " ")
    }

    /// Same text ignoring case, accents and surrounding spaces
    static func sameText(_ first: String, _ second: String) -> Bool {
        words(in: first) == words(in: second)
    }

    /// One style name contains the other ("Gothic" and "Gothic Revival")
    private static func overlaps(_ first: String, _ second: String) -> Bool {
        let firstText = " " + words(in: first).joined(separator: " ") + " "
        let secondText = " " + words(in: second).joined(separator: " ") + " "
        return firstText.contains(secondText) || secondText.contains(firstText)
    }
}
