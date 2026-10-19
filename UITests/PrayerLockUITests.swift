import XCTest

/// UI smoke tests. They launch with `-PLUITesting`, which gives the app throwaway
/// storage so tests never touch real user data.
///
/// Note: Screen Time authorization and the FamilyActivityPicker are system UI that
/// can't be driven reliably in UI tests (and need a real device). These tests cover the
/// app's own flows; Screen Time flows are covered by the device test plan
/// (docs/08-testing-strategy.md).
@MainActor
final class PrayerLockUITests: XCTestCase {
    /// Waits until the element can actually receive a tap (step transitions animate), then taps.
    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let app = XCUIApplication()
        // Lists create rows lazily: scroll to find an element that isn't there yet.
        if !element.waitForExistence(timeout: 5) {
            for _ in 0..<10 where !element.exists { app.swipeUp(velocity: .fast) }
        }
        XCTAssertTrue(element.waitForExistence(timeout: 15), "\(element) never appeared", file: file, line: line)
        // Long screens (e.g. at the largest text sizes) put controls below the fold: scroll like a user.
        // Fast swipes, so a slow swipe on a loaded machine isn't read as a tap on a row.
        for _ in 0..<10 where element.exists && !element.isHittable { app.swipeUp(velocity: .fast) }
        let ready = expectation(for: NSPredicate(format: "isHittable == true AND isEnabled == true"), evaluatedWith: element)
        wait(for: [ready], timeout: 15)
        element.tap()
    }

    /// Taps Continue and waits for the next step's marker element.
    private func continueTo(_ app: XCUIApplication, _ marker: XCUIElement) {
        tap(app.buttons["onboarding.continue"])
        XCTAssertTrue(marker.waitForExistence(timeout: 15), "Next step did not appear: \(marker)")
    }

    /// Audit with element details in the failure message, so issues are actionable.
    /// `allowUnattributedDynamicType`: Settings only. Its Form reports one Dynamic Type finding
    /// with no element attached, so it can't be traced to any view; every *attributed* finding
    /// still fails, and testLargestTextSizeKeepsMainFlowUsable checks Settings text grows.
    private func audit(_ app: XCUIApplication, skipping skipped: XCUIAccessibilityAuditType = [],
                       allowUnattributedDynamicType: Bool = false) throws {
        // Screens fade their content in (plStaggered); auditing mid-fade measures
        // half-transparent text. Let the entrance finish first.
        sleep(2)
        let tabBar = app.tabBars.firstMatch
        let tabBarFrame = tabBar.exists ? tabBar.frame : .null
        try app.performAccessibilityAudit(for: XCUIAccessibilityAuditType.all.subtracting(skipped)) { issue in
            // Content scrolled under the translucent tab bar is measured against the bar's
            // blur, not its real background. Palette contrast is proven separately by
            // PaletteContrastTests (WCAG AA for every text/background pair), so only that
            // specific case is excluded; every other issue fails the test.
            if issue.auditType == .contrast, let element = issue.element, element.frame.intersects(tabBarFrame) {
                return true
            }
            if Self.isVerifiedFalsePositive(issue) { return true }
            if allowUnattributedDynamicType, issue.auditType == .dynamicType, issue.element == nil { return true }
            let element = issue.element.map { "\($0.elementType) label='\($0.label)' id='\($0.identifier)' frame=\($0.frame)" } ?? "no element"
            XCTFail("Accessibility audit: \(issue.compactDescription) — \(element). \(issue.detailedDescription)")
            return true // reported above as a failure
        }
    }

    /// Audit findings checked by hand and shown to be wrong, each with its evidence. Keep this
    /// list short and specific; anything not listed fails the audit.
    private static func isVerifiedFalsePositive(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        switch issue.auditType {
        case .textClipped:
            // Today's preview is an intentional three-line excerpt; VoiceOver reads the full
            // text and the whole passage is in the moment. (Eyebrow labels used to be flagged
            // here too: root-caused to `.tracking` and fixed by using an expanded font width.)
            return issue.element?.identifier == "today.preview"
        case .dynamicType:
            // "transliteration" is one long word: at the largest sizes it hyphenates rather than
            // growing on one line, which the audit reads as "partially unsupported". The large-text
            // test asserts this row grows (testLargestTextSizeKeepsMainFlowUsable).
            return issue.element?.label == "Show transliteration"
        default:
            return false
        }
    }

    private func launch(store: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-PLUITesting"]
        if let store { app.launchEnvironment["PL_UI_TEST_STORE"] = store }
        app.launch()
        return app
    }

    func testFirstLaunchShowsWelcome() {
        let app = launch()
        XCTAssertTrue(app.buttons["onboarding.getStarted"].waitForExistence(timeout: 5))
    }

    func testFaithNeutralOnboardingReachesToday() {
        let app = launch()
        tap(app.buttons["onboarding.getStarted"])

        XCTAssertTrue(app.buttons["faith.none"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["onboarding.continue"].isEnabled, "Faith must be chosen explicitly")
        completeOnboardingAfterWelcome(app)
        XCTAssertTrue(app.buttons["today.beginMoment"].waitForExistence(timeout: 15))
    }

    func testManualMomentCanBeCompleted() {
        let app = launch()
        completeFaithNeutralOnboarding(app)
        app.buttons["today.beginMoment"].tap()
        app.buttons["moment.begin"].tap()
        if app.buttons["Skip"].waitForExistence(timeout: 2) { app.buttons["Skip"].tap() }
        let finish = app.buttons["moment.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: finish)
        waitForExpectations(timeout: 10)
        finish.tap()
        app.buttons["Skip"].tap()
        XCTAssertTrue(app.buttons["moment.done"].waitForExistence(timeout: 5))
    }

    /// Guideline 5.1.1(i): the privacy policy must be reachable inside the app — from
    /// onboarding and from Settings — and it is bundled, so it works offline.
    func testPrivacyPolicyIsReadableInApp() {
        let app = launch()
        tap(app.buttons["onboarding.getStarted"])
        tap(app.buttons["faith.none"])
        continueTo(app, app.textFields.firstMatch)           // → personalize
        continueTo(app, app.buttons["onboarding.privacyPolicy"])  // → privacy
        tap(app.buttons["onboarding.privacyPolicy"])
        XCTAssertTrue(app.staticTexts["Beloved Privacy Policy"].waitForExistence(timeout: 15))
        tap(app.buttons["Done"])
        continueTo(app, app.staticTexts["Choose where to pause"])  // → protection
        continueTo(app, app.buttons["onboarding.notificationsLater"]) // → notifications
        tap(app.buttons["onboarding.notificationsLater"])
        tap(app.buttons["onboarding.finish"])

        tap(app.tabBars.buttons["You"])
        tap(app.buttons["settings.privacyPolicy"])
        XCTAssertTrue(app.staticTexts["Beloved Privacy Policy"].waitForExistence(timeout: 15))
    }

    // MARK: - Persistence across launches (named throwaway store)

    func testInterruptedOnboardingResumesAfterRelaunch() {
        let store = UUID().uuidString
        var app = launch(store: store)
        tap(app.buttons["onboarding.getStarted"])
        tap(app.buttons["faith.none"])
        continueTo(app, app.textFields.firstMatch)          // → personalize
        continueTo(app, app.buttons["onboarding.privacyPolicy"]) // → privacy
        app.terminate()

        app = launch(store: store)
        XCTAssertTrue(app.buttons["onboarding.privacyPolicy"].waitForExistence(timeout: 5),
                      "Setup resumes on the step where it was interrupted")
        XCTAssertFalse(app.buttons["onboarding.getStarted"].exists)
    }

    func testReturningUserSkipsOnboarding() {
        let store = UUID().uuidString
        var app = launch(store: store)
        completeFaithNeutralOnboarding(app)
        XCTAssertTrue(app.buttons["today.beginMoment"].waitForExistence(timeout: 5))
        app.terminate()

        app = launch(store: store)
        XCTAssertTrue(app.buttons["today.beginMoment"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding.getStarted"].exists)
    }

    func testBackKeepsTheFaithChoice() {
        let app = launch()
        tap(app.buttons["onboarding.getStarted"])
        tap(app.buttons["faith.none"])
        continueTo(app, app.textFields.firstMatch) // → personalize
        tap(app.buttons["Back"])
        XCTAssertTrue(app.buttons["faith.none"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["faith.none"].isSelected, "Going back must not lose the answer")
        XCTAssertTrue(app.buttons["onboarding.continue"].isEnabled)
    }

    // MARK: - Intentions

    /// Personal intentions end to end: added on Today, shown in Today's ledger, offered first
    /// at the end of a moment, and echoed on completion.
    func testIntentionFlowsFromTodayIntoTheMoment() {
        let app = launch()
        completeFaithNeutralOnboarding(app)
        tap(app.buttons["today.intention"])
        tap(app.buttons["Rest my mind"])
        tap(app.buttons["intentions.save"])
        let ledger = app.buttons["today.intention"]
        XCTAssertTrue(ledger.waitForExistence(timeout: 15))
        XCTAssertTrue(ledger.label.contains("Rest my mind"), "Today shows the intention: \(ledger.label)")

        tap(app.buttons["today.beginMoment"])
        tap(app.buttons["moment.begin"])
        if app.buttons["Skip"].waitForExistence(timeout: 5) { tap(app.buttons["Skip"]) }
        let finish = app.buttons["moment.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 15))
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: finish)
        wait(for: [enabled], timeout: 20)
        tap(finish)
        tap(app.buttons["Rest my mind"])
        XCTAssertTrue(app.staticTexts["Go gently: “Rest my mind”"].waitForExistence(timeout: 15),
                      "Completion echoes the chosen intention")
        tap(app.buttons["moment.done"])
    }

    /// Journey reopens a past moment's passage.
    func testJourneyReopensAPastMoment() {
        let app = launch()
        completeFaithNeutralOnboarding(app)
        tap(app.buttons["today.beginMoment"])
        tap(app.buttons["moment.begin"])
        if app.buttons["Skip"].waitForExistence(timeout: 5) { tap(app.buttons["Skip"]) }
        let finish = app.buttons["moment.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 15))
        wait(for: [expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: finish)], timeout: 20)
        tap(finish)
        tap(app.buttons["moment.intentionSkip"])
        tap(app.buttons["moment.done"])

        tap(app.buttons["today.journey"])
        let past = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "ago")).firstMatch
        tap(past)
        XCTAssertTrue(app.descendants(matching: .any)["journey.revisit"].waitForExistence(timeout: 15),
                      "Tapping a past moment reopens its passage")
    }

    /// Intentions edited in Settings: Return finishes editing (no line breaks), the change is
    /// saved when leaving, and Today shows it.
    func testIntentionEditedInSettingsReachesToday() {
        let app = launch()
        completeFaithNeutralOnboarding(app)
        tap(app.tabBars.buttons["You"])
        tap(app.buttons["settings.intentions"])
        tap(app.buttons["intentions.add"])
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.typeText("Call my mother\n")
        XCTAssertEqual(field.value as? String, "Call my mother", "Return finishes the intention instead of adding a line")
        app.navigationBars.buttons.firstMatch.tap() // back to Settings: saves
        tap(app.tabBars.buttons["Today"])
        let ledger = app.buttons["today.intention"]
        XCTAssertTrue(ledger.waitForExistence(timeout: 15))
        XCTAssertTrue(ledger.label.contains("Call my mother"), "Today shows the saved intention: \(ledger.label)")
    }

    // MARK: - Settings

    func testSettingsOffersNotificationsAndShowsBuild() {
        let app = launch()
        completeFaithNeutralOnboarding(app)
        tap(app.tabBars.buttons["You"])
        // A fresh simulator has never been asked, so the in-app request is offered.
        let allow = app.buttons["settings.allowNotifications"]
        for _ in 0..<6 where !allow.waitForExistence(timeout: 2) { app.swipeUp() }
        XCTAssertTrue(allow.exists)
        let version = app.descendants(matching: .any)["settings.version"]
        for _ in 0..<6 where !version.exists { app.swipeUp(velocity: .fast) }
        XCTAssertTrue(version.exists, "Settings shows the version row")
        let text = [version.label, version.value as? String ?? ""].joined(separator: " ")
        XCTAssertNotNil(text.range(of: #"[0-9]+\.[0-9]+\.[0-9]+ \([0-9]+\)"#, options: .regularExpression),
                        "Version row shows marketing version and build: \(text)")
    }

    func testDeleteAllDataReturnsToSetup() {
        let store = UUID().uuidString
        var app = launch(store: store)
        completeFaithNeutralOnboarding(app)
        tap(app.tabBars.buttons["You"])
        XCTAssertTrue(app.navigationBars["You"].waitForExistence(timeout: 15))
        // Form rows load lazily: scroll until the row exists and can be tapped.
        let delete = app.buttons["settings.deleteAll"]
        // Gentle swipes: the list is long and fast swipes fling past the row.
        for _ in 0..<16 where !(delete.exists && delete.isHittable) { app.swipeUp(velocity: .slow) }
        for _ in 0..<16 where !(delete.exists && delete.isHittable) { app.swipeDown(velocity: .slow) }
        XCTAssertTrue(delete.exists && delete.isHittable, "Delete all data is reachable")
        delete.tap()
        tap(app.buttons["Delete everything"])
        XCTAssertTrue(app.buttons["onboarding.getStarted"].waitForExistence(timeout: 15))

        app.terminate()
        app = launch(store: store)
        XCTAssertTrue(app.buttons["onboarding.getStarted"].waitForExistence(timeout: 5), "Deletion persists across launches")
    }

    // MARK: - Accessibility (Xcode's automated audit; not a substitute for VoiceOver testing)

    func testAccessibilityAuditWelcome() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["onboarding.getStarted"].waitForExistence(timeout: 15))
        try audit(app)
    }

    func testAccessibilityAuditToday() throws {
        let app = launch()
        completeFaithNeutralOnboarding(app)
        XCTAssertTrue(app.buttons["today.beginMoment"].waitForExistence(timeout: 15))
        try audit(app)
    }

    func testAccessibilityAuditSettings() throws {
        let app = launch()
        completeFaithNeutralOnboarding(app)
        tap(app.tabBars.buttons["You"])
        XCTAssertTrue(app.navigationBars["You"].waitForExistence(timeout: 15))
        try audit(app, allowUnattributedDynamicType: true)
    }

    func testAccessibilityAuditDarkAppearance() throws {
        XCUIDevice.shared.appearance = .dark
        defer { XCUIDevice.shared.appearance = .light }
        let app = launch()
        XCTAssertTrue(app.buttons["onboarding.getStarted"].waitForExistence(timeout: 15))
        try audit(app)
        completeFaithNeutralOnboarding(app)
        XCTAssertTrue(app.buttons["today.beginMoment"].waitForExistence(timeout: 15))
        try audit(app)
        tap(app.tabBars.buttons["You"])
        XCTAssertTrue(app.navigationBars["You"].waitForExistence(timeout: 15))
        try audit(app, allowUnattributedDynamicType: true)
    }

    // MARK: - Largest accessibility text size

    /// Runs the main flow at the largest Dynamic Type size (AX5) and keeps screenshots of
    /// Today and Settings as attachments for visual review.
    func testLargestTextSizeKeepsMainFlowUsable() {
        let app = XCUIApplication()
        app.launchArguments = ["-PLUITesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        completeFaithNeutralOnboarding(app)

        let begin = app.buttons["today.beginMoment"]
        XCTAssertTrue(begin.waitForExistence(timeout: 15))
        attachScreenshot(app, named: "Today AX5")
        for _ in 0..<8 where !begin.isHittable { app.swipeUp(velocity: .fast) }
        XCTAssertTrue(begin.isHittable, "Begin a moment is reachable at the largest text size")

        tap(app.tabBars.buttons["You"])
        // At AX5 the list is long and rows load lazily, so wait for the screen, not a lower row.
        XCTAssertTrue(app.navigationBars["You"].waitForExistence(timeout: 15))
        attachScreenshot(app, named: "Settings AX5 top")
        // Evidence for the one audit exclusion on this screen: the row really grows.
        let transliteration = app.descendants(matching: .any)["settings.showTransliteration"]
        for _ in 0..<8 where !(transliteration.exists && transliteration.isHittable) { app.swipeUp(velocity: .fast) }
        XCTAssertTrue(transliteration.exists, "Show transliteration row reachable at AX5")
        XCTAssertGreaterThan(transliteration.frame.height, 80, "The row grows with text size (default ≈ 52pt)")
        attachScreenshot(app, named: "Settings AX5 transliteration")
        let notifications = app.buttons["settings.allowNotifications"]
        for _ in 0..<8 where !notifications.isHittable { app.swipeUp(velocity: .fast) }
        XCTAssertTrue(notifications.isHittable, "Notification control is reachable at the largest text size")
        attachScreenshot(app, named: "Settings AX5 notifications")
    }

    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func completeFaithNeutralOnboarding(_ app: XCUIApplication) {
        tap(app.buttons["onboarding.getStarted"])
        completeOnboardingAfterWelcome(app)
    }

    private func completeOnboardingAfterWelcome(_ app: XCUIApplication) {
        tap(app.buttons["faith.none"])
        continueTo(app, app.textFields.firstMatch)                 // → personalize
        continueTo(app, app.buttons["onboarding.privacyPolicy"])        // → privacy
        continueTo(app, app.staticTexts["Choose where to pause"])        // → protection
        continueTo(app, app.buttons["onboarding.notificationsLater"])   // → notifications
        tap(app.buttons["onboarding.notificationsLater"])
        XCTAssertTrue(app.buttons["onboarding.finish"].waitForExistence(timeout: 15), "Setup ends with a summary")
        tap(app.buttons["onboarding.finish"])
    }
}
