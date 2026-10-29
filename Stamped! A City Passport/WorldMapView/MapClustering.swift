//
//  MapClustering.swift
//  Stamped! A City Passport
//
//  Groups map pins that would overlap on screen into one numbered bubble.
//  SwiftUI's Map has no clustering of its own, so this works it out from the
//  visible region and the map's size each time the camera stops moving.
//

import SwiftUI
import MapKit

/// One bubble on the map: a single pin, or several pins drawn as one.
struct MapCluster<Item: Identifiable>: Identifiable where Item.ID == String {
    let items: [Item]
    let coordinate: CLLocationCoordinate2D

    /// A lone pin keeps its item's ID, so SwiftUI treats it as the same pin as before.
    var id: String { items.count == 1 ? items[0].id : "cluster-" + items[0].id }
    var isCluster: Bool { items.count > 1 }

    /// The region that frames every pin in the bubble, with room to spare.
    /// Never tighter than `minimumSpan`, so a tap always zooms in far enough to split it.
    func zoomRegion(coordinateOf: (Item) -> CLLocationCoordinate2D, minimumSpan: CLLocationDegrees) -> MKCoordinateRegion {
        let coordinates = items.map(coordinateOf)
        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((lats.max()! - lats.min()!) * 2.5, minimumSpan),
            longitudeDelta: max((lons.max()! - lons.min()!) * 2.5, minimumSpan)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    /// A camera over the middle of the bubble's pins, far enough out to show them all.
    /// Never closer than `minimumDistance` metres, so the city stays in view.
    func zoomCamera(coordinateOf: (Item) -> CLLocationCoordinate2D, minimumDistance: CLLocationDistance,
                    heading: CLLocationDirection = 0, pitch: Double) -> MapCamera {
        let coordinates = items.map(coordinateOf)
        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        let corner1 = CLLocation(latitude: lats.min()!, longitude: lons.min()!)
        let corner2 = CLLocation(latitude: lats.max()!, longitude: lons.max()!)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let distance = max(corner1.distance(from: corner2) * 3, minimumDistance)
        return MapCamera(centerCoordinate: center, distance: distance, heading: heading, pitch: pitch)
    }
}

enum MapClusterer {
    /// Groups items whose pins sit closer than `radius` screen points.
    /// - Parameters:
    ///   - region: What the map is showing now. Nil (before the map has drawn) shows every pin on its own.
    ///   - mapWidth: The map's width on screen, in points.
    ///   - minimumSpan: Below this many degrees across, nothing is grouped, so pins
    ///     that share almost the same spot still come apart once you zoom right in.
    static func clusters<Item: Identifiable>(
        of items: [Item],
        coordinateOf: (Item) -> CLLocationCoordinate2D,
        region: MKCoordinateRegion?,
        mapWidth: CGFloat,
        radius: CGFloat = 28,
        minimumSpan: CLLocationDegrees = 1
    ) -> [MapCluster<Item>] where Item.ID == String {
        let singles = items.map { MapCluster(items: [$0], coordinate: coordinateOf($0)) }
        guard let region, mapWidth > 0, region.span.longitudeDelta >= minimumSpan else { return singles }

        // Work in flat map points (Web Mercator), where screen distance is the same in every direction
        let mapPointsPerScreenPoint = MKMapSize.world.width * min(region.span.longitudeDelta, 360) / 360 / Double(mapWidth)
        let threshold = Double(radius) * mapPointsPerScreenPoint

        // Sorted by ID so the same pins always group the same way
        let sorted = items.sorted { $0.id < $1.id }
        let points = sorted.map { MKMapPoint(coordinateOf($0)) }
        var taken = [Bool](repeating: false, count: sorted.count)
        var result: [MapCluster<Item>] = []

        for i in sorted.indices where !taken[i] {
            taken[i] = true
            var members = [i]
            for j in sorted.indices where !taken[j] {
                let dx = points[i].x - points[j].x
                let dy = points[i].y - points[j].y
                if dx * dx + dy * dy < threshold * threshold {
                    taken[j] = true
                    members.append(j)
                }
            }
            // The bubble sits at the middle of its pins
            let x = members.map { points[$0].x }.reduce(0, +) / Double(members.count)
            let y = members.map { points[$0].y }.reduce(0, +) / Double(members.count)
            result.append(MapCluster(items: members.map { sorted[$0] }, coordinate: MKMapPoint(x: x, y: y).coordinate))
        }
        return result
    }

