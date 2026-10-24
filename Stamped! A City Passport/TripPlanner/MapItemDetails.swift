//
//  MapItemDetails.swift
//  Stamped! A City Passport
//
//  Small helpers for reading an Apple Maps result (MKMapItem), shared by
//  the anywhere-trip screens.
//

import MapKit

extension MKMapItem {
    // The app supports iOS 18.6, but these MKMapItem properties changed in iOS 26.
    // `#available` picks the right one at runtime, like an `if` on the OS version.

    /// Where the result is on the map.
    var displayCoordinate: CLLocationCoordinate2D {
        if #available(iOS 26.0, *) {
            return location.coordinate
        } else {
            return placemark.coordinate
        }
    }

    /// A short address line, e.g. "Kraków, Poland" for a city.
    var displayAddress: String? {
        if #available(iOS 26.0, *) {
            return address?.shortAddress ?? address?.fullAddress
        } else {
            return placemark.title
        }
    }
}
