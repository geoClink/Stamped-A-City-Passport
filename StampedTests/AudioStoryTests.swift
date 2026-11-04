//
//  AudioStoryTests.swift
//  StampedTests
//
//  The text the "Listen" button reads aloud (AudioStoryPlayer.story): the name, the known
//  facts, then the description, never "Unknown" or a year of 0.
//

import XCTest
@testable import Stamped_

@MainActor
final class AudioStoryTests: XCTestCase {

    private func landmark(architect: String = "Bruce Graham", year: Int = 1974, style: String = "International") -> Building {
        let real = CityLocation.City.chicago.buildings[0]
        // Re-encode a real landmark with chosen facts, so the test doesn't depend on Building's initializer
        var json = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(real)) as! [String: Any]
        json["name"] = "Willis Tower"
        json["architect"] = architect
        json["yearBuilt"] = year
        json["buildingStyle"] = style
        json["description"] = "Once the tallest building in the world."
        return try! JSONDecoder().decode(Building.self, from: JSONSerialization.data(withJSONObject: json))
    }

    // Name first, then the facts in one sentence, then the description
    func testStoryReadsFactsThenDescription() {
        XCTAssertEqual(AudioStoryPlayer.story(for: landmark()),
                       "Willis Tower. Finished in 1974, designed by Bruce Graham, in the International style. Once the tallest building in the world.")
    }

    // Unknown facts are left out instead of read as "Unknown" or "0"
    func testUnknownFactsAreLeftOut() {
        let story = AudioStoryPlayer.story(for: landmark(architect: "Unknown", year: 0, style: "Unknown"))
        XCTAssertEqual(story, "Willis Tower. Once the tallest building in the world.")
    }
}
