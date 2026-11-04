//
//  SharePlayTests.swift
//  Tally-AVPTests
//
//  Checks the Explore Together rules that don't need a FaceTime call: what gets
//  sent, what gets applied, and that messages survive the trip between devices.
//

import Foundation
import GroupActivities
import Testing
@testable import Tally_AVP

@MainActor
struct SharePlayTests {

    // MARK: Messages

    /// SharePlay sends messages as JSON. Encoding then decoding must give back
    /// the same city and landmark, including "card closed" (nil).
    @Test(arguments: ["chicago-willis-tower", nil] as [String?])
    func messageSurvivesEncoding(landmarkID: String?) throws {
        let message = ExploreMessage(cityName: "Chicago", landmarkID: landmarkID)
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(ExploreMessage.self, from: data)
        #expect(decoded == message)
    }

    /// The activity's city also travels between devices.
    @Test func activitySurvivesEncoding() throws {
        let activity = ExploreCityActivity(cityName: "Rome")
        let data = try JSONEncoder().encode(activity)
        #expect(try JSONDecoder().decode(ExploreCityActivity.self, from: data).cityName == "Rome")
    }

    /// FaceTime shows this title, so it must name the city.
    @Test func activityTitleNamesTheCity() {
        let metadata = ExploreCityActivity(cityName: "Paris").metadata
        #expect(metadata.title?.contains("Paris") == true)
        #expect(metadata.type == .exploreTogether)
    }

    // MARK: Sending

    /// Not in SharePlay (no shared city): nothing is sent.
    @Test func nothingSentWhenNotSharing() {
        let message = SharePlayExplorer.messageToSend(landmarkID: "a", cityName: "Rome",
                                                      sharedCity: nil, current: nil)
        #expect(message == nil)
    }

    /// A tap in the group's city is sent with that city attached.
    @Test func tapInSharedCityIsSent() {
        let message = SharePlayExplorer.messageToSend(landmarkID: "a", cityName: "Rome",
                                                      sharedCity: "Rome", current: nil)
        #expect(message == ExploreMessage(cityName: "Rome", landmarkID: "a"))
    }

    /// Tapping the landmark that's already open for everyone doesn't send it again.
    @Test func sameLandmarkIsNotResent() {
        let current = ExploreMessage(cityName: "Rome", landmarkID: "a")
        let message = SharePlayExplorer.messageToSend(landmarkID: "a", cityName: "Rome",
                                                      sharedCity: "Rome", current: current)
        #expect(message == nil)
    }

    /// Closing the card is sent too, so friends' cards close.
    @Test func closingTheCardIsSent() {
        let current = ExploreMessage(cityName: "Rome", landmarkID: "a")
        let message = SharePlayExplorer.messageToSend(landmarkID: nil, cityName: "Rome",
                                                      sharedCity: "Rome", current: current)
        #expect(message == ExploreMessage(cityName: "Rome", landmarkID: nil))
    }

    /// A map left over from another city must not send into the group's city.
    @Test func tapInOtherCityIsNotSent() {
        let message = SharePlayExplorer.messageToSend(landmarkID: "a", cityName: "Paris",
                                                      sharedCity: "Rome", current: nil)
        #expect(message == nil)
    }

    // MARK: Receiving

    /// Only a friend's message about the group's current city is applied.
    @Test func onlySharedCityMessagesApply() {
        let rome = ExploreMessage(cityName: "Rome", landmarkID: "a")
        #expect(SharePlayExplorer.shouldApply(rome, sharedCity: "Rome"))
        #expect(!SharePlayExplorer.shouldApply(rome, sharedCity: "Paris"))
        #expect(!SharePlayExplorer.shouldApply(rome, sharedCity: nil))
    }

    /// Without a FaceTime call (as in the simulator) the app starts out not sharing.
    @Test func startsNotSharing() {
        let sharePlay = SharePlayExplorer.shared
        #expect(!sharePlay.isSharing)
        #expect(sharePlay.sharedCity == nil)
        #expect(sharePlay.participantCount == 0)
    }
}
