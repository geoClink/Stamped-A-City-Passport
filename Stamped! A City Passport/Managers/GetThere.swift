//
//  GetThere.swift
//  Stamped! A City Passport
//
//  Get There: hands a landmark to Apple Maps with public transit directions from
//  wherever the user is. Maps falls back to driving or walking where it has no transit.
//

import MapKit

enum GetThere {
    /// True when the landmark has coordinates to route to.
    static func canRoute(to building: Building) -> Bool {
        building.latitude != nil && building.longitude != nil
    }

    /// Opens Apple Maps with transit directions to the landmark.
    @MainActor
    static func open(_ building: Building) {
        guard let lat = building.latitude, let lon = building.longitude else { return }
        // The placemark form, like the rest of the app: some targets still support releases before 26
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
        item.name = building.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit])
    }
}
