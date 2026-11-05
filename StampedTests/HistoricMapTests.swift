//
//  HistoricMapTests.swift
//  StampedTests
//
//  The old map: decoding Mapbox Vector Tiles byte by byte, and drawing them.
//

import XCTest
import MapKit
import ImageIO
@testable import Stamped_

/// Writes the protocol buffer bytes of a small vector tile.
private enum PB {
    static func varint(_ value: UInt64) -> [UInt8] {
        var value = value, bytes: [UInt8] = []
        repeat {
            var byte = UInt8(value & 0x7f)
            value >>= 7
            if value != 0 { byte |= 0x80 }
            bytes.append(byte)
        } while value != 0
        return bytes
    }
    static func key(_ field: UInt64, _ wire: UInt64) -> [UInt8] { varint(field << 3 | wire) }
    static func bytes(_ field: UInt64, _ content: [UInt8]) -> [UInt8] { key(field, 2) + varint(UInt64(content.count)) + content }
    static func string(_ field: UInt64, _ text: String) -> [UInt8] { bytes(field, Array(text.utf8)) }
    static func number(_ field: UInt64, _ value: UInt64) -> [UInt8] { key(field, 0) + varint(value) }
    static func packed(_ field: UInt64, _ values: [UInt32]) -> [UInt8] { bytes(field, values.flatMap { varint(UInt64($0)) }) }
    static func zigzag(_ n: Int32) -> UInt32 { UInt32(bitPattern: (n << 1) ^ (n >> 31)) }
    static func double(_ value: Double) -> [UInt8] {
        key(3, 1) + withUnsafeBytes(of: value.bitPattern.littleEndian, Array.init)
    }
    static func float(_ value: Float) -> [UInt8] {
        key(2, 5) + withUnsafeBytes(of: value.bitPattern.littleEndian, Array.init)
    }

    /// Geometry commands: move to the first point, then a line through the rest
    static func line(_ points: [(Int32, Int32)], close: Bool = false) -> [UInt32] {
        var x: Int32 = 0, y: Int32 = 0
        var out: [UInt32] = []
        for (index, point) in points.enumerated() {
            if index == 0 { out.append(1 << 3 | 1) }
            if index == 1 { out.append(UInt32(points.count - 1) << 3 | 2) }
            out += [zigzag(point.0 - x), zigzag(point.1 - y)]
            (x, y) = point
        }
        if close { out.append(1 << 3 | 7) }
        return out
    }

    static func feature(type: UInt64, geometry: [UInt32], tags: [UInt32] = []) -> [UInt8] {
        packed(2, tags) + number(3, type) + packed(4, geometry)
    }

    /// keys and values are shared by the layer's features; features refer to them by index
    static func layer(_ name: String, extent: UInt64 = 4096, keys: [String] = [], values: [[UInt8]] = [],
                      features: [[UInt8]]) -> [UInt8] {
        var content = string(1, name) + number(15, 2)
        for feature in features { content += bytes(2, feature) }
        for key in keys { content += string(3, key) }
        for value in values { content += bytes(4, value) }
        return bytes(3, content + number(5, extent))
    }
}

final class HistoricMapTests: XCTestCase {

    private func tile(_ layers: [UInt8]...) -> VectorTile { VectorTile(data: Data(layers.flatMap { $0 })) }

    private let square = PB.line([(1024, 1024), (3072, 1024), (3072, 3072), (1024, 3072)], close: true)

    // MARK: Decoding

    func testLayerFeatureAndTagsAreRead() throws {
        let tile = tile(PB.layer("buildings", extent: 512, keys: ["class", "type", "start_decdate", "end_decdate"],
                                 values: [PB.string(1, "building"), PB.string(1, "yes"), PB.double(1890.5), PB.float(1950)],
                                 features: [PB.feature(type: 3, geometry: square, tags: [0, 0, 1, 1, 2, 2, 3, 3])]))
        let layer = try XCTUnwrap(tile.layers["buildings"])
        XCTAssertEqual(layer.extent, 512)
        let feature = try XCTUnwrap(layer.features.first)
        XCTAssertEqual(feature.geometryType, 3)
        XCTAssertEqual(feature.featureClass, "building")
        XCTAssertEqual(feature.type, "yes")
        XCTAssertEqual(feature.start, 1890.5)
        XCTAssertEqual(feature.end, 1950)
    }

    func testAllNumberFormsAreRead() throws {
        // Fields 4 (int), 5 (uint) and 6 (sint, zigzag) as well as float and double
        let tile = tile(PB.layer("buildings", keys: ["start_decdate", "end_decdate"],
                                 values: [PB.number(6, UInt64(PB.zigzag(-44))), PB.number(5, 1900)],
                                 features: [PB.feature(type: 3, geometry: square, tags: [0, 0, 1, 1])]))
        let feature = try XCTUnwrap(tile.layers["buildings"]?.features.first)
        XCTAssertEqual(feature.start, -44)
        XCTAssertEqual(feature.end, 1900)
    }

