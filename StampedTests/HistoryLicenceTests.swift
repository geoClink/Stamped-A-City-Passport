//
//  HistoryLicenceTests.swift
//  StampedTests
//
//  The licence filters: a mistake here could show a photo the app can't legally use.
//

import XCTest
@testable import Stamped_

final class HistoryLicenceTests: XCTestCase {

    private func image(credit: String) -> HistoricImage {
        let url = URL(string: "https://example.org/a.jpg")!
        return HistoricImage(thumbnailURL: url, largeURL: url, caption: nil, isDrawing: false, credit: credit, itemURL: url)
    }

    // MARK: Commons licence names

    func testFreeLicencesAreAccepted() {
        for licence in ["Public domain", "PD-US-expired", "PD US", "PD", "CC0", "CC0 1.0", "CC BY 2.0", "CC BY 4.0",
                        "CC BY-SA 3.0", "CC BY-SA 4.0", "CC-BY-SA-3.0", "cc-by-4.0"] {
            XCTAssertTrue(HeritageService.isFreeForCommercialUse(licence), licence)
        }
    }

    func testNonCommercialLicencesAreRefused() {
        for licence in ["CC BY-NC 4.0", "CC BY-NC-SA 3.0", "CC BY-NC-ND 4.0", "CC-BY-NC-2.0", "cc by-nc",
                        "Public domain (non-commercial use only)", "Public domain, noncommercial"] {
            XCTAssertFalse(HeritageService.isFreeForCommercialUse(licence), licence)
        }
    }

    /// No-derivatives licences aren't among the four the app allows: the app crops and fades photos
    func testNoDerivativesLicencesAreRefused() {
        for licence in ["CC BY-ND 4.0", "CC BY-ND 2.0", "CC-BY-ND-3.0", "cc by-nd"] {
            XCTAssertFalse(HeritageService.isFreeForCommercialUse(licence), licence)
        }
    }

    func testOtherLicencesAreRefused() {
        for licence in ["", "All rights reserved", "Copyrighted", "GFDL", "Fair use", "FAL", "No restrictions",
                        "Not public domain", "Attribution"] {
            XCTAssertFalse(HeritageService.isFreeForCommercialUse(licence), licence)
        }
    }

    // MARK: Europeana rights URLs

    func testOpenRightsURLsGiveTheirLicence() {
        let expected = [
            "http://creativecommons.org/publicdomain/mark/1.0/": "Public domain",
            "https://creativecommons.org/publicdomain/mark/1.0/": "Public domain",
            "http://creativecommons.org/publicdomain/zero/1.0/": "CC0",
            "http://creativecommons.org/licenses/by/4.0/": "CC BY",
            "https://creativecommons.org/licenses/by/3.0/de/": "CC BY",
            "http://creativecommons.org/licenses/by-sa/4.0/": "CC BY-SA",
            "HTTP://CREATIVECOMMONS.ORG/LICENSES/BY-SA/3.0/": "CC BY-SA",
        ]
        for (url, licence) in expected {
            XCTAssertEqual(ArchiveSearch.licence(fromRightsURL: url), licence, url)
        }
    }

    func testClosedRightsURLsGiveNoLicence() {
        for url in ["http://creativecommons.org/licenses/by-nc/4.0/",
                    "http://creativecommons.org/licenses/by-nc-sa/4.0/",
                    "http://creativecommons.org/licenses/by-nc-nd/4.0/",
                    "http://creativecommons.org/licenses/by-nd/4.0/",
                    "http://rightsstatements.org/vocab/InC/1.0/",
                    "http://rightsstatements.org/vocab/InC-EDU/1.0/",
                    "http://rightsstatements.org/vocab/NoC-NC/1.0/",
                    "http://rightsstatements.org/vocab/NoC-OKLR/1.0/",
                    "http://rightsstatements.org/vocab/CNE/1.0/",
                    "http://rightsstatements.org/vocab/NKC/1.0/",
                    "http://www.europeana.eu/rights/out-of-copyright-non-commercial/",
                    "http://www.europeana.eu/portal/rights/rr-f.html",
                    "https://example.org/licenses/by/4.0/",
                    "https://example.org/publicdomain/zero/1.0/",
                    "", "not a url"] {
            XCTAssertNil(ArchiveSearch.licence(fromRightsURL: url), url)
        }
    }

    // MARK: Which photos can go without a credit beside them

    func testPhotosThatNeedNoCredit() {
        for credit in ["Library of Congress, HABS MO-1140",
                       "Library of Congress, HABS/HAER",
                       "Jane Doe · Public domain · Wikimedia Commons",
                       "Rijksmuseum · Public domain · Europeana",
                       "Jane Doe · CC0 · Wikimedia Commons",
                       "Jane Doe · CC0 1.0 · Wikimedia Commons",
                       "National Air and Space Museum · Smithsonian Institution · CC0"] {
            XCTAssertTrue(OldPhotoSources.needsNoCredit(image(credit: credit)), credit)
        }
    }

    func testAttributionPhotosAlwaysNeedTheirCredit() {
        for credit in ["Jane Doe · CC BY 4.0 · Wikimedia Commons",
                       "Jane Doe · CC BY-SA 3.0 · Wikimedia Commons",
                       "Rijksmuseum · CC BY · Europeana",
                       "CC BY-SA · Europeana"] {
            XCTAssertFalse(OldPhotoSources.needsNoCredit(image(credit: credit)), credit)
        }
    }

    /// Names that only look like a free licence mustn't waive the author's credit
    func testNamesThatLookLikeLicencesDontWaiveTheCredit() {
        for credit in ["Public Domain Review · CC BY 4.0 · Wikimedia Commons",
                       "Digital Public Domain Library · CC BY-SA · Europeana",
                       "Library of Congress · CC BY-SA 2.0 · Wikimedia Commons",
                       "CC0 Studio · CC BY 4.0 · Wikimedia Commons",
                       "Public Domain Archive of Photos · GFDL · Elsewhere"] {
            XCTAssertFalse(OldPhotoSources.needsNoCredit(image(credit: credit)), credit)
        }
    }

    // MARK: Keys

    /// A fresh checkout has no plist: no key, and nothing crashes
    func testMissingOrBlankKeysAreNil() {
        XCTAssertNil(Secrets.value("K", in: [:]))
        XCTAssertNil(Secrets.value("K", in: ["K": ""]))
        XCTAssertNil(Secrets.value("K", in: ["K": "  \n"]))
        XCTAssertNil(Secrets.value("K", in: ["K": 42]))
        XCTAssertEqual(Secrets.value("K", in: ["K": "abc"]), "abc")
    }
}
