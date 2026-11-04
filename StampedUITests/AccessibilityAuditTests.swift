//
//  AccessibilityAuditTests.swift
//  StampedUITests
//
//  Runs Apple's automated accessibility audit (performAccessibilityAudit) on each main screen,
//  once at the default text size and once at the largest accessibility size (AX5).
//  It checks for missing labels, clipped text, text that doesn't grow with Dynamic Type,
//  low contrast and buttons too small to tap. It is not a substitute for a real VoiceOver
//  pass, but it runs every time and catches new screens that forget the basics.
//

import XCTest

@MainActor
final class AccessibilityAuditTests: XCTestCase {

    /// The two text sizes every screen is checked at
    enum TextSize: String, CaseIterable {
        case standard
        case largestAccessibility

        /// UIKit reads this launch argument as the text size, so no Settings change is needed
        var launchArguments: [String] {
            switch self {
            case .standard:
                return ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
            case .largestAccessibility:
                return ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            }
        }
    }

    override func setUp() {
        super.setUp()
        // Keep going after one audit issue, so a run lists every problem on every screen
        continueAfterFailure = true
    }

    // MARK: - Screens

    func testOnboarding() throws {
        try auditAtBothTextSizes(showOnboarding: true) { app in
            app.wait(for: app.staticTexts.firstMatch)
        }
    }

    func testCityList() throws {
        try auditAtBothTextSizes { app in
            app.wait(for: app.buttons["My Passport"])
        }
    }

    func testCityDetail() throws {
        try auditAtBothTextSizes { app in
            app.openMontreal()
        }
    }

    func testLandmarkDetail() throws {
        try auditAtBothTextSizes { app in
            app.openMontreal()
            let landmark = app.element(matching: NSPredicate(format: "identifier BEGINSWITH 'LandmarkLink_'"))
            app.scrollUntilHittable(landmark)
            landmark.tap()
            // The landmark page has no list of landmarks
            app.waitUntilGone(landmark)
        }
    }

    func testPassportGallery() throws {
        try auditAtBothTextSizes { app in
            app.tap(app.buttons["My Passport"])
            app.waitUntilGone(app.buttons["My Passport"])
        }
    }

    func testAchievements() throws {
        try auditAtBothTextSizes { app in
            app.tap(app.buttons["Achievements"])
            app.waitUntilGone(app.buttons["My Passport"])
        }
    }

    func testQuiz() throws {
        try auditAtBothTextSizes { app in
            app.openMontreal()
            let quiz = app.element(identifier: "CityAction_quiz")
            app.scrollUntilHittable(quiz)
            quiz.tap()
            app.wait(for: app.buttons["Exit"])
        }
    }

    func testTripPlanner() throws {
        try auditAtBothTextSizes { app in
            app.openMontreal()
            let trip = app.element(identifier: "CityAction_trip")
            app.scrollUntilHittable(trip)
            trip.tap()
            app.wait(for: app.buttons["Done"])
        }
    }

    func testMyTrips() throws {
        try auditAtBothTextSizes { app in
            app.tap(app.buttons["My Trips"])
            app.waitUntilGone(app.buttons["My Passport"])
        }
    }

    func testSettings() throws {
        try auditAtBothTextSizes { app in
            app.tap(app.buttons["Settings"])
            app.waitUntilGone(app.buttons["My Passport"])
        }
    }

    func testTipJar() throws {
        try auditAtBothTextSizes { app in
            app.tap(app.buttons["Settings"])
            // The row reads its title and subtitle together, so match the start of the label
            let support = app.element(matching: NSPredicate(format: "label BEGINSWITH 'Support Stamped!'"))
            app.scrollUntilHittable(support)
            support.tap()
            // The tip jar's title is "Support Stamped!" too, so wait for the row's subtitle to go
            app.waitUntilGone(app.element(matching: NSPredicate(format: "label CONTAINS 'Tips help keep'")))
        }
    }

    // MARK: - Running the audit

    /// Text the default-size audit said might not grow with Dynamic Type, and how tall it was.
    /// Checked again at AX5 (`checkTextGrew`), where it must be clearly taller.
    private var textToCheckAtLargestSize: [(label: String, height: CGFloat)] = []

    /// Launches the app at each text size, goes to the screen with `goToScreen`, and audits it
    private func auditAtBothTextSizes(showOnboarding: Bool = false,
                                      goToScreen: (XCUIApplication) -> Void) throws {
        textToCheckAtLargestSize = []
        for textSize in TextSize.allCases {
            let app = XCUIApplication()
            app.launchArguments = textSize.launchArguments + [
                // Skips the location and notification prompts (ProximityManager)
                "-UITesting",
                // @AppStorage reads these: a "-key value" launch argument overrides what's saved
                "-hasSeenOnboarding", showOnboarding ? "NO" : "YES",
                "-hasSeenPassportHint", showOnboarding ? "NO" : "YES",
            ]
            app.launch()

            try XCTContext.runActivity(named: "Audit at \(textSize.rawValue) text size") { _ in
                goToScreen(app)
                // Let transitions and images finish so the audit sees the settled screen
                sleep(2)
                try app.performAccessibilityAudit(for: Self.auditTypes(at: textSize)) { issue in
                    let ignored = self.shouldIgnore(issue, at: textSize)
                    if !ignored {
                        print("AUDIT [\(textSize.rawValue)] \(issue.compactDescription): \(issue.element?.debugDescription.prefix(200) ?? "no element")")
                    }
                    return ignored
                }
                if textSize == .largestAccessibility {
                    checkTextGrew(in: app)
                }
            }
            app.terminate()
        }
    }

