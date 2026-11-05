//
//  HistoricMap.swift
//  Stamped! A City Passport
//
//  Then vs. Now: an old-style map of the city in a chosen year, faded over today's
//  3D map with a slider. The streets, buildings, parks and water come from
//  OpenHistoricalMap (data CC0; free to use, no key), which only serves vector
//  tiles, so each tile is drawn here on the device for the chosen year.
//
//  SwiftUI's Map can't draw tile overlays, so while Then vs. Now is on the city
//  map swaps to this MKMapView with the same camera and landmark pins.
//

import SwiftUI
import MapKit
import ImageIO
import UniformTypeIdentifiers

// MARK: - Settings

/// The years the user can pick, and the credit shown on screen
enum HistoricMap {
    static let years = [1850, 1900, 1925, 1950]
    static let defaultYear = 1900
    /// The old map can show any year in this range (the time walk uses each landmark's own)
    static let yearRange = 1800...2000
    static func clampedYear(_ year: Int) -> Int { min(max(year, yearRange.lowerBound), yearRange.upperBound) }
    static let credit = "Old map: © OpenHistoricalMap contributors (CC0)"
    static let creditURL = URL(string: "https://www.openhistoricalmap.org/copyright")!
}

// MARK: - Map view

/// Apple's 3D satellite map with the old map on top at `opacity`, plus the landmark pins.
struct HistoricMapView: UIViewRepresentable {

    struct Pin: Equatable {
        let id: String
        let title: String
        let coordinate: CLLocationCoordinate2D
        let systemImage: String
        let color: UIColor
        /// An old photo of the landmark, floated above its pin
        var photoURL: URL?

        static func == (lhs: Pin, rhs: Pin) -> Bool {
            lhs.id == rhs.id && lhs.systemImage == rhs.systemImage && lhs.color == rhs.color
                && lhs.photoURL == rhs.photoURL
        }
    }

    /// Moves the camera when its id changes (a landmark tap, or a fly-to from elsewhere)
    struct CameraRequest: Equatable {
        let id = UUID()
        let camera: MapCamera
        let animated: Bool

        static func == (lhs: CameraRequest, rhs: CameraRequest) -> Bool { lhs.id == rhs.id }
    }

