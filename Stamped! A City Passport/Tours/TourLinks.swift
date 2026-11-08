//
//  TourLinks.swift
//  Stamped! A City Passport
//
//  "Tours & Tickets" links: guided tours and skip-the-line tickets for a landmark on
//  GetYourGuide. Like the hotel links, Stamped never books or takes payment; the button
//  opens GetYourGuide's own search, credited to Stamped's partner ID.
//

import SwiftUI

// MARK: - Configuration

/// The single configuration point for tour links.
enum TourPartner {
    /// GetYourGuide partner ID (Partner Portal, joined 29 Oct 2026). Not a secret: it's in
    /// every link a user opens. nil turns the links' tracking (and the commission note) off.
    static let getYourGuidePartnerID: String? = "PBXFUP9"

    /// Labels these clicks in GetYourGuide's reports; the website's links use "website".
    static let campaign = "app"

    /// Viator partner ID and campaign number (Viator Partner Program, approved 30 Oct 2026),
    /// from a link its dashboard made. Not secrets: they're in every link a user opens.
    /// nil hides the Viator link.
    static let viatorPartnerID: String? = "P00329078"
    static let viatorCampaignNumber = "42383"
}

// MARK: - URL building

struct TourLinkBuilder {
    var partnerID: String? = TourPartner.getYourGuidePartnerID
    var campaign: String = TourPartner.campaign

    /// The trimmed ID, when one is set.
    private var activePartnerID: String? {
        guard let id = partnerID?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else { return nil }
        return id
    }

    /// True when links carry the partner ID, so the "may earn a commission" note shows.
    var earnsCommission: Bool { activePartnerID != nil }

    /// GetYourGuide's search for "<landmark>, <place>". Famous landmarks get their own tours
    /// ("Colosseum, Rome"); for one GetYourGuide doesn't know, the search falls back to tours
    /// in the place, which is still what a visitor wants. Checked against the live site 29 Oct 2026.
    ///
    /// https://www.getyourguide.com/s/?partner_id=<id>&cmp=<campaign>&q=<landmark, place>
    func url(landmark: String, place: String) -> URL? {
        let query = [landmark, place]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        guard !query.isEmpty else { return nil }

        var items: [(String, String)] = []
        if let id = activePartnerID {
            items.append(("partner_id", id))
            items.append(("cmp", campaign))
        }
        items.append(("q", query))
        let encoded = items
            .map { "\(HotelLinkBuilder.encode($0.0))=\(HotelLinkBuilder.encode($0.1))" }
            .joined(separator: "&")
        return URL(string: "https://www.getyourguide.com/s/?\(encoded)")
    }

    /// GetYourGuide's search for "food tour, <place>": food tours, tastings and cooking
    /// classes there, for the building page's Local Flavors. Same link as a landmark's,
    /// with "food tour" in the landmark's spot.
    func foodToursURL(place: String) -> URL? {
        guard !place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return url(landmark: "food tour", place: place)
    }
}

/// Viator's search for "<landmark>, <place>", a second tours site next to GetYourGuide, with
/// Viator's partner tracking (checked against the live site 30 Oct 2026: "Colosseum, Rome"
/// returns 200+ tours).
///
/// https://www.viator.com/searchResults/all?text=<landmark, place>&pid=<id>&mcid=<n>&medium=link&campaign=<campaign>
struct ViatorLinkBuilder {
    var partnerID: String? = TourPartner.viatorPartnerID
    var campaignNumber: String = TourPartner.viatorCampaignNumber
    var campaign: String = TourPartner.campaign

    func url(landmark: String, place: String) -> URL? {
        guard let id = partnerID?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else { return nil }
        let query = [landmark, place]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        guard !query.isEmpty else { return nil }
        let items = [("text", query), ("pid", id), ("mcid", campaignNumber), ("medium", "link"), ("campaign", campaign)]
        let encoded = items.map { "\(HotelLinkBuilder.encode($0.0))=\(HotelLinkBuilder.encode($0.1))" }.joined(separator: "&")
        return URL(string: "https://www.viator.com/searchResults/all?\(encoded)")
    }
}

// MARK: - Button

// The Vision Pro app shares this file but not the iPhone design tokens (DS),
// so it has its own tour links on the landmark card.
/// Remembers which cities have had the after-tour offer, so it never nags.
enum TourOffer {
    private static let shownKey = "tourOfferShownCities"

