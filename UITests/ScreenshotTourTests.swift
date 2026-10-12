import XCTest

/// Visual QA, not a behavioural test: walks every main screen and attaches a screenshot of
/// each (light and dark). Skipped unless the runner has `PL_SCREENSHOT_TOUR=1`:
///
///     TEST_RUNNER_PL_SCREENSHOT_TOUR=1 xcodebuild test … \
///       -only-testing:PrayerLockUITests/ScreenshotTourTests -resultBundlePath tour.xcresult
///     xcrun xcresulttool export attachments --path tour.xcresult --output-path tour
@MainActor
final class ScreenshotTourTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PL_SCREENSHOT_TOUR"] == "1",
                          "Set TEST_RUNNER_PL_SCREENSHOT_TOUR=1 to capture the screenshot tour")
        continueAfterFailure = true
    }

    func testTourLight() { tour(prefix: "light", appearance: "light") }

    /// Dark via the app's own Appearance setting (`-pl.appearance dark` writes the
    /// preference for this launch) — the simulator appearance switch doesn't reach the app.
    func testTourDark() { tour(prefix: "dark", appearance: "dark") }

    /// The reader for each faith: Quran (Arabic + English), then the Gita (Sanskrit + IAST)
    /// after switching faith in Settings. Light and dark.
    func testScriptureTourLight() { scriptureTour(prefix: "scripture-light", appearance: "light") }
    func testScriptureTourDark() { scriptureTour(prefix: "scripture-dark", appearance: "dark") }

    // MARK: - Tour

    private func tour(prefix: String, appearance: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-PLUITesting", "-pl.appearance", appearance]
        app.launch()
        var index = 0
        func shot(_ name: String) {
            index += 1
            sleep(1) // let transitions settle; this is a screenshot tour, not a timing test
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = String(format: "%@ %02d %@", prefix, index, name)
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        // Onboarding
        wait(app.buttons["onboarding.getStarted"]); shot("welcome")
        tap(app.buttons["onboarding.getStarted"]); wait(app.buttons["faith.christianity"]); shot("faith")
        tap(app.buttons["faith.christianity"]); shot("faith-selected")
        tap(app.buttons["onboarding.continue"]); sleep(1); shot("tradition")
        tap(app.buttons["onboarding.continue"]); wait(app.textFields.firstMatch); shot("personalize")
        tap(app.buttons["onboarding.continue"]); wait(app.buttons["onboarding.privacyPolicy"]); shot("privacy")
        tap(app.buttons["onboarding.continue"]); sleep(1); shot("protection-setup")
        tap(app.buttons["onboarding.continue"]); wait(app.buttons["onboarding.notificationsLater"]); shot("notifications")
        tap(app.buttons["onboarding.notificationsLater"]); wait(app.buttons["onboarding.finish"]); shot("summary")
        tap(app.buttons["onboarding.finish"])

        // Today
        wait(app.buttons["today.beginMoment"]); shot("today")
        app.swipeUp(); shot("today-scrolled")
        app.swipeDown()

        // Moment
        tap(app.buttons["today.beginMoment"]); wait(app.buttons["moment.begin"]); shot("moment-arrival")
        tap(app.buttons["moment.begin"]); sleep(1); shot("moment-checkin")
        let mood = app.buttons["mood.grateful"]
        if mood.waitForExistence(timeout: 5) { tap(mood) } else if app.buttons["Skip"].exists { tap(app.buttons["Skip"]) }
        wait(app.buttons["moment.finish"]); shot("moment-reflection")
        let finish = app.buttons["moment.finish"]
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: finish)
        wait(for: [enabled], timeout: 20)
        tap(finish); sleep(1); shot("moment-intention")
        let skip = app.buttons["moment.intentionSkip"].exists ? app.buttons["moment.intentionSkip"] : app.buttons["Skip"]
        tap(skip); wait(app.buttons["moment.done"]); shot("moment-complete")
        tap(app.buttons["moment.done"])

        // Today's sheets (after the moment, so the moment's own check-in was captured)
        tap(app.buttons["today.mood"]); sleep(1); shot("today-mood-sheet")
        tap(app.buttons["mood.hopeful"]); sleep(1)
        tap(app.buttons["today.intention"]); sleep(1)
        if app.buttons["Rest my mind"].waitForExistence(timeout: 5) { tap(app.buttons["Rest my mind"]) }
        shot("today-intentions-sheet")
        tap(app.buttons["intentions.save"]); sleep(1)
        app.swipeDown(); shot("today-with-intention")

        // Bible
        tap(app.tabBars.buttons["Bible"]); sleep(1); shot("bible-contents")
        tap(app.buttons["scripture.continue"]); wait(app.staticTexts["reader.title"]); shot("bible-genesis-1")
        tap(app.buttons["reader.layout.original"]); sleep(1); shot("bible-genesis-1-hebrew")
        tap(app.buttons["reader.layout.translation"])
        app.navigationBars.buttons.firstMatch.tap(); sleep(1)

        // Tabs
        tap(app.tabBars.buttons["Protection"]); sleep(1); shot("protection")
        tap(app.tabBars.buttons["Today"]); tap(app.buttons["today.journey"]); sleep(1); shot("journey")
        app.swipeUp(); shot("journey-scrolled")
        let past = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "ago")).firstMatch
        if past.waitForExistence(timeout: 5) {
            tap(past); sleep(1); shot("journey-revisit")
            app.navigationBars.buttons.firstMatch.tap(); sleep(1)
        }
        // Companion (library mode in this build)
        tap(app.tabBars.buttons["Companion"]); sleep(1); shot("companion-welcome")
        let input = app.textViews["companion.input"].exists ? app.textViews["companion.input"] : app.textFields["companion.input"]
        tap(input); input.typeText("What does Psalm 23:1-3 mean?")
        tap(app.buttons["companion.send"]); sleep(2); shot("companion-answer")
        tap(app.tabBars.buttons["Settings"]); sleep(1); shot("settings")
        app.swipeUp(); shot("settings-scrolled")
        app.swipeUp(); shot("settings-bottom")
    }

    private func scriptureTour(prefix: String, appearance: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-PLUITesting", "-pl.appearance", appearance]
        app.launch()
        var index = 0
        func shot(_ name: String) {
            index += 1
            sleep(1)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = String(format: "%@ %02d %@", prefix, index, name)
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        tap(app.buttons["onboarding.getStarted"])
        tap(app.buttons["faith.islam"])
        for _ in 0..<4 where !app.textFields.firstMatch.exists {
            tap(app.buttons["onboarding.continue"]); _ = app.textFields.firstMatch.waitForExistence(timeout: 3)
        }
        tap(app.buttons["onboarding.continue"]); wait(app.buttons["onboarding.privacyPolicy"])
        tap(app.buttons["onboarding.continue"]); sleep(1)
        tap(app.buttons["onboarding.continue"]); tap(app.buttons["onboarding.notificationsLater"])
        tap(app.buttons["onboarding.finish"])

        wait(app.buttons["today.beginMoment"])
        let verse = app.staticTexts["today.verse.reference"]
        for _ in 0..<4 where !(verse.exists && verse.isHittable) { app.swipeUp() }
        shot("today-verse-quran")
        tap(app.tabBars.buttons["Quran"]); sleep(1); shot("quran-contents")
        tap(app.buttons["scripture.chapter.1"]); wait(app.staticTexts["reader.title"]); shot("quran-fatiha-english")
        tap(app.buttons["reader.layout.original"]); sleep(1); shot("quran-fatiha-arabic")
        tap(app.buttons["reader.layout.parallel"]); sleep(1); shot("quran-fatiha-both")
        app.navigationBars.buttons.firstMatch.tap(); sleep(1)
        tap(app.buttons["scripture.aboutToolbar"]); sleep(1); shot("quran-sources")
        app.navigationBars.buttons.firstMatch.tap(); sleep(1)

        // Switch to Hinduism in Settings → the tab becomes the Gita.
        tap(app.tabBars.buttons["Settings"]); sleep(1)
        tap(app.staticTexts["Faith & tradition"])
        tap(app.buttons["faith.hinduism"])
        tap(app.navigationBars.buttons["Save"]); sleep(1)
        tap(app.tabBars.buttons["Gita"]); sleep(1); shot("gita-contents")
        tap(app.buttons["scripture.chapter.2"]); wait(app.staticTexts["reader.title"]); shot("gita-2-arnold")
        tap(app.buttons["reader.layout.original"]); sleep(1); shot("gita-2-sanskrit")
        tap(app.tabBars.buttons["Today"]); sleep(1)
        for _ in 0..<4 where !(verse.exists && verse.isHittable) { app.swipeUp() }
        shot("today-verse-gita")
    }

    private func wait(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 20), "\(element) never appeared")
    }

    private func tap(_ element: XCUIElement) {
        guard element.waitForExistence(timeout: 20) else {
            XCTFail("\(element) never appeared")
            return
        }
        let app = XCUIApplication()
        for _ in 0..<6 where !element.isHittable { app.swipeUp() }
        element.tap()
    }
}
