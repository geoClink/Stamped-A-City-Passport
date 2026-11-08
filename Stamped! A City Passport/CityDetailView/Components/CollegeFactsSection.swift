//
//  CollegeFactsSection.swift
//  Stamped! A City Passport
//
//  The College Facts card on a US campus page: acceptance rate, size, tuition,
//  graduation rate and earnings from the U.S. Department of Education's College
//  Scorecard (CollegeScorecardService). Hidden while loading and when there's no data.
//

import SwiftUI

/// Shown wherever the app gives information about a school.
enum CollegeDisclaimer {
    static var text: String {
        NSLocalizedString("Stamped! is an independent app and isn't connected with any school. Details can be wrong or out of date, so check the school's official website before you make plans or decisions.", comment: "Campus pages: independent app, check the school's site")
    }
}

struct CollegeFactsSection: View {
    let campus: CityLocation.City
    var isHighContrast: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var facts: CollegeFacts?
    @State private var isLoading = true
    @ScaledMetric(relativeTo: .body) private var factMinWidth: CGFloat = 140

    /// The school's color, like the campus stamp; orange when it has none
    private var accent: Color {
        isHighContrast ? .primary : (campus.stampColor(darkMode: colorScheme == .dark) ?? DS.Palette.accent)
    }

    var body: some View {
        // Only US campuses have a Scorecard ID, and only with an API key is there anything to load
        if let unitID = campus.scorecardID, CollegeScorecardService.isConfigured {
            Group {
                if let facts {
                    card(facts)
                        .transition(.opacity)
                } else if isLoading {
                    // A `.task` on an empty view never runs, so loading hangs off this
                    // invisible placeholder; it goes away once the load is done
                    Color.clear
                        .frame(height: 0)
                        .accessibilityHidden(true)
                        .task(id: unitID) {
                            let loaded = await CollegeScorecardService.shared.facts(forUnitID: unitID)
                            withAnimation(.easeIn(duration: 0.2)) {
                                facts = loaded
                                isLoading = false
                            }
                        }
                }
                // Loaded with nothing to show: render nothing
            }
        }
    }

    private func card(_ facts: CollegeFacts) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader("COLLEGE FACTS", systemImage: "chart.bar.doc.horizontal", isHighContrast: isHighContrast)
                .dsPageMargin()

            // Two columns on a phone; one at large text sizes, more on a wide iPad or Mac window
            LazyVGrid(columns: [GridItem(.adaptive(minimum: factMinWidth), spacing: DS.Space.m, alignment: .topLeading)],
                      alignment: .leading, spacing: DS.Space.l) {
                ForEach(rows(for: facts), id: \.label) { row in
                    fact(value: row.value, label: row.label)
                }
            }
            .dsCard(isHighContrast: isHighContrast)
            .dsPageMargin()

            if !facts.topPrograms.isEmpty {
                topPrograms(facts.topPrograms)
                    .dsCard(isHighContrast: isHighContrast)
                    .dsPageMargin()
            }

            Text(footnoteText(facts))
                .font(.caption2)
                .foregroundColor(isHighContrast ? .primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)
                .dsPageMargin()

            // The data's source, linking to the school's own Scorecard page
            if let url = facts.scorecardPageURL {
                Link(destination: url) {
                    Label(NSLocalizedString("Source: U.S. Department of Education College Scorecard", comment: "College Facts card: source line, links to collegescorecard.ed.gov"), systemImage: "building.columns")
                        .font(.caption)
                        .foregroundColor(accent)
                        .multilineTextAlignment(.leading)
                }
                .accessibilityHint(NSLocalizedString("Opens the College Scorecard website", comment: "College Facts card: VoiceOver hint for the source link"))
                .dsPageMargin()
            }
        }
    }

    /// The facts the Scorecard has, in card order; missing numbers are left out.
    private func rows(for facts: CollegeFacts) -> [(label: String, value: String)] {
        var rows: [(label: String, value: String)] = []
        if let rate = facts.admissionRate {
            rows.append((NSLocalizedString("Acceptance rate", comment: "College Facts card: share of applicants admitted"), CollegeFactsFormat.percent(rate)))
        }
        if let size = facts.undergraduates {
            rows.append((NSLocalizedString("Undergraduates", comment: "College Facts card: number of undergraduate students"), CollegeFactsFormat.count(size)))
        }
        if let tuition = facts.inStateTuition {
            rows.append((NSLocalizedString("In-state tuition", comment: "College Facts card: yearly tuition for state residents"), CollegeFactsFormat.dollars(tuition)))
        }
        if let tuition = facts.outOfStateTuition {
            rows.append((NSLocalizedString("Out-of-state tuition", comment: "College Facts card: yearly tuition for non-residents"), CollegeFactsFormat.dollars(tuition)))
        }
        if let price = facts.averageNetPrice {
            rows.append((NSLocalizedString("Average net price", comment: "College Facts card: average yearly cost after aid"), CollegeFactsFormat.dollars(price)))
        }
        if let rate = facts.graduationRate {
            rows.append((NSLocalizedString("Graduation rate", comment: "College Facts card: share of students who graduate"), CollegeFactsFormat.percent(rate)))
        }
        if let earnings = facts.medianEarnings {
            rows.append((NSLocalizedString("Median earnings after 10 years", comment: "College Facts card: median yearly pay 10 years after starting at the school"), CollegeFactsFormat.dollars(earnings)))
        }
        return rows
    }

    private func footnoteText(_ facts: CollegeFacts) -> String {
        var notes = [NSLocalizedString("Tuition and fees are per year. Graduation is within 6 years; earnings are the median 10 years after starting.", comment: "College Facts card: footnote explaining the numbers")]
        if facts.averageNetPrice != nil || !facts.topPrograms.isEmpty {
            notes.append(NSLocalizedString("Average net price is what students with federal aid paid per year after grants and scholarships. Top programs are each field's share of degrees awarded. Figures are the latest the government has published.", comment: "College Facts card: footnote explaining net price and programs"))
        }
        return notes.joined(separator: " ")
    }

    private func topPrograms(_ programs: [CollegeProgram]) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text(NSLocalizedString("Top programs", comment: "College Facts card: largest fields of study"))
                .font(.headline)
            ForEach(programs, id: \.key) { program in
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(program.displayName)
                        Spacer()
                        Text(CollegeFactsFormat.percent(program.share))
                            .monospacedDigit()
                            .foregroundColor(accent)
                    }
                    .font(.subheadline)
                    // An ink line scaled to the school's largest program
                    GeometryReader { proxy in
                        Capsule()
                            .fill(accent)
                            .frame(width: proxy.size.width * program.share / max(programs[0].share, 0.01))
                    }
                    .frame(height: 4)
                    .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A big number with its label under it, read by VoiceOver as one item
    private func fact(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.monospacedDigit().bold())
                .foregroundColor(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundColor(isHighContrast ? .primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}