    let year: Int
    let opacity: Double
    let pins: [Pin]
    /// Where the camera starts
    let initialCamera: MapCamera
    let cameraRequest: CameraRequest?
    let onSelectPin: (String) -> Void
    /// An old photo above a pin was tapped; without this it acts like its pin
    var onSelectPhoto: ((String) -> Void)? = nil
    let onCameraChange: (MapCamera) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
        mapView.showsCompass = true
        mapView.delegate = context.coordinator
        mapView.register(MKMarkerAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: Coordinator.pinID)
        mapView.register(PhotoAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: Coordinator.photoID)
        mapView.setCamera(Self.mkCamera(initialCamera), animated: false)
        context.coordinator.showYear(year, on: mapView)
        context.coordinator.showPins(pins, on: mapView)
        context.coordinator.lastRequest = cameraRequest
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if coordinator.year != year { coordinator.showYear(year, on: mapView) }
        coordinator.setOpacity(opacity, on: mapView)
        if coordinator.pins != pins { coordinator.showPins(pins, on: mapView) }
        if let cameraRequest, cameraRequest != coordinator.lastRequest {
            coordinator.lastRequest = cameraRequest
            mapView.setCamera(Self.mkCamera(cameraRequest.camera), animated: cameraRequest.animated)
        }
    }

    static func mkCamera(_ camera: MapCamera) -> MKMapCamera {
        MKMapCamera(lookingAtCenter: camera.centerCoordinate, fromDistance: camera.distance,
                    pitch: camera.pitch, heading: camera.heading)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        static let pinID = "landmark"
        static let photoID = "old-photo"

        var parent: HistoricMapView
        var year: Int?
        var pins: [Pin] = []
        var lastRequest: CameraRequest?
        private var pinsCanShow = false
        private var overlay: HistoricTileOverlay?
        private var renderer: MKTileOverlayRenderer?

        init(_ parent: HistoricMapView) { self.parent = parent }

        func showYear(_ year: Int, on mapView: MKMapView) {
            self.year = year
            if let overlay { mapView.removeOverlay(overlay) }
            let newOverlay = HistoricTileOverlay(year: year)
            overlay = newOverlay
            renderer = nil
            mapView.addOverlay(newOverlay, level: .aboveLabels)
        }

        func setOpacity(_ opacity: Double, on mapView: MKMapView) {
            // Old photos fade with the old map
            for annotation in mapView.annotations where annotation is PhotoAnnotation {
                mapView.view(for: annotation)?.setOpacity(opacity)
            }
            guard let renderer, abs(renderer.alpha - opacity) > 0.001 else { return }
            renderer.alpha = opacity
        }

        /// The 3D map drops pins added before it has settled, so they wait for that
        private func mapSettled(_ mapView: MKMapView) {
            guard !pinsCanShow else { return }
            pinsCanShow = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                self.showPins(self.pins, on: mapView)
            }
        }

        func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) { mapSettled(mapView) }

        func showPins(_ pins: [Pin], on mapView: MKMapView) {
            self.pins = pins
            guard pinsCanShow else { return }
            mapView.removeAnnotations(mapView.annotations.filter { $0 is PinAnnotation || $0 is PhotoAnnotation })
            mapView.addAnnotations(pins.map { PinAnnotation($0) })
            mapView.addAnnotations(pins.compactMap { pin in pin.photoURL.map { PhotoAnnotation(pin: pin, url: $0) } })
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let tiles = overlay as? MKTileOverlay else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKTileOverlayRenderer(tileOverlay: tiles)
            renderer.alpha = parent.opacity
            self.renderer = renderer
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let photo = annotation as? PhotoAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: Self.photoID, for: photo)
                (view as? PhotoAnnotationView)?.show(photo.url)
                view.setOpacity(parent.opacity)
                return view
            }
            guard let annotation = annotation as? PinAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: Self.pinID, for: annotation)
            if let marker = view as? MKMarkerAnnotationView {
                #if os(macOS)
                marker.glyphImage = NSImage(systemSymbolName: annotation.pin.systemImage, accessibilityDescription: nil)
                #else
                marker.glyphImage = UIImage(systemName: annotation.pin.systemImage)
                #endif
                marker.markerTintColor = annotation.pin.color
                marker.displayPriority = .required
                marker.titleVisibility = .adaptive
            }
            return view
        }

        #if os(macOS)
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let annotation = view.annotation { selected(annotation, on: mapView) }
        }
        #else
        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            selected(annotation, on: mapView)
        }
        #endif

        private func selected(_ annotation: MKAnnotation, on mapView: MKMapView) {
            if let photo = annotation as? PhotoAnnotation {
                mapView.deselectAnnotation(photo, animated: false)
                (parent.onSelectPhoto ?? parent.onSelectPin)(photo.pin.id)
                return
            }
            guard let annotation = annotation as? PinAnnotation else { return }
            mapView.deselectAnnotation(annotation, animated: false)
            parent.onSelectPin(annotation.pin.id)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            mapSettled(mapView)
            let camera = mapView.camera
            parent.onCameraChange(MapCamera(centerCoordinate: camera.centerCoordinate,
                                            distance: camera.centerCoordinateDistance,
                                            heading: camera.heading, pitch: camera.pitch))
        }
    }

    final class PhotoAnnotation: NSObject, MKAnnotation {
        let pin: Pin
        let url: URL
        var coordinate: CLLocationCoordinate2D { pin.coordinate }
        init(pin: Pin, url: URL) {
            self.pin = pin
            self.url = url
        }
    }

    /// An old photo in a white print border, standing above the landmark's pin
    final class PhotoAnnotationView: MKAnnotationView {
        #if os(macOS)
        /// Lets clicks through to the annotation, which NSImageView would otherwise keep
        private final class ClickThroughImageView: NSImageView {
            override func hitTest(_ point: NSPoint) -> NSView? { nil }
        }
        private let imageView = ClickThroughImageView()
        #else
        private let imageView = UIImageView()
        #endif
        private var loading: Task<Void, Never>?

        // A phone has less room for them
        #if os(visionOS)
        private static let size = CGSize(width: 150, height: 112)
        #else
        private static let size = CGSize(width: 96, height: 72)
        #endif

        override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
            super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
            frame = CGRect(origin: .zero, size: Self.size)
            imageView.frame = bounds.insetBy(dx: 4, dy: 4)
            #if os(macOS)
            wantsLayer = true
            layer?.backgroundColor = NSColor.white.cgColor
            layer?.cornerRadius = 4
            imageView.imageScaling = .scaleProportionallyUpOrDown
            #else
            backgroundColor = .white
            layer.cornerRadius = 4
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.backgroundColor = UIColor(white: 0.85, alpha: 1)
            #endif
            addSubview(imageView)
            // Above the pin, not on top of it
            centerOffset = CGPoint(x: 0, y: -(Self.size.height / 2 + 44))
            displayPriority = .required
            collisionMode = .rectangle
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        func show(_ url: URL) {
            loading?.cancel()
            imageView.image = nil
            loading = Task { [weak self] in
                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      !Task.isCancelled else { return }
                self?.imageView.image = UIImage(data: data)
            }
        }
    }

    final class PinAnnotation: NSObject, MKAnnotation {
        let pin: Pin
        var coordinate: CLLocationCoordinate2D { pin.coordinate }
        var title: String? { pin.title }
        init(_ pin: Pin) { self.pin = pin }
    }
}