    func testLayersTheMapDoesntDrawAreSkipped() {
        let tile = tile(PB.layer("place_labels", features: [PB.feature(type: 1, geometry: [9, 0, 0])]),
                        PB.layer("water_lines", features: [PB.feature(type: 2, geometry: square)]))
        XCTAssertEqual(Array(tile.layers.keys), ["water_lines"])
    }

    func testBadTagIndexesAreIgnored() throws {
        let tile = tile(PB.layer("buildings", keys: ["type"], values: [PB.string(1, "yes")],
                                 features: [PB.feature(type: 3, geometry: square, tags: [5, 9, 0])]))
        XCTAssertEqual(tile.layers["buildings"]?.features.first?.type, "")
    }

    func testGeometryTurnsIntoAPath() throws {
        var feature = VectorTile.Feature()
        feature.geometry = PB.line([(100, 200), (300, 200), (300, -50)])
        let box = feature.path(transform: .identity).boundingBoxOfPath
        XCTAssertEqual(box, CGRect(x: 100, y: -50, width: 200, height: 250))
    }

    func testGeometryWithMissingNumbersDoesntCrash() {
        var feature = VectorTile.Feature()
        feature.geometry = [2 << 3 | 1, 4, 4, 2]  // says two points, gives one and a half
        XCTAssertFalse(feature.path(transform: .identity).isEmpty)
        feature.geometry = [UInt32.max]
        XCTAssertTrue(feature.path(transform: .identity).isEmpty)
    }

    /// A server error page or a cut-off download reaches the decoder as junk
    func testJunkDataIsSurvived() {
        XCTAssertTrue(VectorTile(data: Data()).layers.isEmpty)
        XCTAssertTrue(VectorTile(data: Data("<html>502 Bad Gateway</html>".utf8)).layers.isEmpty)
        let whole = PB.layer("buildings", features: [PB.feature(type: 3, geometry: square)])
        for length in 0..<whole.count { _ = VectorTile(data: Data(whole.prefix(length))) }
    }

    /// A length of 2^63 or more must not crash the app
    func testHugeLengthsAreSurvived() {
        let huge = PB.key(3, 2) + [UInt8](repeating: 0xff, count: 9) + [0x01]
        XCTAssertTrue(VectorTile(data: Data(huge)).layers.isEmpty)
        let nearlyHuge = PB.key(3, 2) + PB.varint(UInt64(Int.max))
        XCTAssertTrue(VectorTile(data: Data(nearlyHuge)).layers.isEmpty)
        let layer = PB.bytes(3, PB.key(2, 2) + PB.varint(UInt64.max))
        _ = VectorTile(data: Data(layer))
    }

    // MARK: Which features a year shows

    func testAFeatureExistsFromItsStartUntilItsEnd() {
        var feature = VectorTile.Feature()
        XCTAssertTrue(feature.exists(in: 1900), "no dates means always")
        feature.start = 1890
        feature.end = 1950
        XCTAssertFalse(feature.exists(in: 1889.9))
        XCTAssertTrue(feature.exists(in: 1890))
        XCTAssertTrue(feature.exists(in: 1949.9))
        XCTAssertFalse(feature.exists(in: 1950), "gone by its end date")
    }

    func testYearsAreKeptInRange() {
        XCTAssertEqual(HistoricMap.clampedYear(1500), 1800)
        XCTAssertEqual(HistoricMap.clampedYear(2030), 2000)
        XCTAssertEqual(HistoricMap.clampedYear(1912), 1912)
        XCTAssertTrue(HistoricMap.years.contains(HistoricMap.defaultYear))
    }

    // MARK: Drawing

    /// The drawn tile, with a way to read a pixel's colour
    private struct Picture {
        let pixels: [UInt8]
        let width: Int

        init(png: Data) throws {
            let source = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            width = image.width
            var bytes = [UInt8](repeating: 0, count: width * image.height * 4)
            let context = try XCTUnwrap(CGContext(data: &bytes, width: width, height: image.height, bitsPerComponent: 8,
                                                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: image.height))
            pixels = bytes
        }

        /// (0, 0) is the top left, as on the map
        func color(_ x: Int, _ y: Int) -> [Int] {
            let start = (y * width + x) * 4
            return pixels[start..<start + 3].map(Int.init)
        }
    }

    // As read back from the PNG, after colour conversion
    private let paper = [243, 232, 209]
    private let water = [182, 204, 203]

