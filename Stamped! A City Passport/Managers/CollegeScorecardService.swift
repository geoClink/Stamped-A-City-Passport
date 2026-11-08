//
//  CollegeScorecardService.swift
//  Stamped! A City Passport
//
//  Key facts for a US campus (acceptance rate, cost, graduation rate, earnings) from
//  the U.S. Department of Education's College Scorecard API. Free and official.
//
//  API key is read from Info.plist (COLLEGE_SCORECARD_API_KEY) — never hardcoded.
//  Without it every call returns nil and the College Facts card stays hidden.
//  Free: sign up at api.data.gov/signup.
//

import Foundation

// MARK: - Result model
/// One field of study and its share of the degrees a school awards.
nonisolated struct CollegeProgram: Equatable {
    /// The Scorecard's field name, e.g. "business_marketing"
    let key: String
    /// 0...1
    let share: Double

    var displayName: String {
        guard let name = Self.names[key] else { return key }
        return Bundle.main.localizedString(forKey: name, value: name, table: nil)
    }

    static let names: [String: String] = [
        "agriculture": "Agriculture",
        "resources": "Natural Resources",
        "architecture": "Architecture",
        "ethnic_cultural_gender": "Area and Gender Studies",
        "communication": "Communication",
        "communications_technology": "Communications Technology",
        "computer": "Computer Science",
        "personal_culinary": "Culinary and Personal Services",
        "education": "Education",
        "engineering": "Engineering",
        "engineering_technology": "Engineering Technology",
        "language": "Foreign Languages",
        "family_consumer_science": "Family and Consumer Sciences",
        "legal": "Legal Studies",
        "english": "English",
        "humanities": "Liberal Arts",
        "library": "Library Science",
        "biological": "Biology",
        "mathematics": "Mathematics",
        "military": "Military Science",
        "multidiscipline": "Interdisciplinary Studies",
        "parks_recreation_fitness": "Parks, Recreation and Fitness",
        "philosophy_religious": "Philosophy and Religion",
        "theology_religious_vocation": "Theology",
        "physical_science": "Physical Sciences",
        "science_technology": "Science Technology",
        "psychology": "Psychology",
        "security_law_enforcement": "Criminal Justice",
        "public_administration_social_service": "Public Administration",
        "social_science": "Social Sciences",
        "construction": "Construction",
        "mechanic_repair_technology": "Mechanics and Repair",
        "precision_production": "Precision Production",
        "transportation": "Transportation",
        "visual_performing": "Visual and Performing Arts",
        "health": "Health Professions",
        "business_marketing": "Business",
        "history": "History",
    ]
}


/// The College Facts card's numbers. Any one can be nil when the Scorecard has no figure.
nonisolated struct CollegeFacts: Equatable {
    let unitID: Int
    let name: String
    /// 0...1, e.g. 0.848
    let admissionRate: Double?
    /// Degree-seeking undergraduates
    let undergraduates: Int?
    /// Yearly tuition and fees in US dollars
    let inStateTuition: Int?
    let outOfStateTuition: Int?
    /// Share of full-time first-time students who finish a 4-year degree within 6 years, 0...1
    let graduationRate: Double?
    /// Median yearly earnings, in US dollars, 10 years after starting at the school
    let medianEarnings: Int?
    /// Average yearly cost after grants and scholarships, in US dollars
    var averageNetPrice: Int? = nil
    /// The largest fields by share of degrees awarded, biggest first
    var topPrograms: [CollegeProgram] = []

    /// True when the Scorecard sent the school but none of the numbers the card shows.
    var isEmpty: Bool {
        admissionRate == nil && undergraduates == nil && inStateTuition == nil
            && outOfStateTuition == nil && graduationRate == nil && medianEarnings == nil
    }

    /// The school's own page on collegescorecard.ed.gov, e.g. ".../school/?171100-Michigan-State-University"
    var scorecardPageURL: URL? {
        let slug = name.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return URL(string: "https://collegescorecard.ed.gov/school/?\(unitID)-\(slug)")
    }
}

// MARK: - Service

