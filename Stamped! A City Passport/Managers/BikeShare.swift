//
//  BikeShare.swift
//  Stamped! A City Passport
//
//  Live bike-share docks for the city map's Bikes chip, from each system's public GBFS feed.
//  The device fetches the feeds itself (no server of ours in between), and pins carry
//  generic labels, never an operator's name or logo, as the feed licenses ask.
//
//  Pilot cities: Chicago, Washington D.C., Boston and New York (Lyft-run systems), and
//  Berlin, Munich and Vienna (nextbike, CC0). Detroit's MoGo stopped renting in Oct 2026;
//  add it back here if its stations start renting again.
//

import Foundation
import CoreLocation
import Observation

enum BikeShare {
    /// Each pilot city's GBFS base URL (the folder holding station_information.json).
    private static let feeds: [String: String] = [
        "Chicago":          "https://gbfs.lyft.com/gbfs/2.3/chi/en/",
        "Washington D.C.":  "https://gbfs.lyft.com/gbfs/2.3/dca-cabi/en/",
        "Boston":           "https://gbfs.lyft.com/gbfs/2.3/bos/en/",
        "New York":         "https://gbfs.lyft.com/gbfs/2.3/bkn/en/",
        "Berlin":           "https://gbfs.nextbike.net/maps/gbfs/v2/nextbike_bn/en/",
        "Munich":           "https://gbfs.nextbike.net/maps/gbfs/v2/nextbike_ml/en/",
        "Vienna":           "https://gbfs.nextbike.net/maps/gbfs/v2/nextbike_wr/en/",
    ]

    static func feed(for cityName: String) -> URL? {
        feeds[cityName].flatMap(URL.init(string:))
    }

    static func isAvailable(in cityName: String) -> Bool { feeds[cityName] != nil }
}

/// One dock with its live counts.
struct BikeStation: Identifiable, Equatable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    var bikes: Int
    var docks: Int
    var isRenting: Bool

    static func == (a: Self, b: Self) -> Bool {
        a.id == b.id && a.bikes == b.bikes && a.docks == b.docks && a.isRenting == b.isRenting
    }
}

/// Loads a city's docks and keeps their counts fresh while the Bikes chip is on.
@MainActor @Observable
final class BikeShareStore {
    private(set) var stations: [BikeStation] = []
    /// Every station's name and place, loaded once per city; `stations` is rebuilt from it.
    private var allStations: [BikeStation] = []
    private(set) var failed = false
    private var loadedCity: String?
    private var lastStatus: Date = .distantPast

    /// Station names and places (once per city), then the live counts.
    func refresh(cityName: String) async {
        guard let base = BikeShare.feed(for: cityName) else { stations = []; return }
        if loadedCity != cityName {
            stations = []
            allStations = []
            guard let info = await Self.fetchInfo(base) else { failed = true; return }
            allStations = info
            loadedCity = cityName
            lastStatus = .distantPast
        }
        // GBFS feeds update about once a minute; don't ask more often than that
        guard Date().timeIntervalSince(lastStatus) > 55 else { return }
        guard let status = await Self.fetchStatus(base) else {
            failed = true
            // Never show old counts as live: after 3 minutes without an update, hide the docks
            if Date().timeIntervalSince(lastStatus) > 180 { stations = [] }
            return
        }
        failed = false
        lastStatus = Date()
        // Only stations with live status: one missing from it is not installed (or not reporting)
        stations = allStations.compactMap { station in
            guard let live = status[station.id] else { return nil }
            var s = station
            s.bikes = live.bikes; s.docks = live.docks; s.isRenting = live.renting
            return s
        }
    }

    /// The docks nearest a point, so the map never draws thousands of pins at once.
    func nearest(to center: CLLocationCoordinate2D, limit: Int = 40, withinMeters radius: Double = 2_000) -> [BikeStation] {
        let here = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return stations
            .map { ($0, here.distance(from: CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude))) }
            .filter { $0.1 <= radius }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    // MARK: - Feeds

    private struct InfoFeed: Decodable {
        struct Data: Decodable { let stations: [Station] }
        struct Station: Decodable { let station_id: String; let name: String?; let lat: Double; let lon: Double }
        let data: Data
    }

    private struct StatusFeed: Decodable {
        /// When the operator last refreshed the feed (seconds since 1970).
        let last_updated: Double?
        struct Data: Decodable { let stations: [Station] }
        struct Station: Decodable {
            let station_id: String
            let num_bikes_available: Int?
            let num_docks_available: Int?
            let is_renting: Bool?
            let is_installed: Bool?
            // Some feeds send 0/1 instead of true/false
            enum CodingKeys: String, CodingKey { case station_id, num_bikes_available, num_docks_available, is_renting, is_installed }
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                station_id = try c.decode(String.self, forKey: .station_id)
                num_bikes_available = try c.decodeIfPresent(Int.self, forKey: .num_bikes_available)
                num_docks_available = try c.decodeIfPresent(Int.self, forKey: .num_docks_available)
                is_renting = Self.flag(c, .is_renting)
                is_installed = Self.flag(c, .is_installed)
            }
            private static func flag(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Bool? {
                if let value = try? c.decodeIfPresent(Bool.self, forKey: key) { return value }
                return (try? c.decodeIfPresent(Int.self, forKey: key)).map { $0 != 0 }
            }
        }
        let data: Data
    }

    private static func get<T: Decodable>(_ url: URL, as type: T.Type) async -> T? {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func fetchInfo(_ base: URL) async -> [BikeStation]? {
        guard let feed = await get(base.appendingPathComponent("station_information.json"), as: InfoFeed.self) else { return nil }
        return feed.data.stations.map {
            BikeStation(id: $0.station_id, name: $0.name ?? "",
                        coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon),
                        bikes: 0, docks: 0, isRenting: false)
        }
    }

    /// Live counts by station. Stations the operator marks as not installed (removed, or not
    /// built yet) are left out, so `refresh` drops them from the map.
    private static func fetchStatus(_ base: URL) async -> [String: (bikes: Int, docks: Int, renting: Bool)]? {
        guard let feed = await get(base.appendingPathComponent("station_status.json"), as: StatusFeed.self) else { return nil }
        // A feed the operator stopped updating would show frozen counts: treat it as down
        if let updated = feed.last_updated, Date().timeIntervalSince1970 - updated > 15 * 60 { return nil }
        var result: [String: (bikes: Int, docks: Int, renting: Bool)] = [:]
        for s in feed.data.stations where s.is_installed != false {
            result[s.station_id] = (s.num_bikes_available ?? 0, s.num_docks_available ?? 0, s.is_renting ?? true)
        }
        return result
    }
}
