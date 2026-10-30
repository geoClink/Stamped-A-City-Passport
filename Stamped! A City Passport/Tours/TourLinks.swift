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

// MARK: - Button

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

                if builder.earnsCommission {
                    HotelCommissionNote()
                }
            }
            .inAppBrowser(item: $browserLink)
        }
    }
}
