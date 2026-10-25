//
//  ApplePlaceSheet.swift
//  Stamped! A City Passport
//
//  Apple's own place card (photos, hours, ratings, Call, Website…) for any
//  restaurant, café, shop or museum tapped on the city map, with Stamped's
//  "Want to Visit" button pinned underneath. Hotels also get "Check Prices",
//  which opens the hotel site's search for that hotel (see Hotels/HotelLinks.swift).
//

import SwiftUI
import MapKit

/// An Apple Maps place the user tapped. MKMapItem isn't Identifiable,
/// so this wrapper lets `.sheet(item:)` present it.
struct TappedApplePlace: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
}

struct ApplePlaceSheet: View {
    let mapItem: MKMapItem
    /// The Stamped city the place is saved under, so it shows on this city's map.
    let cityName: String

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var progress = GlobalProgressManager.shared
    @AppStorage("haptics_enabled") private var hapticsEnabled = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var addToTrip: AddToTripRequest?

    private var name: String { mapItem.name ?? "Unnamed place" }

    /// This place in the user's Want to Visit list, if they've already saved it.
    private var savedPlace: CustomPlace? {
        let coordinate = coordinate(of: mapItem)
        return progress.customPlaces(in: cityName).first {
            $0.isSamePlace(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }

    var body: some View {
        MapItemDetailView(mapItem: mapItem) { dismiss() }
            .safeAreaInset(edge: .bottom) { actionBar }
            // With large text a half-height card cuts the place's name in half, so it opens full height
            .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
            .sheet(item: $addToTrip) { request in
                AddToTripSheet(cityName: cityName, stop: request.stop, stopName: request.name)
            }
    }

    /// True for a hotel, which gets a Check Prices button.
    private var isHotel: Bool {
        mapItem.pointOfInterestCategory == .hotel
    }

    /// Searches the hotel site for this hotel: its name plus its town as the label,
    /// centred on its location so the hotel shows near the top of the results.
    private var hotelSearch: HotelSearch {
        let townName = town(of: mapItem) ?? cityName
        let destination = townName.isEmpty || name.localizedCaseInsensitiveContains(townName) ? name : "\(name), \(townName)"
        return HotelSearch(destination: destination, coordinate: coordinate(of: mapItem))
    }

    /// Want to Visit + Add to Trip (and Check Prices for a hotel), pinned under Apple's card.
    private var actionBar: some View {
        VStack(spacing: 8) {
            if isHotel {
                FindHotelsButton(
                    search: hotelSearch,
                    title: NSLocalizedString("Check Prices", comment: "Map place card: button on a hotel that opens a hotel site's prices for it"),
                    accessibilityText: String(
                        format: NSLocalizedString("Check prices for %1$@ on %2$@", comment: "Map place card, VoiceOver: e.g. \"Check prices for Hotel Indigo on Booking.com\""),
                        name, HotelPartner.provider.displayName
                    ),
                    fillsWidth: true
                )
                .font(.headline)
                // For a hotel, prices are the main action; the other two step back
                .buttonStyle(.borderedProminent)
                .tint(.adventureOrange)
            }
            // Side by side when they fit; stacked with large text instead of wrapping inside the buttons
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { primaryActions }
                VStack(spacing: 8) { primaryActions }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ViewBuilder
    private var primaryActions: some View {
        wantToVisitButton
        Button {
            // A trip stop points at a saved place, so save it first if needed
            let place = savedPlace ?? save()
            addToTrip = AddToTripRequest(stop: .place(placeID: place.id), name: place.name)
        } label: {
            Label("Add to Trip", systemImage: "suitcase.rolling")
                .font(.headline)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(.adventureOrange)
    }

    @ViewBuilder
    private var wantToVisitButton: some View {
        let isSaved = savedPlace != nil
        let button = Button(action: toggleSaved) {
            Label(isSaved ? "Saved" : "Want to Visit",
                  systemImage: isSaved ? "heart.fill" : "heart")
                .font(.headline)
                .lineLimit(1)
                .contentTransition(.symbolEffect(.replace))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        // Only one filled button per card: Check Prices on a hotel, Want to Visit everywhere else
        Group {
            if isHotel {
                button.buttonStyle(.bordered)
            } else {
                button.buttonStyle(.borderedProminent)
            }
        }
        .tint(DS.Palette.wishlist)
        .accessibilityHint(isSaved ? "Removes \(name) from Want to Visit" : "Adds \(name) to your map and Want to Visit list")
    }

    // MARK: - Actions

    /// Saves the place (it then gets a pink pin), or removes it if it's already saved.
    private func toggleSaved() {
        if let savedPlace {
            withAnimation { progress.removeCustomPlace(savedPlace.id) }
            if hapticsEnabled { HapticManager.shared.trigger(.selection) }
            return
        }
        save()
        if hapticsEnabled { HapticManager.shared.trigger(.success) }
    }

    /// Adds this place to Want to Visit and returns the saved copy.
    @discardableResult
    private func save() -> CustomPlace {
        let coordinate = coordinate(of: mapItem)
        let place = CustomPlace(
            id: UUID().uuidString,
            name: name,
            address: address(of: mapItem),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            cityName: cityName,
            websiteURL: mapItem.url,
            phoneNumber: mapItem.phoneNumber,
            category: mapItem.pointOfInterestCategory?.rawValue
        )
        withAnimation { progress.addCustomPlace(place) }
        // addCustomPlace skips a place already saved under any city, so hand back
        // whichever copy is really stored; a trip stop must point at a real id
        return progress.customPlaces.first { $0.isSamePlace(name: place.name, latitude: place.latitude, longitude: place.longitude) } ?? place
    }

    // MARK: - Helpers

    // The app supports iOS 18.6, but these MKMapItem properties changed in iOS 26
    // (same as AddPlaceSheet). `#available` picks the right one at runtime.
    private func coordinate(of item: MKMapItem) -> CLLocationCoordinate2D {
        if #available(iOS 26.0, *) {
            return item.location.coordinate
        } else {
            return item.placemark.coordinate
        }
    }

    /// The hotel's town ("Athens"), from Apple's address.
    private func town(of item: MKMapItem) -> String? {
        if #available(iOS 26.0, *) {
            return item.addressRepresentations?.cityName
        } else {
            return item.placemark.locality
        }
    }

    private func address(of item: MKMapItem) -> String? {
        if #available(iOS 26.0, *) {
            return item.address?.shortAddress ?? item.address?.fullAddress
        } else {
            return item.placemark.title
        }
    }
}

// MARK: - Apple's place card

/// Wraps MapKit's UIKit place card (MKMapItemDetailViewController) so SwiftUI can show it.
/// SwiftUI has no view of its own for this card, only a sheet modifier
/// that can't hold extra buttons like Want to Visit.
private struct MapItemDetailView: UIViewControllerRepresentable {
    let mapItem: MKMapItem
    /// Called when the user taps the card's own close button.
    let onDone: () -> Void

    func makeUIViewController(context: Context) -> MKMapItemDetailViewController {
        // displaysMap: false — the card already sits on top of our map
        let controller = MKMapItemDetailViewController(mapItem: mapItem, displaysMap: false)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: MKMapItemDetailViewController, context: Context) {
        controller.mapItem = mapItem
        context.coordinator.onDone = onDone
    }

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    /// UIKit reports "close tapped" through a delegate; the coordinator passes it back to SwiftUI.
    final class Coordinator: NSObject, MKMapItemDetailViewControllerDelegate {
        var onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }

        func mapItemDetailViewControllerDidFinish(_ detailViewController: MKMapItemDetailViewController) {
            onDone()
        }
    }
}
