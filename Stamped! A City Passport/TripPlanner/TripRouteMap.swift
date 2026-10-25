//
//  TripRouteMap.swift
//  Stamped! A City Passport
//
//  A small map of one day: numbered pins in walking order, joined by a
//  dashed line. The numbers match the stop numbers in the list below it.
//

import SwiftUI
import MapKit

struct TripRouteMap: View {
    /// The day's stops in order. Stops without a location are skipped on the map.
    let stops: [ResolvedTripStop]
    /// Where to centre the map before any stops are added (the middle of the city).
    let cityCenter: CLLocationCoordinate2D?

    /// Each located stop with its 1-based number in the day's full list.
    private var numberedStops: [(number: Int, stop: ResolvedTripStop, coordinate: CLLocationCoordinate2D)] {
        stops.enumerated().compactMap { index, stop in
            guard let point = stop.routePoint else { return nil }
            let coordinate = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
            return (index + 1, stop, coordinate)
        }
    }

    var body: some View {
        Map(initialPosition: startPosition) {
            if numberedStops.count > 1 {
                MapPolyline(coordinates: numberedStops.map(\.coordinate))
                    .stroke(DS.Palette.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 5]))
            }
            ForEach(numberedStops, id: \.stop.id) { item in
                Annotation(item.stop.name, coordinate: item.coordinate) {
                    StopNumberBadge(number: item.number, isLandmark: item.stop.isLandmark)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        // Keeps pins and their names from sitting right on the map's edges
        .safeAreaPadding(DS.Space.xl)
        // Rebuild the map when the stops change (another day, a reorder, an
        // optimize). Map doesn't reliably redraw its line otherwise, and a
        // fresh map also re-frames itself around the new stops.
        .id(stops.map(\.id))
        .overlay {
            if numberedStops.isEmpty {
                Text("Add stops to see your route")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, DS.Space.l)
                    .padding(.vertical, DS.Space.s)
                    .background(.regularMaterial, in: Capsule())
            }
        }
        .accessibilityLabel("Map of this day's route, \(numberedStops.count) stops")
    }

    /// With stops, frame them all automatically. With none, show the city
    /// rather than the whole country.
    private var startPosition: MapCameraPosition {
        guard numberedStops.isEmpty, let cityCenter else { return .automatic }
        return .region(MKCoordinateRegion(center: cityCenter, latitudinalMeters: 4000, longitudinalMeters: 4000))
    }

    /// The middle of a city's landmarks. Uses the median rather than the
    /// average so one far-away landmark doesn't pull the centre off.
    static func center(of buildings: [Building]) -> CLLocationCoordinate2D? {
        let latitudes = buildings.compactMap(\.latitude).sorted()
        let longitudes = buildings.compactMap(\.longitude).sorted()
        guard !latitudes.isEmpty, !longitudes.isEmpty else { return nil }
        return CLLocationCoordinate2D(
            latitude: latitudes[latitudes.count / 2],
            longitude: longitudes[longitudes.count / 2]
        )
    }
}

/// The numbered circle used on the map and in the stop list, so they match.
struct StopNumberBadge: View {
    let number: Int
    let isLandmark: Bool

    /// Scales with the caption text so two-digit numbers still fit at large sizes
    @ScaledMetric(relativeTo: .caption) private var size: CGFloat = 26

    var body: some View {
        Text("\(number)")
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .minimumScaleFactor(0.7)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            // Pink like saved places' pins on the city map
            .background(isLandmark ? DS.Palette.accent : DS.Palette.wishlist, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            // The shadow lifts the pin off the map behind it
            .shadow(radius: 2)
    }
}
