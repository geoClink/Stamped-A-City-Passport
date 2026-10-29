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

    @State private var position: MapCameraPosition
    /// Where each stop's badge sat on screen when the camera last stopped (for grouping badges that overlap).
    @State private var stopScreenPoints: [String: CGPoint] = [:]
    @ScaledMetric(relativeTo: .caption) private var clusterSize: CGFloat = 26

    init(stops: [ResolvedTripStop], cityCenter: CLLocationCoordinate2D?) {
        self.stops = stops
        self.cityCenter = cityCenter
        _position = State(initialValue: Self.startPosition(stops: stops, cityCenter: cityCenter))
    }

    /// A located stop with its 1-based number in the day's full list.
    private struct NumberedStop: Identifiable {
        let number: Int
        let stop: ResolvedTripStop
        let coordinate: CLLocationCoordinate2D
        var id: String { stop.id }
    }

    private var numberedStops: [NumberedStop] {
        stops.enumerated().compactMap { index, stop in
            guard let point = stop.routePoint else { return nil }
            let coordinate = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
            return NumberedStop(number: index + 1, stop: stop, coordinate: coordinate)
        }
    }

    /// Badges grouped into one bubble where they'd overlap (two stops in the same building, say).
    private var stopClusters: [MapCluster<NumberedStop>] {
        MapClusterer.clusters(of: numberedStops, coordinateOf: \.coordinate, screenPoints: stopScreenPoints)
    }

    /// Closer than this (metres), every stop shows its own number.
    private static let clusteringMinimumDistance: CLLocationDistance = 400

    var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                if numberedStops.count > 1 {
                    MapPolyline(coordinates: numberedStops.map(\.coordinate))
                        .stroke(DS.Palette.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 5]))
                }
                ForEach(stopClusters) { cluster in
                    if cluster.isCluster {
                        Annotation("", coordinate: cluster.coordinate) {
                            clusterBubble(for: cluster)
                                .onTapGesture { zoom(into: cluster) }
                        }
                        .annotationTitles(.hidden)
                    } else {
                        let item = cluster.items[0]
                        Annotation(item.stop.name, coordinate: item.coordinate) {
                            StopNumberBadge(number: item.number, isLandmark: item.stop.isLandmark)
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .onMapCameraChange(frequency: .onEnd) { context in
                stopScreenPoints = MapClusterer.screenPoints(
                    of: numberedStops,
                    coordinateOf: \.coordinate,
                    proxy: proxy,
                    camera: context.camera,
                    minimumDistance: Self.clusteringMinimumDistance
                )
            }
        }
        // Keeps pins and their names from sitting right on the map's edges
        .safeAreaPadding(DS.Space.xl)
        // Rebuild the map when the stops change (another day, a reorder, an
        // optimize). Map doesn't reliably redraw its line otherwise, and a
        // fresh map also re-frames itself around the new stops.
        .id(stops.map(\.id))
        .onChange(of: stops.map(\.id)) {
            stopScreenPoints = [:]
            position = Self.startPosition(stops: stops, cityCenter: cityCenter)
        }
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

    /// Shows the stop numbers it holds ("1–4", or "2, 5"), so it can't be mistaken for a single
    /// stop's badge. Pink when every stop in it is a saved place, like their badges.
    private func clusterBubble(for cluster: MapCluster<NumberedStop>) -> some View {
        let numbers = cluster.items.map(\.number).sorted()
        let isRun = numbers.last! - numbers.first! == numbers.count - 1
        let title = isRun ? "\(numbers.first!)–\(numbers.last!)"
            : numbers.count <= 3 ? numbers.map(String.init).joined(separator: ", ")
            : "\(numbers.first!)–\(numbers.last!)…"
        return MapClusterBubble(
            count: cluster.items.count,
            fill: cluster.items.contains(where: \.stop.isLandmark) ? DS.Palette.accent : DS.Palette.wishlist,
            baseDiameter: clusterSize,
            label: Text("Stops \(numbers.map(String.init).formatted(.list(type: .and)))"),
            title: title
        )
    }

    /// Tapping a bubble zooms in until its stops come apart.
    private func zoom(into cluster: MapCluster<NumberedStop>) {
        let camera = cluster.zoomCamera(coordinateOf: \.coordinate, minimumDistance: 300, pitch: 0)
        withAnimation(.easeInOut(duration: 0.8)) {
            position = .camera(camera)
        }
    }

    /// With stops, frame them all automatically. With none, show the city
    /// rather than the whole country.
    private static func startPosition(stops: [ResolvedTripStop], cityCenter: CLLocationCoordinate2D?) -> MapCameraPosition {
        guard !stops.contains(where: { $0.routePoint != nil }), let cityCenter else { return .automatic }
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