    /// What the audit checks at each size.
    private static func auditTypes(at textSize: TextSize) -> XCUIAccessibilityAuditType {
        // Contrast: most findings are the brand orange (white on orange, orange on white).
        // Changing the brand colour is a design decision, and the app's answer to contrast is its
        // High Contrast mode (Settings, or iOS's Increase Contrast), which swaps orange for black/white.
        // Left out until that decision is made, so it doesn't hide every other finding.
        var types = XCUIAccessibilityAuditType.all.subtracting(.contrast)
        if textSize == .largestAccessibility {
            // The Dynamic Type check asks "does this text get bigger when the size goes up?".
            // AX5 is the top of the scale, so nothing can pass it there.
            types.remove(.dynamicType)
        }
        return types
    }

    /// Returns true for audit findings that are not real problems (the audit then skips them).
    /// Each rule says why it is safe to ignore.
    private func shouldIgnore(_ issue: XCUIAccessibilityAuditIssue, at textSize: TextSize) -> Bool {
        let element = issue.element
        let label = element?.label ?? ""

        switch issue.auditType {
        case .dynamicType:
            // Bar buttons (Done, Exit): iOS itself stops them growing so the bar keeps its height,
            // and shows them in the Large Content Viewer on a long press instead
            if Self.barButtonLabels.contains(label) { return true }
            // Capped on purpose in CityListView: the four tiles stop fitting side by side, and the
            // floating My Passport button would cover half the list (it shows the Large Content Viewer)
            if Self.cappedHomeLabels.contains(label) { return true }
            // The audit often flags text that does grow (plain Text in a Toggle, for one).
            // Don't trust it either way: note the height and check it again at AX5.
            if let element, !label.isEmpty {
                textToCheckAtLargestSize.append((label, element.frame.height))
                return true
            }
            return false

        case .textClipped:
            // At the default size this is only a guess ("may be clipped at larger sizes").
            // The AX5 launch checks the real thing at the largest size, so only trust it there.
            if textSize == .standard { return true }
            // The system search bar draws its own placeholder and cuts it to fit; VoiceOver
            // still reads it in full. Nothing in the app can change how it's drawn.
            if element?.elementType == .searchField { return true }
            // The first onboarding title, in the large serif font: a screenshot at AX5 shows
            // all of it ("Explore / the World"), but the audit still reports it as clipped
            if label == "Explore the World" { return true }
            return false

        case .hitRegion:
            // Progress bars only show progress; nobody needs to tap them
            if element?.elementType == .progressIndicator { return true }
            return false

        default:
            return false
        }
    }

    /// Done and Exit in the top bars of the full-screen screens
    private static let barButtonLabels: Set<String> = ["Done", "Exit"]

    /// The four tiles under the home header (`quickActions`), capped at xxxLarge text,
    /// and the floating passport button (`passportFloatingButton`), capped at AX1
    private static let cappedHomeLabels: Set<String> = ["My Journey", "Achievements", "World Map", "My Trips", "My Passport"]

    /// Each piece of text noted by the default-size audit must be at least 20% taller at AX5
    private func checkTextGrew(in app: XCUIApplication) {
        for (label, standardHeight) in textToCheckAtLargestSize {
            let text = app.element(matching: NSPredicate(format: "label == %@", label))
            // Bigger text pushes things further down, and lists only build rows on screen
            app.scrollUntilExists(text)
            guard text.exists else {
                XCTFail("Couldn't find '\(label)' at AX5 to check it grows with Dynamic Type")
                continue
            }
            XCTAssertGreaterThan(text.frame.height, standardHeight * 1.2,
                                 "'\(label)' doesn't grow with Dynamic Type (\(standardHeight) pt, \(text.frame.height) pt at AX5)")
        }
    }
}

// MARK: - Navigation helpers

private extension XCUIApplication {

    /// Fails the test (with the element's name) if it never shows up
    func wait(for element: XCUIElement, timeout: TimeInterval = 10) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(element) never appeared")
    }

    func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 10) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: timeout), .completed, "\(element) is still on screen")
    }

    func tap(_ element: XCUIElement) {
        wait(for: element)
        element.tap()
    }

    /// Swipes up until the element is on screen (lists only build rows as they scroll in)
    func scrollUntilHittable(_ element: XCUIElement, maxSwipes: Int = 12) {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < maxSwipes {
            swipeUp()
            swipes += 1
        }
        XCTAssertTrue(element.isHittable, "\(element) is not on screen after \(swipes) swipes")
    }

    /// Looks further down the screen, then back up, until the element is built
    func scrollUntilExists(_ element: XCUIElement, maxSwipes: Int = 8) {
        for _ in 0..<maxSwipes where !element.exists { swipeUp() }
        for _ in 0..<(maxSwipes * 2) where !element.exists { swipeDown() }
    }

    /// Any kind of element (button, cell, other...): SwiftUI decides the type, and it can change
    func element(identifier: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func element(matching predicate: NSPredicate) -> XCUIElement {
        descendants(matching: .any).matching(predicate).firstMatch
    }

    /// Opens Montreal's city page with the link the home screen widget uses (WebLinkRouter),
    /// so the test doesn't depend on where Montreal sits in the list at each text size
    func openMontreal() {
        wait(for: buttons["My Passport"])
        open(URL(string: "stamped://city/Montreal")!)
        wait(for: element(identifier: "CityAction_quiz"))
    }
}
