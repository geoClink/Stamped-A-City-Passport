//
//  OpenTableButton.swift
//  Stamped! A City Passport
//
//  "Find a Table on OpenTable" under Local Flavors: OpenTable's own restaurant search
//  around this building, wrapped in OpenTable's Partnerize click link. Stamped never
//  books a table: the reservation happens on OpenTable.
//
//  The restaurants on the cards come from Apple Maps, which doesn't say which ones are
//  on OpenTable, so this is one search for the area rather than a link per card.
//

import SwiftUI

/// The single configuration point for OpenTable links.
enum OpenTablePartner {
    /// OpenTable's Partnerize camref for this account. OpenTable pointed us to its affiliate
    /// program on Partnerize (4 Nov 2026); paste the camref here once the campaign approves
    /// the app. Not a secret: it's in plain sight in every link. nil hides the button.
    static let camref: String? = nil
}

/// OpenTable's search near a point, wrapped in a Partnerize click link:
/// https://prf.hn/click/camref:<id>/destination:<https://www.opentable.com/s?latitude=…&longitude=…>
struct OpenTableLinkBuilder {
    var camref: String? = OpenTablePartner.camref
    /// Partnerize "pubref" label, e.g. "vision" for the Vision Pro app; nil adds nothing.
    var clickLabel: String? = nil

    func url(latitude: Double, longitude: Double) -> URL? {
        guard let camref = camref?.trimmingCharacters(in: .whitespacesAndNewlines), !camref.isEmpty else { return nil }
        // Five decimals like the hotel links; POSIX so a German phone doesn't write "40,73"
        let posix = Locale(identifier: "en_US_POSIX")
        let lat = String(format: "%.5f", locale: posix, latitude)
        let lon = String(format: "%.5f", locale: posix, longitude)
        let searchLink = "https://www.opentable.com/s?latitude=\(lat)&longitude=\(lon)"
        return HotelLinkBuilder.partnerizeURL(camref: camref, clickLabel: clickLabel, destination: searchLink)
    }
}

/// The button itself. Hidden when the building has no coordinate or no camref is set.
struct OpenTableButton: View {
    let latitude: Double?
    let longitude: Double?
    /// Lets the building page dress the label like its own buttons (its tinted tiles)
    var styleLabel: (AnyView) -> AnyView = { $0 }

    private let builder = OpenTableLinkBuilder()
    @State private var browserLink: BrowserLink?

    var body: some View {
        if let latitude, let longitude, let url = builder.url(latitude: latitude, longitude: longitude) {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    browserLink = BrowserLink(url: url)
                } label: {
                    styleLabel(AnyView(
                        Label(NSLocalizedString("Find a Table on OpenTable", comment: "Building page button under Local Flavors: opens OpenTable's restaurant search near this building"),
                              systemImage: "fork.knife.circle.fill")
                    ))
                }
                .accessibilityHint(NSLocalizedString("Opens OpenTable. Stamped! doesn't handle bookings or payments.", comment: "OpenTable button, VoiceOver hint"))

                // Every link that reaches here carries the camref, so the disclosure always shows
                HotelCommissionNote()
            }
            .inAppBrowser(item: $browserLink)
        }
    }
}
