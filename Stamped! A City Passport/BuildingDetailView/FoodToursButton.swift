//
//  FoodToursButton.swift
//  Stamped! A City Passport
//
//  "Find Food Tours & Cooking Classes" under a building's Local Flavors: opens
//  GetYourGuide's search for food tours in the city, credited to Stamped's partner ID
//  (see Tours/TourLinks.swift). Like the Tours & Tickets button, Stamped never books
//  or takes payment.
//

import SwiftUI

struct FoodToursButton: View {
    let city: CityLocation.City
    /// Lets the building page dress the label like its own buttons (its tinted tiles)
    var styleLabel: (AnyView) -> AnyView = { $0 }

    private let builder = TourLinkBuilder()
    @State private var browserLink: BrowserLink?

    var body: some View {
        // Cities only, the same rule as the Tours & Tickets button: a campus search
        // lands on unrelated tours.
        if !city.isCampus, let url = builder.foodToursURL(place: city.hotelSearchName) {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    browserLink = BrowserLink(url: url)
                } label: {
                    styleLabel(AnyView(
                        Label(NSLocalizedString("Find Food Tours & Cooking Classes", comment: "Building page button under Local Flavors: opens GetYourGuide's food tours and cooking classes in this city"),
                              systemImage: "takeoutbag.and.cup.and.straw.fill")
                    ))
                }
                .accessibilityLabel(String(
                    format: NSLocalizedString("Find food tours and cooking classes in %@ on GetYourGuide", comment: "Food tours button, VoiceOver: e.g. \"Find food tours and cooking classes in Rome, Italy on GetYourGuide\""),
                    city.hotelSearchName
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
