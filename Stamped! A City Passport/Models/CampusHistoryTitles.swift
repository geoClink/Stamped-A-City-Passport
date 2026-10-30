//
//  CampusHistoryTitles.swift
//  Stamped! A City Passport
//
//  Which English Wikipedia article the History card reads for each campus.
//  Most campus names are already the article title; the few that aren't are listed here.
//  Checked for every campus with tools/campus-data/check_history_titles.py (2026-10-29):
//  each title leads to the university's own article, not a city, a team or a "may refer to" page.
//

import Foundation

extension CityLocation.City {
    /// The university's English Wikipedia article title, or nil for real cities.
    var historyArticleTitle: String? {
        guard isCampus else { return nil }
        return Self.historyTitleOverrides[self] ?? name
    }

    /// Campus → article title, where the app's name for the campus isn't the title
    /// (the same titles as `wiki` in tools/campus-data/campuses).
    static let historyTitleOverrides: [CityLocation.City: String] = [
        // "Georgia Institute of Technology" redirects; the article is "Georgia Tech"
        .georgiaTech: "Georgia Tech",
        // The article covers the Twin Cities campus under the university's own name
        .uMinnesota: "University of Minnesota",
        // "University of Paris (Sorbonne)" is only the app's name; the article is the historic university
        .sorbonne: "University of Paris",
    ]

    /// Campuses whose Wikidata founding year would mislead, so the card leaves it out:
    /// the University of Paris dates from about 1150, but Wikidata prefers its 1896 re-founding;
    /// KU Leuven's 1968 is the Dutch-language split, not the university's 1425 founding.
    static let historyFoundedYearHidden: Set<CityLocation.City> = [.sorbonne, .kuLeuven]
}
