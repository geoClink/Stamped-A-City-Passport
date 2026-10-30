//
//  CampusHistorySection.swift
//  Stamped! A City Passport
//
//  The History card on a campus page: the year the university was founded and a few
//  sentences from its Wikipedia article (CampusHistoryService), with a link to the
//  full article. Hidden while loading and when Wikipedia has nothing.
//

import SwiftUI

struct CampusHistorySection: View {
    let campus: CityLocation.City
    var isHighContrast: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var history: CampusHistory?
    @State private var isLoading = true

    /// The school's color, like the campus stamp; orange when it has none
    private var accent: Color {
        isHighContrast ? .primary : (campus.stampColor(darkMode: colorScheme == .dark) ?? DS.Palette.accent)
    }

    var body: some View {
        // Campuses only; real cities have no history article
        if let title = campus.historyArticleTitle {
            Group {
                if let history {
                    card(history)
                        .transition(.opacity)
                } else if isLoading {
                    // A `.task` on an empty view never runs, so loading hangs off this
                    // invisible placeholder; it goes away once the load is done
                    Color.clear
                        .frame(height: 0)
                        .accessibilityHidden(true)
                        .task(id: title) {
                            let loaded = await CampusHistoryService.shared.history(forArticle: title)
                            withAnimation(.easeIn(duration: 0.2)) {
                                history = loaded
                                isLoading = false
                            }
                        }
                }
                // Loaded with nothing to show: render nothing
            }
        }
    }

    private func card(_ history: CampusHistory) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader("HISTORY", systemImage: "clock.arrow.circlepath", isHighContrast: isHighContrast)
                .dsPageMargin()

            VStack(alignment: .leading, spacing: DS.Space.m) {
                if let year = history.foundedYear, !CityLocation.City.historyFoundedYearHidden.contains(campus) {
                    // String(year), not a formatted number, so it never reads "1,855"
                    DSChip(text: String(format: NSLocalizedString("Founded %@", comment: "Campus History card: the year the university was founded, e.g. Founded 1855"), String(year)),
                           systemImage: "calendar",
                           tint: accent)
                }

                // Same "From Wikipedia" label as the building pages
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "w.circle.fill")
                        .font(.caption)
                    Text("From Wikipedia")
                        .font(.caption2.monospaced().weight(.semibold))
                }
                .foregroundColor(isHighContrast ? .primary : .secondary)

                Text(history.summary)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let url = history.articleURL {
                    Link(destination: url) {
                        Label(NSLocalizedString("Read more on Wikipedia", comment: "Campus History card: link to the university's full Wikipedia article"), systemImage: "arrow.up.right.square")
                            .font(.caption.bold())
                            .foregroundColor(accent)
                    }
                    .accessibilityHint(NSLocalizedString("Opens the full article on Wikipedia", comment: "Campus History card: VoiceOver hint for the Wikipedia link"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCard(isHighContrast: isHighContrast)
            .dsPageMargin()
        }
    }
}