    /// Groups items whose pins sit closer than `radius` on screen, using where each pin
    /// was actually drawn (from `MapProxy.convert`). Unlike the region-based version above,
    /// this is right for a tilted 3D camera too. Items without a screen point stay on their own.
    static func clusters<Item: Identifiable>(
        of items: [Item],
        coordinateOf: (Item) -> CLLocationCoordinate2D,
        screenPoints: [String: CGPoint],
        radius: CGFloat = 28
    ) -> [MapCluster<Item>] where Item.ID == String {
        let sorted = items.sorted { $0.id < $1.id }
        var taken = [Bool](repeating: false, count: sorted.count)
        var result: [MapCluster<Item>] = []

        for i in sorted.indices where !taken[i] {
            taken[i] = true
            var members = [i]
            if let point = screenPoints[sorted[i].id] {
                for j in sorted.indices where !taken[j] {
                    guard let other = screenPoints[sorted[j].id] else { continue }
                    if hypot(point.x - other.x, point.y - other.y) < radius {
                        taken[j] = true
                        members.append(j)
                    }
                }
            }
            // Within a city, a plain average of the coordinates is the middle of the pins
            let coordinates = members.map { coordinateOf(sorted[$0]) }
            let center = CLLocationCoordinate2D(
                latitude: coordinates.map(\.latitude).reduce(0, +) / Double(coordinates.count),
                longitude: coordinates.map(\.longitude).reduce(0, +) / Double(coordinates.count)
            )
            result.append(MapCluster(items: members.map { sorted[$0] }, coordinate: center))
        }
        return result
    }

    /// Where each item's pin is on screen now, keyed by ID, for `clusters(of:coordinateOf:screenPoints:)`.
    /// Empty when the camera is closer than `minimumDistance` metres, so zoomed right in every pin shows on its own.
    static func screenPoints<Item: Identifiable>(
        of items: [Item],
        coordinateOf: (Item) -> CLLocationCoordinate2D,
        proxy: MapProxy,
        camera: MapCamera?,
        minimumDistance: CLLocationDistance
    ) -> [String: CGPoint] where Item.ID == String {
        guard let camera, camera.distance > minimumDistance else { return [:] }
        var points: [String: CGPoint] = [:]
        for item in items {
            points[item.id] = proxy.convert(coordinateOf(item), to: .local)
        }
        return points
    }
}

/// The numbered bubble drawn in place of several pins. On the world map it's orange once any
/// of them is visited, matching the pins it stands for; other maps pass their own colours.
struct MapClusterBubble: View {
    let count: Int
    let fill: Color
    let foreground: Color
    let stroke: Color
    var strokeWidth: CGFloat = 2.5
    /// The smallest bubble; larger counts get a little bigger.
    var baseDiameter: CGFloat = 26
    /// What VoiceOver says; "4 places" unless a map has something better.
    var label: Text? = nil
    /// What the bubble shows instead of the count, such as a trip's stop numbers ("1–4").
    var title: String? = nil

    /// The world map's bubble: orange like a visited pin, or white like a "not yet" pin.
    init(count: Int, anyVisited: Bool) {
        self.count = count
        fill = anyVisited ? Color.adventureOrange : Color.white
        foreground = anyVisited ? Color.white : Color(UIColor.darkGray)
        stroke = anyVisited ? Color.white : Color(UIColor.systemGray2)
        strokeWidth = anyVisited ? 2.5 : 1.5
    }

    init(count: Int, fill: Color, foreground: Color = .white, stroke: Color = .white,
         strokeWidth: CGFloat = 2, baseDiameter: CGFloat, label: Text? = nil, title: String? = nil) {
        self.count = count
        self.fill = fill
        self.foreground = foreground
        self.stroke = stroke
        self.strokeWidth = strokeWidth
        self.baseDiameter = baseDiameter
        self.label = label
        self.title = title
    }

    private var diameter: CGFloat {
        switch count {
        case ..<10:  return baseDiameter
        case ..<50:  return baseDiameter + 6
        default:     return baseDiameter + 12
        }
    }

    var body: some View {
        Text(title ?? "\(count)")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(foreground)
            .lineLimit(1)
            // A circle for a number; a longer title stretches it into a capsule
            .padding(.horizontal, title == nil ? 0 : 6)
            .frame(minWidth: diameter, minHeight: diameter, maxHeight: diameter)
            .background(Capsule().fill(fill))
            .overlay(Capsule().stroke(stroke, lineWidth: strokeWidth))
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            .contentShape(Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label ?? Text("\(count) places"))
            .accessibilityHint(Text("Zooms in on these places"))
            .accessibilityAddTraits(.isButton)
    }
}
