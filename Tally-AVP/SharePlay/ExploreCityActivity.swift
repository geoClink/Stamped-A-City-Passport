//
//  ExploreCityActivity.swift
//  Tally-AVP
//
//  The SharePlay activity "Explore <city> together". Friends on a FaceTime call
//  open the same city's 3D map; the landmark one of them taps opens for everyone.
//
//  `nonisolated` because SharePlay sends these between devices off the main
//  thread, and this target makes types main-actor by default.
//

import CoreTransferable
import Foundation
import GroupActivities

nonisolated struct ExploreCityActivity: GroupActivity, Transferable {

    /// Which city everyone in the call is looking at.
    var cityName: String

    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = String(localized: "Explore \(cityName) together",
                                comment: "SharePlay activity title shown in FaceTime (Vision Pro)")
        metadata.subtitle = String(localized: "See its landmarks in 3D on Stamped!",
                                   comment: "SharePlay activity subtitle shown in FaceTime (Vision Pro)")
        metadata.type = .exploreTogether
        return metadata
    }

    /// Lets a ShareLink offer SharePlay before a FaceTime call has started.
    static var transferRepresentation: some TransferRepresentation {
        GroupActivityTransferRepresentation { activity in
            activity
        }
    }
}

/// The one message participants send each other: the landmark whose card is open.
/// It carries the city too, so a message sent just before someone switched city
/// can't open a landmark from the wrong city.
nonisolated struct ExploreMessage: Codable, Sendable, Equatable {
    var cityName: String
    /// The open landmark's Building.id, or nil when its card was closed.
    var landmarkID: String?
}
