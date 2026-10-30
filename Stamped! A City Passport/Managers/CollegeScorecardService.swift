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
            medianEarnings: school.medianEarnings.map { Int($0.rounded()) }
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

    enum CodingKeys: String, CodingKey {
        case id
        case name = "school.name"
        case admissionRate = "latest.admissions.admission_rate.overall"
        case size = "latest.student.size"
        case inStateTuition = "latest.cost.tuition.in_state"
        case outOfStateTuition = "latest.cost.tuition.out_of_state"
        case completionRate = "latest.completion.completion_rate_4yr_150nt"
        case medianEarnings = "latest.earnings.10_yrs_after_entry.median"
    }
}