    /// True the first time it's called for a city, false after that.
    static func claim(city: String, defaults: UserDefaults = .standard) -> Bool {
        var shown = Set(defaults.stringArray(forKey: shownKey) ?? [])
        guard shown.insert(city).inserted else { return false }
        defaults.set(Array(shown), forKey: shownKey)
        return true
    }
}

#if !os(visionOS)
/// "Tours & Tickets on GetYourGuide" for a landmark, with the commission note under it.
struct ToursButton: View {
    let landmark: String
    let place: String
    /// Lets a screen dress the label like its own buttons (the landmark page's tinted tiles)
    var styleLabel: (AnyView) -> AnyView = { $0 }

    private let builder = TourLinkBuilder()
    @State private var browserLink: BrowserLink?

    var body: some View {
        if let url = builder.url(landmark: landmark, place: place) {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    browserLink = BrowserLink(url: url)
                } label: {
                    styleLabel(AnyView(
                        Label(NSLocalizedString("Find Tours & Tickets", comment: "Landmark page button: opens GetYourGuide's tours and tickets for this landmark"),
                              systemImage: "ticket.fill")
                    ))
                }
                .accessibilityLabel(String(
                    format: NSLocalizedString("Find tours and tickets for %@ on GetYourGuide", comment: "Tours button, VoiceOver: e.g. \"Find tours and tickets for Colosseum on GetYourGuide\""),
                    landmark
                ))
                .accessibilityHint(NSLocalizedString("Opens GetYourGuide. Stamped! doesn't handle bookings or payments.", comment: "Tours button, VoiceOver hint"))

                // A second tours site: Viator sometimes has tours GetYourGuide doesn't
                if let viatorURL = ViatorLinkBuilder().url(landmark: landmark, place: place) {
                    Button {
                        browserLink = BrowserLink(url: viatorURL)
                    } label: {
                        Label(NSLocalizedString("More tours on Viator", comment: "Landmark page: link under Tours & Tickets that opens Viator's tours for this landmark"),
                              systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DS.Palette.accent)
                    .accessibilityHint(NSLocalizedString("Opens Viator. Stamped! doesn't handle bookings or payments.", comment: "Viator link, VoiceOver hint"))
                }

                if builder.earnsCommission {
                    HotelCommissionNote()
                }
            }
            .inAppBrowser(item: $browserLink)
        }
    }
}

/// Identifies the place a tour offer is for, so it can drive `.sheet(item:)`.
struct TourOfferPlace: Identifiable {
    let name: String
    var id: String { name }
}

/// Shown once per city when a Time Walk finishes.
struct TourOfferSheet: View {
    let place: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: DS.Space.l) {
            Text("Want to see \(place) in person?")
                .font(.system(.title2, design: .serif))
                .multilineTextAlignment(.center)
            Text("Guided tours and tickets for your trip.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            ToursButton(landmark: "", place: place) { AnyView($0.tourTile(tint: DS.Palette.accent)) }
                .buttonStyle(.plain)
            Button("Not Now") { dismiss() }
        }
        .padding(DS.Space.section)
        .presentationDetents([.medium])
    }
}

/// A campus page's link to the school's own visit page, with hotels for the trip.
struct CampusVisitSection: View {
    let campus: CityLocation.City
    var isHighContrast = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var browserLink: BrowserLink?

    private var accent: Color {
        isHighContrast ? .primary : (campus.stampColor(darkMode: colorScheme == .dark) ?? DS.Palette.accent)
    }

    var body: some View {
        if let url = campus.officialVisitURL {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                Button {
                    browserLink = BrowserLink(url: url)
                } label: {
                    Label("Official Campus Tour", systemImage: "building.columns.fill")
                        .tourTile(tint: accent)
                }
                .buttonStyle(.plain)
                Text("Opens the school's own visit page")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline) {
                    Text("Staying overnight?")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    FindHotelsButton(search: HotelSearch(city: campus))
                        .font(.subheadline.weight(.semibold))
                        .tint(accent)
                }
                Text(CollegeDisclaimer.text)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCard(isHighContrast: isHighContrast)
            .dsPageMargin()
            .inAppBrowser(item: $browserLink)
        }
    }
}

private extension View {
    /// The tinted full-width tile the landing page uses for its actions.
    func tourTile(tint: Color) -> some View {
        font(.subheadline.weight(.semibold))
            .foregroundColor(tint)
            .padding(.vertical, DS.Space.m)
            .padding(.horizontal, DS.Space.s)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }
}

#endif
