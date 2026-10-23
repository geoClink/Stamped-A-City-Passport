//
//  CustomPlace.swift
//  Stamped! A City Passport
//
//  A place the user saved to "Want to Visit" from Apple Maps search —
//  anything that isn't one of the app's built-in landmarks.
//

import Foundation
import CoreLocation
import MapKit

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

extension CustomPlace {
    /// SF Symbol for an Apple Maps point-of-interest category.
    static func icon(forCategory category: String?) -> String {
        switch category.map(MKPointOfInterestCategory.init(rawValue:)) {
        case .restaurant?, .foodMarket?: "fork.knife"
        case .cafe?, .bakery?: "cup.and.saucer.fill"
        case .nightlife?, .brewery?, .winery?: "wineglass.fill"
        case .museum?: "building.columns.fill"
        case .park?, .nationalPark?: "tree.fill"
        case .theater?, .movieTheater?: "theatermasks.fill"
        case .stadium?: "sportscourt.fill"
        case .store?: "bag.fill"
        case .hotel?: "bed.double.fill"
        case .beach?: "beach.umbrella.fill"
        default: "heart.fill"
        }
    }
}
