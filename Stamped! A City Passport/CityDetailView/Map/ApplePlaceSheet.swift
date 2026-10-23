//
//  ApplePlaceSheet.swift
//  Stamped! A City Passport
//
//  Apple's own place card (photos, hours, ratings, Call, Website…) for any
//  restaurant, café, shop or museum tapped on the city map, with Stamped's
//  "Want to Visit" button pinned underneath.
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
            .safeAreaInset(edge: .bottom) { wantToVisitButton }
            .presentationDetents([.medium, .large])
    }

    private var wantToVisitButton: some View {
        let isSaved = savedPlace != nil
        return Button(action: toggleSaved) {
            Label(isSaved ? "Saved to Want to Visit" : "Want to Visit",
                  systemImage: isSaved ? "heart.fill" : "heart")
                .font(.headline)
                .contentTransition(.symbolEffect(.replace))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(.pink)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
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
        if hapticsEnabled { HapticManager.shared.trigger(.success) }
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
