//
//  CustomPlace.swift
//  Stamped! A City Passport
//
//  A place the user saved to "Want to Visit" from Apple Maps search —
//  anything that isn't one of the app's built-in landmarks.
//

import Foundation
import CoreLocation

struct CustomPlace: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let address: String?
    let latitude: Double
    let longitude: Double
    /// The Stamped city it was saved under (e.g. "New York"), so it shows on that city's map.
    let cityName: String
    // Extra details from Apple Maps, when it has them
    var websiteURL: URL? = nil
    var phoneNumber: String? = nil
    var category: String? = nil

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// True if this looks like the same spot (same name, within about 50 m).
    func isSamePlace(name otherName: String, latitude otherLat: Double, longitude otherLon: Double) -> Bool {
        name == otherName && abs(latitude - otherLat) < 0.0005 && abs(longitude - otherLon) < 0.0005
    }
}
