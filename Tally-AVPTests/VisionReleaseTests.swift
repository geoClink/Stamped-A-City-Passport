//
//  VisionReleaseTests.swift
//  Tally-AVPTests
//
//  Vision Pro checks that would embarrass a release: every city and campus loads,
//  the files the Vision app reads by name are in its bundle, and the app's name,
//  version and privacy manifest are what App Review sees. They only read.
//

import Foundation
import Testing
@testable import Tally_AVP

@MainActor
struct VisionReleaseTests {

    /// All 166 cities and 122 campuses load (a single bad entry would empty the whole list)
    @Test func everyCityAndCampusLoads() {
        #expect(VisionStore.shared.cityNames.count == 166 + 122)
    }

    /// Every city has at least 4 landmarks, enough for a quiz's 4 answers
    @Test func everyCityHasEnoughLandmarks() {
        let thin = VisionStore.shared.cityNames.filter { VisionStore.shared.buildings(for: $0).count < 4 }
        #expect(thin.isEmpty, "Too few landmarks: \(thin)")
    }

    /// Files the Vision app opens by name are in its bundle (a missing one fails silently, with no sound or no globe)
    @Test(arguments: [
        ("PrivacyInfo", "xcprivacy"),
        ("BuildingRegistry", "json"),
        ("LandmarkPanoramas", "json"),
        ("AudioCredits", "json"),
        ("baseball_crowd", "m4a"),
        ("football_crowd", "m4a"),
        ("GlobeEarth", "png"),
    ])
    func bundleHasFile(name: String, ext: String) {
        #expect(Bundle.main.url(forResource: name, withExtension: ext) != nil, "\(name).\(ext) is missing")
    }

    /// The app shows as "Stamped!" on the Home View and in App Review, not as "Tally-AVP"
    @Test func appIsNamedStamped() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == "Stamped!")
    }

    /// The Detroit download extension has the same version and build as the app; an upload is refused otherwise
    @Test func downloaderVersionMatchesApp() throws {
        let url = Bundle.main.bundleURL.appendingPathComponent("Extensions/DetroitDownloader.appex")
        let downloader = try #require(Bundle(url: url), "DetroitDownloader.appex isn't in the app")
        for key in ["CFBundleShortVersionString", "CFBundleVersion"] {
            let appValue = Bundle.main.object(forInfoDictionaryKey: key) as? String
            #expect(appValue != nil)
            #expect(downloader.object(forInfoDictionaryKey: key) as? String == appValue, "\(key) differs")
        }
    }
}