    private func assertColor(_ picture: Picture, _ x: Int, _ y: Int, _ expected: [Int], _ what: String,
                             line: UInt = #line) {
        let found = picture.color(x, y)
        let close = zip(found, expected).allSatisfy { abs($0 - $1) <= 6 }
        XCTAssertTrue(close, "\(what) at (\(x), \(y)): \(found), expected \(expected)", line: line)
    }

    private func paint(_ tile: VectorTile, year: Double = 1900, z: Int = 15, x: Int = 0, y: Int = 0, sourceZoom: Int = 15) throws -> Picture {
        let path = MKTileOverlayPath(x: x, y: y, z: z, contentScaleFactor: 2)
        return try Picture(png: try XCTUnwrap(HistoricTilePainter.paint(tile, year: year, path: path, sourceZoom: sourceZoom)))
    }

    private var lake: VectorTile { tile(PB.layer("water_areas", features: [PB.feature(type: 3, geometry: square)])) }

    func testAnEmptyTileIsPaper() throws {
        let picture = try paint(tile())
        XCTAssertEqual(picture.width, 512)
        assertColor(picture, 256, 256, paper, "paper")
    }

    /// Tile coordinates run down the page: a shape at the top stays at the top
    func testShapesLandWhereTheTileSays() throws {
        let top = PB.line([(0, 0), (4096, 0), (4096, 1024), (0, 1024)], close: true)
        let picture = try paint(tile(PB.layer("water_areas", features: [PB.feature(type: 3, geometry: top)])))
        assertColor(picture, 256, 50, water, "water at the top")
        assertColor(picture, 256, 460, paper, "paper at the bottom")
    }

    func testTheExtentSetsTheScale() throws {
        let square256 = PB.line([(64, 64), (192, 64), (192, 192), (64, 192)], close: true)
        let picture = try paint(tile(PB.layer("water_areas", extent: 256, features: [PB.feature(type: 3, geometry: square256)])))
        assertColor(picture, 256, 256, water, "middle of the lake")
        assertColor(picture, 60, 60, paper, "outside the lake")
    }

    func testFeaturesOutsideTheYearArentDrawn() throws {
        let dated = tile(PB.layer("water_areas", keys: ["start_decdate"], values: [PB.double(1950)],
                                  features: [PB.feature(type: 3, geometry: square, tags: [0, 0])]))
        assertColor(try paint(dated, year: 1900), 256, 256, paper, "before it existed")
        assertColor(try paint(dated, year: 1960), 256, 256, water, "after it was built")
    }

    /// Past zoom 15 each tile shows a quarter of the source tile, and the right quarter
    func testCloserTilesShowTheirPartOfTheSourceTile() throws {
        let topLeft = PB.line([(0, 0), (2048, 0), (2048, 2048), (0, 2048)], close: true)
        let tile = tile(PB.layer("water_areas", features: [PB.feature(type: 3, geometry: topLeft)]))
        assertColor(try paint(tile, z: 16, x: 0, y: 0), 256, 256, water, "the top left quarter")
        assertColor(try paint(tile, z: 16, x: 1, y: 0), 256, 256, paper, "the top right quarter")
        assertColor(try paint(tile, z: 16, x: 0, y: 1), 256, 256, paper, "the bottom left quarter")
    }

    /// Railways are thin lines with separate cross ties, not one thick bar
    func testRailwayTiesHaveGapsBetweenThem() throws {
        let rail = PB.line([(0, 2048), (4096, 2048)])
        let tile = tile(PB.layer("transport_lines", keys: ["class"], values: [PB.string(1, "railway")],
                                 features: [PB.feature(type: 2, geometry: rail, tags: [0, 0])]))
        let picture = try paint(tile)
        // Just off the rail, where only the ties reach
        let row = (100..<400).map { picture.color($0, 254) }
        let bare = row.filter { zip($0, paper).allSatisfy { abs($0 - $1) <= 6 } }.count
        XCTAssertGreaterThan(bare, 100, "the gaps between ties should show paper")
        XCTAssertLessThan(bare, 290, "the ties should show")
    }

    func testStreetsHaveAPaleMiddleAndInkEdges() throws {
        let street = PB.line([(0, 2048), (4096, 2048)])
        let tile = tile(PB.layer("transport_lines", keys: ["class", "type"], values: [PB.string(1, "highway"), PB.string(1, "primary")],
                                 features: [PB.feature(type: 2, geometry: street, tags: [0, 0, 1, 1])]))
        let picture = try paint(tile)
        assertColor(picture, 256, 256, [250, 242, 222], "the middle of the street")
        assertColor(picture, 256, 200, paper, "away from the street")
    }
}
