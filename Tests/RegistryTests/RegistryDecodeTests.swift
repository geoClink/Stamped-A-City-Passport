import XCTest
@testable import GlobalDiscoveryApp

final class RegistryDecodeTests: XCTestCase {
    func testDecodeBundleRegistry() throws {
        // Attempt to load the bundled JSON resource included in the app target
        guard let url = Bundle.main.url(forResource: "BuildingRegistry", withExtension: "json") else {
            XCTFail("BuildingRegistry.json not found in bundle")
            return
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let dict = try decoder.decode([String: [Building]].self, from: data)
        XCTAssertFalse(dict.isEmpty, "Registry JSON should not be empty")
        XCTAssertTrue(dict.keys.contains("Bath") || dict.count > 10, "There should be known cities present")
    }
}
