//
//  SharePlayButton.swift
//  Tally-AVP
//
//  The city map's SharePlay control. It changes with the situation:
//  • on a FaceTime call  → "SharePlay" starts Explore Together right away
//  • no call yet         → "SharePlay" opens the share sheet to call friends
//  • already sharing     → "Leave SharePlay"
//

import GroupActivities
import SwiftUI

struct SharePlayButton: View {

    let cityName: String

    private let sharePlay = SharePlayExplorer.shared
    /// Tells us whether a FaceTime call is active
    @StateObject private var groupState = GroupStateObserver()

    var body: some View {
        if sharePlay.isSharing {
            Button {
                sharePlay.leave()
            } label: {
                Label("Leave SharePlay", systemImage: "shareplay.slash")
            }
            .help("Stop exploring together. Your friends can carry on.")
        } else if groupState.isEligibleForGroupSession {
            Button {
                Task { await sharePlay.start(cityName) }
            } label: {
                Label("SharePlay", systemImage: "shareplay")
            }
            .help("Explore this city with the people on your FaceTime call")
        } else {
            ShareLink(item: ExploreCityActivity(cityName: cityName),
                      preview: SharePreview(Text("Explore \(cityName) together"))) {
                Label("SharePlay", systemImage: "shareplay")
            }
            .help("Call friends on FaceTime and explore this city together")
        }
    }
}
