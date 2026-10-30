//
//  ArchitectIndexTests.swift
//  StampedTests
//
//  How the free-text `architect` field is split into the names that get an
//  Architect page, and the check that keeps a wrong person's Wikipedia bio off it.
//  Lives in StampedTests/ (a synchronized folder) so Xcode picks it up
//  without editing the project file.
//

import XCTest
@testable import Stamped_

@MainActor
final class ArchitectIndexTests: XCTestCase {

    // A firm named after two partners is one firm: "Darling and Pearson" has one-word
    // sides, and "Skidmore, Owings & Merrill" has a comma, so neither is split
    func testFirmNamesStayWhole() {
        XCTAssertEqual(ArchitectIndex.names(in: "Darling and Pearson"), ["Darling and Pearson"])
        XCTAssertEqual(ArchitectIndex.names(in: "Herzog & de Meuron"), ["Herzog & de Meuron"])
        XCTAssertEqual(ArchitectIndex.names(in: "Eliel & Eero Saarinen"), ["Eliel & Eero Saarinen"])
        XCTAssertEqual(ArchitectIndex.names(in: "Welton Becket & Associates"), ["Welton Becket & Associates"])
        XCTAssertEqual(ArchitectIndex.names(in: "Skidmore, Owings & Merrill"), ["Skidmore, Owings & Merrill"])
    }

    // Two full personal names joined by "&", "and" or "/" are two architects,
    // so the building shows up on both of their pages
    func testTwoPeopleAreSplit() {
        XCTAssertEqual(ArchitectIndex.names(in: "I.M. Pei & Henry N. Cobb"), ["I.M. Pei", "Henry N. Cobb"])
        XCTAssertEqual(ArchitectIndex.names(in: "Bernard Maybeck and Julia Morgan"), ["Bernard Maybeck", "Julia Morgan"])
        XCTAssertEqual(ArchitectIndex.names(in: "Alphonse Venne / Dom Bellot"), ["Alphonse Venne", "Dom Bellot"])
        // Notes in brackets on each side are dropped before splitting
        XCTAssertEqual(ArchitectIndex.names(in: "Cass Gilbert (Original) / David Chipperfield (Expansion)"),
                       ["Cass Gilbert", "David Chipperfield"])
    }

    // " / " between firms is only split when each firm has buildings of its own in the
    // app; otherwise the whole credit stays as it is
    func testSlashBetweenFirmsNeedsBothKnown() {
        let credit = "Reed and Stem / Warren and Wetmore"
        XCTAssertEqual(ArchitectIndex.names(in: credit), [credit])
        let known: Set<String> = [ArchitectIndex.key(for: "Reed and Stem"), ArchitectIndex.key(for: "Warren & Wetmore")]
        XCTAssertEqual(ArchitectIndex.names(in: credit, standaloneKeys: known), ["Reed and Stem", "Warren and Wetmore"])
    }

    // Different spellings of one name share a key, so they land on the same page
    func testSpellingsShareAKey() {
        XCTAssertEqual(ArchitectIndex.key(for: "Bruce and Morgan"), ArchitectIndex.key(for: "Bruce & Morgan"))
        XCTAssertEqual(ArchitectIndex.key(for: "I. M. Pei"), ArchitectIndex.key(for: "I.M. Pei"))
        XCTAssertEqual(ArchitectIndex.names(in: "Skidmore, Owings & Merrill (SOM)"), ["Skidmore, Owings & Merrill"])
        XCTAssertNotEqual(ArchitectIndex.key(for: "Philip Johnson"), ArchitectIndex.key(for: "John Burgee"))
    }

    // Vague credits like "Traditional / Unknown" are not split and get no page
    func testVagueCreditsAreNotLinked() {
        XCTAssertEqual(ArchitectIndex.names(in: "Traditional / Unknown"), ["Traditional / Unknown"])
        XCTAssertFalse(ArchitectIndex.isLinkable("Traditional / Unknown"))
        XCTAssertFalse(ArchitectIndex.isLinkable("Various, reconstructed by Jan Zachwatowicz"))
        XCTAssertTrue(ArchitectIndex.isLinkable("Herzog & de Meuron"))
    }

    // With the real registry: every building on an architect's page really names that
    // architect, and each building links back to a page that lists it
    func testRealRegistryLinksBothWays() throws {
        let building = try XCTUnwrap(
            CityLocation.City.allCases.flatMap(\.buildings).first { $0.architect == "Herzog & de Meuron" },
            "No Herzog & de Meuron building in the registry"
        )
        let architect = try XCTUnwrap(ArchitectIndex.architects(of: building).first)
        let landmarks = ArchitectIndex.landmarks(by: architect)
        XCTAssertGreaterThan(landmarks.count, 1, "Herzog & de Meuron should have several landmarks")
        XCTAssertTrue(landmarks.contains { $0.building.id == building.id })
        for landmark in landmarks {
            XCTAssertTrue(ArchitectIndex.architects(of: landmark.building).contains(architect),
                          "\(landmark.building.name) is listed but doesn't link back")
        }
    }

    // Only a Wikipedia article about an architect, firm or designer is used for the bio
    func testOnlyArchitectArticlesGiveABio() {
        XCTAssertTrue(ArchitectWikiService.describesArchitect("American architect (1917–2019)"))
        XCTAssertTrue(ArchitectWikiService.describesArchitect("Swiss architecture firm"))
        XCTAssertTrue(ArchitectWikiService.describesArchitect("Danish designer"))
        XCTAssertFalse(ArchitectWikiService.describesArchitect("American football player"))
        XCTAssertFalse(ArchitectWikiService.describesArchitect(nil))
    }
}