actor CollegeScorecardService {
    static let shared = CollegeScorecardService()

    // In-memory cache: UNITID → facts. Failures aren't cached, so they're retried next visit.
    private var cache: [Int: CollegeFacts] = [:]

    private init() {}

    /// Only the fields the card shows, so the response stays small
    static let fields = [
        "id",
        "school.name",
        "latest.admissions.admission_rate.overall",
        "latest.student.size",
        "latest.cost.tuition.in_state",
        "latest.cost.tuition.out_of_state",
        "latest.completion.completion_rate_4yr_150nt",
        "latest.earnings.10_yrs_after_entry.median",
        "latest.cost.avg_net_price.public",
        "latest.cost.avg_net_price.private",
        "latest.academics.program_percentage.agriculture",
        "latest.academics.program_percentage.resources",
        "latest.academics.program_percentage.architecture",
        "latest.academics.program_percentage.ethnic_cultural_gender",
        "latest.academics.program_percentage.communication",
        "latest.academics.program_percentage.communications_technology",
        "latest.academics.program_percentage.computer",
        "latest.academics.program_percentage.personal_culinary",
        "latest.academics.program_percentage.education",
        "latest.academics.program_percentage.engineering",
        "latest.academics.program_percentage.engineering_technology",
        "latest.academics.program_percentage.language",
        "latest.academics.program_percentage.family_consumer_science",
        "latest.academics.program_percentage.legal",
        "latest.academics.program_percentage.english",
        "latest.academics.program_percentage.humanities",
        "latest.academics.program_percentage.library",
        "latest.academics.program_percentage.biological",
        "latest.academics.program_percentage.mathematics",
        "latest.academics.program_percentage.military",
        "latest.academics.program_percentage.multidiscipline",
        "latest.academics.program_percentage.parks_recreation_fitness",
        "latest.academics.program_percentage.philosophy_religious",
        "latest.academics.program_percentage.theology_religious_vocation",
        "latest.academics.program_percentage.physical_science",
        "latest.academics.program_percentage.science_technology",
        "latest.academics.program_percentage.psychology",
        "latest.academics.program_percentage.security_law_enforcement",
        "latest.academics.program_percentage.public_administration_social_service",
        "latest.academics.program_percentage.social_science",
        "latest.academics.program_percentage.construction",
        "latest.academics.program_percentage.mechanic_repair_technology",
        "latest.academics.program_percentage.precision_production",
        "latest.academics.program_percentage.transportation",
        "latest.academics.program_percentage.visual_performing",
        "latest.academics.program_percentage.health",
        "latest.academics.program_percentage.business_marketing",
        "latest.academics.program_percentage.history",
    ]

    /// True when the API key is in Info.plist; without it the card never shows.
    nonisolated static var isConfigured: Bool { apiKey != nil }

    private nonisolated static var apiKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "COLLEGE_SCORECARD_API_KEY") as? String,
              !key.isEmpty else { return nil }
        return key
    }

    /// The school's facts, or nil when there's no API key, the request failed, or the
    /// Scorecard has none of the numbers.
    func facts(forUnitID unitID: Int) async -> CollegeFacts? {
        if let cached = cache[unitID] { return cached }
        guard let key = Self.apiKey else { return nil }

        var comps = URLComponents(string: "https://api.data.gov/ed/collegescorecard/v1/schools")!
        comps.queryItems = [
            URLQueryItem(name: "api_key", value: key),
            URLQueryItem(name: "id", value: String(unitID)),
            URLQueryItem(name: "fields", value: Self.fields.joined(separator: ",")),
        ]
        guard let url = comps.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                print("[Scorecard] Bad status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }
            guard let facts = Self.parse(data, unitID: unitID) else { return nil }
            cache[unitID] = facts
            return facts
        } catch {
            print("[Scorecard] Error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Reads the school with this UNITID out of a Scorecard response. Kept separate from
    /// the network call so the tests can feed it a saved sample.
    /// The three largest fields with at least 5% of degrees. The API sends one flat key per field.
    nonisolated static func topPrograms(in data: Data, unitID: Int) -> [CollegeProgram] {
        let prefix = "latest.academics.program_percentage."
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let school = results.first(where: { ($0["id"] as? Int) == unitID })
        else { return [] }
        return school.compactMap { key, value -> CollegeProgram? in
            guard key.hasPrefix(prefix), let share = (value as? NSNumber)?.doubleValue, share >= 0.05 else { return nil }
            return CollegeProgram(key: String(key.dropFirst(prefix.count)), share: share)
        }
        .sorted { ($0.share, $1.key) > ($1.share, $0.key) }
        .prefix(3)
        .map { $0 }
    }

    nonisolated static func parse(_ data: Data, unitID: Int) -> CollegeFacts? {
        guard let decoded = try? JSONDecoder().decode(ScorecardResponse.self, from: data),
              let school = decoded.results.first(where: { $0.id == unitID })
        else { return nil }

        let facts = CollegeFacts(
            unitID: unitID,
            name: school.name ?? "",
            admissionRate: school.admissionRate,
            undergraduates: school.size,
            inStateTuition: school.inStateTuition.map { Int($0.rounded()) },
            outOfStateTuition: school.outOfStateTuition.map { Int($0.rounded()) },
            graduationRate: school.completionRate,
            medianEarnings: school.medianEarnings.map { Int($0.rounded()) },
            averageNetPrice: (school.netPricePublic ?? school.netPricePrivate).map { Int($0.rounded()) },
            topPrograms: topPrograms(in: data, unitID: unitID)
        )
        return facts.isEmpty ? nil : facts
    }
}

// MARK: - Formatting

/// How the card writes each number, in the user's own locale (85 %, 17.256 $ and so on).
/// Every figure is US data, so money is always US dollars.
nonisolated enum CollegeFactsFormat {
    /// 0.848 → "85%"
    static func percent(_ value: Double, locale: Locale = .current) -> String {
        value.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    /// 17256 → "$17,256"
    static func dollars(_ value: Int, locale: Locale = .current) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(0)).locale(locale))
    }

    /// 40922 → "40,922"
    static func count(_ value: Int, locale: Locale = .current) -> String {
        value.formatted(.number.locale(locale))
    }
}

// MARK: - College Scorecard API response shapes

nonisolated private struct ScorecardResponse: Decodable {
    let results: [ScorecardSchool]
}

/// With `fields=` the API sends flat, dotted keys ("latest.student.size"), not nested objects.
nonisolated private struct ScorecardSchool: Decodable {
    let id: Int
    let name: String?
    let admissionRate: Double?
    let size: Int?
    let inStateTuition: Double?
    let outOfStateTuition: Double?
    let completionRate: Double?
    let medianEarnings: Double?
    let netPricePublic: Double?
    let netPricePrivate: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case name = "school.name"
        case admissionRate = "latest.admissions.admission_rate.overall"
        case size = "latest.student.size"
        case inStateTuition = "latest.cost.tuition.in_state"
        case outOfStateTuition = "latest.cost.tuition.out_of_state"
        case completionRate = "latest.completion.completion_rate_4yr_150nt"
        case medianEarnings = "latest.earnings.10_yrs_after_entry.median"
        case netPricePublic = "latest.cost.avg_net_price.public"
        case netPricePrivate = "latest.cost.avg_net_price.private"
    }
}