private extension MKAnnotationView {
    func setOpacity(_ opacity: Double) {
        #if os(macOS)
        alphaValue = opacity
        #else
        alpha = opacity
        #endif
    }
}

// MARK: - Year and fade controls

/// Floats above the map while Then vs. Now is on: the year, the fade slider and the credit.
struct HistoricMapControls: View {
    @Binding var year: Int
    @Binding var opacity: Double
    /// Old photos from the Library of Congress are on the map
    var showsPhotoCredit = false

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 10) {
            #if os(visionOS)
            HStack(spacing: 16) {
                yearPicker.frame(width: 280)
                fadeSlider(width: 220)
            }
            #else
            // A phone is narrow: the years above the slider
            yearPicker
            fadeSlider(width: nil)
            #endif
            Link(HistoricMap.credit, destination: HistoricMap.creditURL)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if showsPhotoCredit {
                Text("Old photos: Library of Congress, Wikimedia Commons, Europeana, Smithsonian, DPLA; public domain")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        #if os(visionOS)
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .glassBackgroundEffect()
        #else
        .padding(12)
        .background(reduceTransparency ? AnyShapeStyle(Color(UIColor.systemBackground)) : AnyShapeStyle(.regularMaterial),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.top, 8)
        #endif
    }

    private var yearPicker: some View {
        Picker("Year", selection: $year) {
            ForEach(HistoricMap.years, id: \.self) { year in
                Text(verbatim: String(year)).tag(year)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private func fadeSlider(width: CGFloat?) -> some View {
        HStack {
            Text("Now").font(.callout)
            Slider(value: $opacity, in: 0...1)
                .frame(width: width)
                .tint(.orange)
                .accessibilityLabel(Text("Old map"))
                .accessibilityValue(Text("\(Int(opacity * 100)) percent"))
            Text(verbatim: String(year)).font(.callout).monospacedDigit()
        }
    }
}

// MARK: - Tiles

/// Draws OpenHistoricalMap's vector tiles as an old paper map of `year`.
nonisolated final class HistoricTileOverlay: MKTileOverlay, @unchecked Sendable {
    let year: Double

    /// OHM's tiles go to zoom 15; closer in, the zoom-15 tile is drawn larger
    private static let sourceMaxZoom = 15
    private static let tileURL = "https://vtiles.openhistoricalmap.org/maps/ohm/%d/%d/%d.pbf"
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 20 << 20, diskCapacity: 200 << 20)
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpAdditionalHeaders = ["User-Agent": "Stamped! A City Passport"]
        return URLSession(configuration: config)
    }()
    /// Decoded source tiles, shared by the zoomed-in tiles drawn from them
    private static let decoded = NSCache<NSString, VectorTileBox>()

    init(year: Int) {
        self.year = Double(year)
        super.init(urlTemplate: nil)
        tileSize = CGSize(width: 256, height: 256)
        minimumZ = 3
        maximumZ = 20
        canReplaceMapContent = false
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let year = year
        Task.detached(priority: .userInitiated) {
            do {
                let zoom = min(path.z, Self.sourceMaxZoom)
                let shift = path.z - zoom
                let source = try await Self.tile(z: zoom, x: path.x >> shift, y: path.y >> shift)
                let image = HistoricTilePainter.paint(source, year: year, path: path, sourceZoom: zoom)
                result(image, nil)
            } catch {
                result(nil, error)
            }
        }
    }

    private static func tile(z: Int, x: Int, y: Int) async throws -> VectorTile {
        let key = "\(z)/\(x)/\(y)" as NSString
        if let box = decoded.object(forKey: key) { return box.tile }
        let url = URL(string: String(format: tileURL, z, x, y))!
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let tile = VectorTile(data: data)
        decoded.setObject(VectorTileBox(tile), forKey: key)
        return tile
    }
}

nonisolated final class VectorTileBox: @unchecked Sendable {
    let tile: VectorTile
    init(_ tile: VectorTile) { self.tile = tile }
}

// MARK: - Drawing

nonisolated enum HistoricTilePainter {
    private static let pixels = 512

    private static let paper = CGColor(red: 0.94, green: 0.89, blue: 0.78, alpha: 1)
    private static let water = CGColor(red: 0.66, green: 0.76, blue: 0.75, alpha: 1)
    private static let waterEdge = CGColor(red: 0.42, green: 0.55, blue: 0.56, alpha: 1)
    private static let park = CGColor(red: 0.80, green: 0.83, blue: 0.64, alpha: 1)
    private static let land = CGColor(red: 0.90, green: 0.83, blue: 0.69, alpha: 1)
    private static let building = CGColor(red: 0.80, green: 0.62, blue: 0.47, alpha: 1)
    private static let ink = CGColor(red: 0.38, green: 0.27, blue: 0.18, alpha: 1)
    private static let road = CGColor(red: 0.98, green: 0.95, blue: 0.87, alpha: 1)

    static func paint(_ tile: VectorTile, year: Double, path: MKTileOverlayPath, sourceZoom: Int) -> Data? {
        let shift = path.z - sourceZoom
        let scale = Double(1 << shift)
        // Which part of the source tile this tile shows
        let offsetX = Double(path.x - ((path.x >> shift) << shift))
        let offsetY = Double(path.y - ((path.y >> shift) << shift))
        // Line widths grow as the map zooms in, like streets do
        let zoomScale = pow(2, Double(path.z) - 15)

        guard let cg = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                 space: CGColorSpaceCreateDeviceRGB(),
                                 bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        // Tile coordinates run top-down; Core Graphics runs bottom-up
        cg.translateBy(x: 0, y: CGFloat(pixels))
        cg.scaleBy(x: 1, y: -1)
        do {
            cg.setFillColor(paper)
            cg.fill(CGRect(x: 0, y: 0, width: pixels, height: pixels))
            cg.setLineJoin(.round)
            cg.setLineCap(.round)

            func transform(extent: Double) -> CGAffineTransform {
                let unit = Double(pixels) * scale / extent
                return CGAffineTransform(translationX: -offsetX * Double(pixels), y: -offsetY * Double(pixels))
                    .scaledBy(x: unit, y: unit)
            }
            func features(_ layer: String) -> [(VectorTile.Feature, CGAffineTransform)] {
                guard let layer = tile.layers[layer] else { return [] }
                let t = transform(extent: layer.extent)
                return layer.features.filter { $0.exists(in: year) }.map { ($0, t) }
            }
            func fill(_ feature: VectorTile.Feature, _ t: CGAffineTransform, _ color: CGColor) {
                cg.addPath(feature.path(transform: t))
                cg.setFillColor(color)
                cg.fillPath(using: .evenOdd)
            }
            func stroke(_ feature: VectorTile.Feature, _ t: CGAffineTransform, _ color: CGColor, width: Double) {
                cg.addPath(feature.path(transform: t))
                cg.setStrokeColor(color)
                cg.setLineWidth(width)
                cg.strokePath()
            }

            for (feature, t) in features("landuse_areas") where feature.geometryType == 3 {
                let parkLike = ["park", "garden", "grass", "cemetery", "recreation_ground",
                                "wood", "forest", "meadow", "golf_course", "farmland"]
                fill(feature, t, parkLike.contains(feature.type) ? park : land)
            }
            for (feature, t) in features("water_areas") where feature.geometryType == 3 {
                fill(feature, t, water)
                stroke(feature, t, waterEdge, width: 1.5)
            }
            for (feature, t) in features("water_lines") {
                stroke(feature, t, water, width: max(2, 4 * zoomScale))
            }
            for (feature, t) in features("buildings") where feature.geometryType == 3 {
                fill(feature, t, building)
                stroke(feature, t, ink.copy(alpha: 0.6)!, width: 0.75)
            }

            // Streets: a dark ink edge with a pale middle, like an engraved map
            let streets = features("transport_lines").filter { $0.0.featureClass == "highway" }
            let widths = streets.map { roadWidth($0.0.type, zoomScale: zoomScale) }
            for ((feature, t), width) in zip(streets, widths) where width > 0 {
                stroke(feature, t, ink, width: width + 2)
            }
            for ((feature, t), width) in zip(streets, widths) where width > 2 {
                stroke(feature, t, road, width: width)
            }
            // Railways: thin ink lines with cross ties
            for (feature, t) in features("transport_lines") where feature.featureClass == "railway" {
                stroke(feature, t, ink, width: 1.5)
                cg.saveGState()
                // Square ends: round ones would grow each tie until the gaps closed
                cg.setLineCap(.butt)
                cg.setLineDash(phase: 0, lengths: [1.5, 6])
                stroke(feature, t, ink, width: 6)
                cg.restoreGState()
            }
        }
        guard let image = cg.makeImage() else { return nil }
        let png = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(png, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? png as Data : nil
    }

    /// Street width in pixels at zoom 15, by OpenStreetMap highway type; 0 hides it
    private static func roadWidth(_ type: String, zoomScale: Double) -> Double {
        let base: Double = switch type {
        case "motorway", "trunk": 9
        case "primary": 8
        case "secondary": 7
        case "tertiary": 6
        case "residential", "unclassified", "living_street", "road": 4.5
        case "service", "pedestrian": 2.5
        case "footway", "path", "cycleway", "steps", "track": zoomScale >= 2 ? 1 : 0
        default: 2
        }
        return min(base * zoomScale, 60)
    }
}

// MARK: - Vector tile decoding

/// A Mapbox Vector Tile (protocol buffers), keeping just what the old map draws.
nonisolated struct VectorTile: Sendable {

    struct Layer: Sendable {
        var extent: Double = 4096
        var features: [Feature] = []
    }

    struct Feature: Sendable {
        var geometryType = 0
        var geometry: [UInt32] = []
        var featureClass = ""
        var type = ""
        var start: Double?
        var end: Double?

        /// OpenHistoricalMap dates are decimal years; a missing date means "always"
        func exists(in year: Double) -> Bool {
            (start ?? -.infinity) <= year && year < (end ?? .infinity)
        }

        func path(transform: CGAffineTransform) -> CGPath {
            let path = CGMutablePath()
            var x: Int32 = 0, y: Int32 = 0
            var i = 0
            func point() -> CGPoint {
                CGPoint(x: Double(x), y: Double(y)).applying(transform)
            }
            while i < geometry.count {
                let command = geometry[i] & 0x7
                let count = Int(geometry[i] >> 3)
                i += 1
                if command == 7 { path.closeSubpath(); continue }
                for _ in 0..<count where i + 1 < geometry.count {
                    x &+= Self.zigzag(geometry[i]); y &+= Self.zigzag(geometry[i + 1])
                    i += 2
                    if command == 1 { path.move(to: point()) } else { path.addLine(to: point()) }
                }
            }
            return path
        }

        private static func zigzag(_ n: UInt32) -> Int32 {
            Int32(bitPattern: (n >> 1)) ^ -Int32(bitPattern: n & 1)
        }
    }

    private static let wantedLayers: Set<String> = [
        "landuse_areas", "water_areas", "water_lines", "buildings", "transport_lines",
    ]

    var layers: [String: Layer] = [:]

    init(data: Data) {
        var reader = ProtoReader(bytes: [UInt8](data))
        while let (field, wire) = reader.nextField() {
            if field == 3, wire == 2 {
                let range = reader.lengthDelimited()
                if let (name, layer) = Self.layer(reader.bytes, range) { layers[name] = layer }
            } else {
                reader.skip(wire)
            }
        }
    }

    private enum Value { case string(String), number(Double), other }

    private static func layer(_ bytes: [UInt8], _ range: Range<Int>) -> (String, Layer)? {
        var reader = ProtoReader(bytes: bytes, range: range)
        var name = ""
        var layer = Layer()
        var keys: [String] = []
        var values: [Value] = []
        var featureRanges: [Range<Int>] = []
        while let (field, wire) = reader.nextField() {
            switch (field, wire) {
            case (1, 2): name = reader.string()
                // Skip layers the old map doesn't draw, before decoding their features
                if !wantedLayers.contains(name) { return nil }
            case (2, 2): featureRanges.append(reader.lengthDelimited())
            case (3, 2): keys.append(reader.string())
            case (4, 2): values.append(value(bytes, reader.lengthDelimited()))
            case (5, 0): layer.extent = Double(reader.varint())
            default: reader.skip(wire)
            }
        }
        guard wantedLayers.contains(name) else { return nil }

        for range in featureRanges {
            var reader = ProtoReader(bytes: bytes, range: range)
            var feature = Feature()
            while let (field, wire) = reader.nextField() {
                switch (field, wire) {
                case (2, 2):
                    let tags = reader.packed()
                    for pair in stride(from: 0, to: tags.count - 1, by: 2) {
                        let k = Int(tags[pair]), v = Int(tags[pair + 1])
                        guard k < keys.count, v < values.count else { continue }
                        switch (keys[k], values[v]) {
                        case ("class", .string(let s)): feature.featureClass = s
                        case ("type", .string(let s)): feature.type = s
                        case ("start_decdate", .number(let d)): feature.start = d
                        case ("end_decdate", .number(let d)): feature.end = d
                        default: break
                        }
                    }
                case (3, 0): feature.geometryType = Int(reader.varint())
                case (4, 2): feature.geometry = reader.packed()
                default: reader.skip(wire)
                }
            }
            layer.features.append(feature)
        }
        return (name, layer)
    }

    private static func value(_ bytes: [UInt8], _ range: Range<Int>) -> Value {
        var reader = ProtoReader(bytes: bytes, range: range)
        var result = Value.other
        while let (field, wire) = reader.nextField() {
            switch (field, wire) {
            case (1, 2): result = .string(reader.string())
            case (2, 5): result = .number(Double(Float(bitPattern: reader.fixed32())))
            case (3, 1): result = .number(Double(bitPattern: reader.fixed64()))
            case (4, 0), (5, 0): result = .number(Double(Int64(bitPattern: reader.varint())))
            case (6, 0):
                let n = reader.varint()
                result = .number(Double(Int64(bitPattern: n >> 1) ^ -Int64(bitPattern: n & 1)))
            default: reader.skip(wire)
            }
        }
        return result
    }
}

/// Reads protocol buffer fields from a byte array.
nonisolated private struct ProtoReader {
    let bytes: [UInt8]
    private var index: Int
    private let end: Int

    init(bytes: [UInt8], range: Range<Int>? = nil) {
        self.bytes = bytes
        index = range?.lowerBound ?? 0
        end = range?.upperBound ?? bytes.count
    }

    mutating func nextField() -> (Int, Int)? {
        guard index < end else { return nil }
        let key = varint()
        return (Int(key >> 3), Int(key & 7))
    }

    mutating func varint() -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while index < end {
            let byte = bytes[index]
            index += 1
            if shift < 64 { result |= UInt64(byte & 0x7f) << shift }
            if byte < 0x80 { break }
            shift += 7
        }
        return result
    }

    mutating func lengthDelimited() -> Range<Int> {
        // A corrupt tile can claim any length, even more than Int holds
        let length = varint()
        let start = index
        index = length < UInt64(end - index) ? index + Int(length) : end
        return start..<index
    }

    mutating func string() -> String {
        String(decoding: bytes[lengthDelimited()], as: UTF8.self)
    }

    mutating func packed() -> [UInt32] {
        let range = lengthDelimited()
        var inner = ProtoReader(bytes: bytes, range: range)
        var values: [UInt32] = []
        values.reserveCapacity(range.count)
        while inner.index < inner.end { values.append(UInt32(truncatingIfNeeded: inner.varint())) }
        return values
    }

    mutating func fixed32() -> UInt32 {
        var value: UInt32 = 0
        for shift in 0..<4 where index < end {
            value |= UInt32(bytes[index]) << (shift * 8)
            index += 1
        }
        return value
    }

    mutating func fixed64() -> UInt64 {
        var value: UInt64 = 0
        for shift in 0..<8 where index < end {
            value |= UInt64(bytes[index]) << (shift * 8)
            index += 1
        }
        return value
    }

    mutating func skip(_ wire: Int) {
        switch wire {
        case 0: _ = varint()
        case 1: index = min(index + 8, end)
        case 2: _ = lengthDelimited()
        case 5: index = min(index + 4, end)
        default: index = end
        }
    }
}
