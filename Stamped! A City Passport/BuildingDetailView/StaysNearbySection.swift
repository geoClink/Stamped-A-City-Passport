//
//  StaysNearbySection.swift
//  Stamped! A City Passport
//
//  "Stays Near Here" on a building page: up to 6 hotels from Apple Maps around the
//  building, nearest first, as cards like Local Flavors. Tapping one opens Apple's place
//  card in the app (ApplePlaceSheet), which already has the hotel's "Check Prices" button,
//  so there's no booking flow here. Hidden when Apple Maps finds no hotels.
//

import SwiftUI
import MapKit
import CoreLocation

/// A hotel Apple Maps found, with how far it is from the building.
private struct NearbyHotel: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
    let name: String
    let meters: CLLocationDistance
}

struct StaysNearbySection: View {
    let building: Building
    /// The Stamped city a hotel is saved under if the user taps Want to Visit on its card.
    let cityName: String
    let isHighContrast: Bool

    @AppStorage("use_metric_units") private var useMetric = true
    @AppStorage("haptics_enabled") private var hapticsEnabled = true
    @ScaledMetric(relativeTo: .subheadline) private var cardWidth: CGFloat = 160
    /// Street photo (or bed icon) at the top of each hotel card
    @ScaledMetric(relativeTo: .body) private var thumbnailHeight: CGFloat = 72

    @State private var hotels: [NearbyHotel] = []
    @State private var tappedHotel: TappedApplePlace?

    private let hotelLinks = HotelLinkBuilder()

    /// The building's location; no search without one.
    private var coordinate: CLLocationCoordinate2D? {
        guard let latitude = building.latitude, let longitude = building.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var body: some View {
        if let coordinate {
            // The VStack always exists so its .task runs (a .task on an empty Group never does).
            // Until hotels arrive it holds only a zero-height placeholder.
            VStack(alignment: .leading, spacing: DS.Space.m) {
                if hotels.isEmpty {
                    Color.clear.frame(height: 0)
                } else {
                    DSSectionHeader("Stays Near Here", systemImage: "bed.double", isHighContrast: isHighContrast)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: DS.Space.m) {
                            ForEach(hotels) { hotel in
                                hotelCard(hotel)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Hotel data from Apple Maps.", comment: "Building page, Stays Near Here: data source note under the hotel cards"))
                            .font(.caption2)
                            .foregroundColor(isHighContrast ? .primary : .secondary)
                        // Check Prices on the hotel's card uses the affiliate link
                        if hotelLinks.earnsCommission {
                            HotelCommissionNote()
                        }
                    }
                }
            }
            .task(id: building.id) {
                hotels = await Self.searchHotels(near: coordinate)
            }
            .sheet(item: $tappedHotel) { place in
                ApplePlaceSheet(mapItem: place.mapItem, cityName: cityName)
            }
        }
    }

    // MARK: - Card

    /// Same surface, size and thumbnail as the Local Flavors cards.
    private func hotelCard(_ hotel: NearbyHotel) -> some View {
        let distance = NearbyDistance.text(meters: hotel.meters, useMetric: useMetric)
        return Button {
            if hapticsEnabled { HapticManager.shared.trigger(.selection) }
            tappedHotel = TappedApplePlace(mapItem: hotel.mapItem)
        } label: {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                // Apple's street photo of the hotel, or a bed icon when there isn't one
                PlaceThumbnail(mapItem: hotel.mapItem, category: hotel.mapItem.pointOfInterestCategory ?? .hotel,
                               height: thumbnailHeight, isHighContrast: isHighContrast)

                Text(hotel.name)
                    .font(.subheadline).fontWeight(.bold)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)

                Spacer(minLength: DS.Space.xs)

                HStack(spacing: DS.Space.xs) {
                    Text(distance)
                        .font(.caption2.monospaced()).fontWeight(.semibold)
                        .foregroundColor(isHighContrast ? .primary : .secondary)
                        .textCase(.uppercase)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(isHighContrast ? .primary : .secondary)
                }
            }
            .padding(DS.Space.l)
            .frame(width: cardWidth, alignment: .leading)
            .frame(minHeight: cardWidth, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(isHighContrast ? Color.clear : DS.Palette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(Color.primary, lineWidth: isHighContrast ? 2 : 0)
            )
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(hotel.name), \(distance)")
        .accessibilityHint(NSLocalizedString("Shows this hotel's details and prices.", comment: "Building page, Stays Near Here card, VoiceOver hint"))
    }

    // MARK: - Search

    /// Hotels within about 1.5 km of the building, nearest first, at most 6.
    private static func searchHotels(near center: CLLocationCoordinate2D) async -> [NearbyHotel] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "hotel"
        request.region = MKCoordinateRegion(center: center, latitudinalMeters: 3000, longitudinalMeters: 3000)
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.hotel])

        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
        let origin = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return response.mapItems
            .compactMap { item -> NearbyHotel? in
                guard let name = item.name else { return nil }
                return NearbyHotel(mapItem: item, name: name, meters: location(of: item).distance(from: origin))
            }
            .sorted { $0.meters < $1.meters }
            .prefix(6)
            .map { $0 }
    }

    // The app supports iOS 18.6, but MKMapItem's location moved in iOS 26
    // (same as ApplePlaceSheet). `#available` picks the right one at runtime.
    private static func location(of item: MKMapItem) -> CLLocation {
        if #available(iOS 26.0, macOS 26.0, *) {
            return item.location
        } else {
            let coordinate = item.placemark.coordinate
            return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }
}

// MARK: - Distance text

/// "6 min walk" for anything up to a 20-minute walk, else "2.4 km" or "1.5 mi" following
/// the Metric Units setting, in the user's language.
/// (feature/apple-place-cards adds a similar DiningPlaceLabel.distanceText for restaurant
/// cards; the two can become one once both are merged.)
enum NearbyDistance {
    /// About 4.8 km/h, the usual figure for a relaxed city walk.
    static let walkingMetersPerMinute: Double = 80
    static let maxWalkingMinutes = 20

    static func text(meters: CLLocationDistance, useMetric: Bool, locale: Locale = .current) -> String {
        // Rounded up, and never "0 min" for a hotel next door
        let minutes = max(1, Int((meters / walkingMetersPerMinute).rounded(.up)))
        if minutes <= maxWalkingMinutes {
            return String(
                format: NSLocalizedString("%lld min walk", comment: "Walking time to a nearby place, e.g. \"6 min walk\""),
                locale: locale,
                minutes
            )
        }

        let formatter = MeasurementFormatter()
        formatter.locale = locale
        // Keep km or mi as chosen; don't let the formatter switch to the locale's unit
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .medium
        formatter.numberFormatter.locale = locale
        formatter.numberFormatter.maximumFractionDigits = 1
        let distance = Measurement(value: meters, unit: UnitLength.meters)
            .converted(to: useMetric ? .kilometers : .miles)
        return formatter.string(from: distance)
    }
}
