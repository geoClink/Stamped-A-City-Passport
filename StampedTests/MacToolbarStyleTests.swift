//
//  MacToolbarStyleTests.swift
//  StampedTests
//
//  Guards the Mac toolbar fix. The Mac window sets `.buttonStyle(.borderless)` for the app's
//  own iOS-style buttons; when that reached the toolbar, every glass pill squeezed into a
//  tall, narrow oval (the sidebar toggle was the worst). Two things keep it fixed:
//    1. toolbar buttons use AppToolbarItem / AppToolbarItemGroup, which put the normal
//       toolbar style back on the Mac;
//    2. every NavigationSplitView gets .macToolbarButtonStyle(), for the sidebar toggle the
//       system adds itself.
//  These tests read the app's Swift files, so they run with the other unit tests in about
//  a second, without opening the Mac app or taking over the mouse and keyboard.
//

import XCTest

final class MacToolbarStyleTests: XCTestCase {

    /// The app's source folder, found from this file's own path (StampedTests/ sits beside it)
    private var appSourceFolder: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // StampedTests/
            .deletingLastPathComponent()      // repository root
            .appendingPathComponent("Stamped! A City Passport")
    }

    /// Every Swift file in the app, as (path relative to the app folder, contents)
    private func appSwiftFiles() throws -> [(name: String, text: String)] {
        let folder = appSourceFolder
        guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) else {
            XCTFail("Can't read the app's source folder at \(folder.path)")
            return []
        }
        var files: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let name = String(url.path.dropFirst(folder.path.count + 1))
            files.append((name, try String(contentsOf: url, encoding: .utf8)))
        }
        XCTAssertFalse(files.isEmpty, "No Swift files found in \(folder.path)")
        return files
    }

    // No plain ToolbarItem / ToolbarItemGroup in the app: they'd bring the narrow ovals back on the Mac.
    // MacCompat.swift is the one place allowed to use them, inside AppToolbarItem itself.
    func testToolbarButtonsUseTheMacAwareItems() throws {
        let plain = try NSRegularExpression(pattern: #"(?<![A-Za-z])ToolbarItem(Group)?\("#)
        var offenders: [String] = []
        for file in try appSwiftFiles() where !file.name.hasSuffix("MacCompat.swift") {
            let range = NSRange(file.text.startIndex..., in: file.text)
            let count = plain.numberOfMatches(in: file.text, range: range)
            if count > 0 { offenders.append("\(file.name) (\(count))") }
        }
        XCTAssertTrue(offenders.isEmpty,
                      "Use AppToolbarItem / AppToolbarItemGroup instead of ToolbarItem in: \(offenders.sorted())")
    }

    // Every file with a NavigationSplitView also gives it .macToolbarButtonStyle(), so the sidebar
    // toggle the system adds stays a round glass button on the Mac
    func testSplitViewsKeepTheRoundSidebarButton() throws {
        var offenders: [String] = []
        for file in try appSwiftFiles() {
            let splitViews = file.text.components(separatedBy: "NavigationSplitView {").count - 1
                + file.text.components(separatedBy: "NavigationSplitView(").count - 1
            let styled = file.text.components(separatedBy: ".macToolbarButtonStyle()").count - 1
            if splitViews > styled { offenders.append("\(file.name): \(splitViews) split view(s), \(styled) styled") }
        }
        XCTAssertTrue(offenders.isEmpty,
                      "Add .macToolbarButtonStyle() to each NavigationSplitView in: \(offenders.sorted())")
    }
}
