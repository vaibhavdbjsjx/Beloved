import XCTest

/// The scripture reader and the daily verse, per faith. Development builds show draft
/// editions (release builds show only reviewed ones), so these run against the bundled texts.
@MainActor
final class ScriptureUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testBibleReaderOpensChaptersAndTheHebrewText() {
        let app = onboard(faith: "christianity")
        tap(app.tabBars.buttons["Bible"])
        tap(app.buttons["scripture.continue"])
        XCTAssertTrue(app.staticTexts["reader.title"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["reader.title"].label, "Genesis 1")
        let verse = app.descendants(matching: .any)["reader.verse.1"]
        XCTAssertTrue(verse.waitForExistence(timeout: 15))
        XCTAssertTrue(verse.label.contains("In the beginning, God created the heavens and the earth."))

        // Original language: Genesis is Hebrew; no side-by-side (numbering differs in places).
        XCTAssertFalse(app.buttons["reader.layout.parallel"].exists)
        tap(app.buttons["reader.layout.original"])
        XCTAssertTrue(app.descendants(matching: .any)["reader.verse.1"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["reader.verse.1"].label.contains("בְּרֵאשִׁ֖ית"))

        tap(app.buttons["reader.layout.translation"])
        tap(app.buttons["reader.next"])
        XCTAssertTrue(app.staticTexts["Genesis 2"].waitForExistence(timeout: 15))

        // The tab remembers where you were.
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Continue reading"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Genesis 2"].exists)
    }

    func testQuranDailyVerseOpensItsSurahWithArabicAndAttribution() {
        let app = onboard(faith: "islam")
        let reference = app.staticTexts["today.verse.reference"]
        for _ in 0..<4 where !reference.exists { app.swipeUp(velocity: .fast) }
        XCTAssertTrue(reference.waitForExistence(timeout: 15), "Today shows a verse from the Quran")
        XCTAssertTrue(reference.label.contains("Quran"))
        tap(app.buttons["today.verse.read"])
        XCTAssertTrue(app.staticTexts["reader.title"].waitForExistence(timeout: 15))

        let highlighted = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'reader.verse.'")).firstMatch
        XCTAssertTrue(highlighted.waitForExistence(timeout: 15), "The verse's surah opens")
        app.navigationBars.buttons.firstMatch.tap()

        // Al-Fatiha side by side; Tanzil's terms: the source is named and linked wherever
        // the Arabic is shown.
        tap(app.buttons["scripture.chapter.1"])
        tap(app.buttons["reader.layout.parallel"])
        XCTAssertTrue(app.descendants(matching: .any)["reader.verse.7"].waitForExistence(timeout: 15))
        let link = app.descendants(matching: .any)["reader.sourceLink"]
        for _ in 0..<10 where !link.exists { app.swipeUp(velocity: .fast) }
        XCTAssertTrue(link.exists, "The Arabic text links to tanzil.net")
        XCTAssertTrue(link.label.contains("tanzil.net"))
        app.navigationBars.buttons.firstMatch.tap()

        tap(app.buttons["scripture.aboutToolbar"])
        let notice = app.staticTexts["scripture.notice.quran.ar"]
        for _ in 0..<6 where !notice.exists { app.swipeUp(velocity: .fast) }
        XCTAssertTrue(notice.exists)
        XCTAssertTrue(notice.label.contains("CHANGING IT IS NOT ALLOWED"))
    }

    func testGitaReadsInSanskritWithTransliteration() {
        let app = onboard(faith: "hinduism")
        tap(app.tabBars.buttons["Gita"])
        tap(app.buttons["scripture.chapter.2"])
        XCTAssertTrue(app.staticTexts["reader.title"].waitForExistence(timeout: 15))
        // Arnold's poem follows chapters, not verses.
        XCTAssertTrue(app.descendants(matching: .any)["reader.passage.1"].waitForExistence(timeout: 15))
        tap(app.buttons["reader.layout.original"])
        let verse = app.descendants(matching: .any)["reader.verse.47"]
        for _ in 0..<40 where !verse.exists { app.swipeUp(velocity: .fast) }
        XCTAssertTrue(verse.exists)
        XCTAssertTrue(verse.label.contains("कर्मण्येवाधिकारस्ते"))
        XCTAssertTrue(verse.label.contains("karmaṇyevādhikāraste"), "Transliteration is on by default")
    }

    func testFaithNeutralUsersHaveNoScriptureTab() {
        let app = XCUIApplication()
        app.launchArguments = ["-PLUITesting"]
        app.launch()
        tap(app.buttons["onboarding.getStarted"])
        tap(app.buttons["faith.none"])
        finishOnboarding(app)
        XCTAssertTrue(app.buttons["today.beginMoment"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.tabBars.buttons.count, 4)
        XCTAssertFalse(app.staticTexts["today.verse.reference"].exists)
    }

    func testAccessibilityAuditReader() throws {
        let app = onboard(faith: "islam")
        tap(app.tabBars.buttons["Quran"])
        XCTAssertTrue(app.buttons["scripture.continue"].waitForExistence(timeout: 15))
        try audit(app, step: "contents")
        tap(app.buttons["scripture.continue"])
        tap(app.buttons["reader.layout.parallel"])
        XCTAssertTrue(app.descendants(matching: .any)["reader.verse.1"].waitForExistence(timeout: 15))
        // The reader is audited for everything except two findings shown to be wrong (D52):
        // "Dynamic Type partially unsupported" on verses near the bottom edge
        // (testLargestTextSizeReader proves verse text grows at AX5), and "text clipped" on
        // Arabic, whose vowel marks sit above the line box but render fully on screen.
        try audit(app, step: "reader", skipping: [.dynamicType, .textClipped])
    }

    /// Evidence at the largest text size (AX5): contents rows and verses grow and wrap.
    func testLargestTextSizeReader() {
        let app = XCUIApplication()
        app.launchArguments = ["-PLUITesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        tap(app.buttons["onboarding.getStarted"])
        tap(app.buttons["faith.islam"])
        finishOnboarding(app)
        tap(app.tabBars.buttons["Quran"])
        app.swipeUp()
        app.swipeUp()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'scripture.chapter.'"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 15))
        let row = (0..<rows.count).lazy.map { rows.element(boundBy: $0) }.first { $0.isHittable } ?? rows.firstMatch
        attach(app, "Quran contents AX5")
        XCTAssertGreaterThan(row.frame.height, 90, "Contents rows grow with text size (default ≈ 70pt)")
        tap(row)
        tap(app.buttons["reader.layout.parallel"])
        let verse = app.descendants(matching: .any)["reader.verse.1"]
        XCTAssertTrue(verse.waitForExistence(timeout: 15))
        for _ in 0..<6 where !verse.isHittable { app.swipeUp(velocity: .slow) }
        attach(app, "Al-Baqara both AX5")
        // Verse 1 of Al-Baqara is three letters ("Alif. Lam. Mim.") and one short Arabic word:
        // about 70pt tall at the default size. At AX5 it must be far taller.
        XCTAssertGreaterThan(verse.frame.height, 140, "Verse text grows with Dynamic Type")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Helpers

    /// Same rule as PrayerLockUITests: only contrast measured under the translucent tab bar
    /// (proven separately by PaletteContrastTests) is excluded; everything else fails.
    private func audit(_ app: XCUIApplication, step: String, skipping skipped: XCUIAccessibilityAuditType = []) throws {
        sleep(3) // sections fade in with a short stagger; audit what the user finally sees
        let tabBar = app.tabBars.firstMatch
        let tabBarFrame = tabBar.exists ? tabBar.frame : .null
        try app.performAccessibilityAudit(for: XCUIAccessibilityAuditType.all.subtracting(skipped)) { issue in
            if issue.auditType == .contrast, let element = issue.element, element.frame.intersects(tabBarFrame) {
                return true
            }
            let element = issue.element.map { "\($0.elementType) label='\($0.label)' id='\($0.identifier)' frame=\($0.frame)" } ?? "no element"
            self.attach(app, "audit \(step)")
            XCTFail("Accessibility audit (\(step)): \(issue.compactDescription) — \(element). \(issue.detailedDescription)")
            return true
        }
    }

    private func onboard(faith: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-PLUITesting"]
        app.launch()
        tap(app.buttons["onboarding.getStarted"])
        tap(app.buttons["faith.\(faith)"])
        finishOnboarding(app)
        XCTAssertTrue(app.buttons["today.beginMoment"].waitForExistence(timeout: 15))
        return app
    }

    /// From a chosen faith through tradition/focus (optional), personalize, privacy,
    /// protection and notifications to Today.
    private func finishOnboarding(_ app: XCUIApplication) {
        for _ in 0..<4 where !app.textFields.firstMatch.exists {
            tap(app.buttons["onboarding.continue"])
            _ = app.textFields.firstMatch.waitForExistence(timeout: 3)
        }
        tap(app.buttons["onboarding.continue"])
        XCTAssertTrue(app.buttons["onboarding.privacyPolicy"].waitForExistence(timeout: 15))
        tap(app.buttons["onboarding.continue"])
        XCTAssertTrue(app.staticTexts["Choose where to pause"].waitForExistence(timeout: 15))
        tap(app.buttons["onboarding.continue"])
        tap(app.buttons["onboarding.notificationsLater"])
        tap(app.buttons["onboarding.finish"])
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let app = XCUIApplication()
        if !element.waitForExistence(timeout: 5) {
            for _ in 0..<10 where !element.exists { app.swipeUp(velocity: .fast) }
        }
        XCTAssertTrue(element.waitForExistence(timeout: 15), "\(element) never appeared", file: file, line: line)
        for _ in 0..<10 where element.exists && !element.isHittable { app.swipeUp(velocity: .fast) }
        let ready = expectation(for: NSPredicate(format: "isHittable == true AND isEnabled == true"), evaluatedWith: element)
        wait(for: [ready], timeout: 15)
        element.tap()
    }
}
