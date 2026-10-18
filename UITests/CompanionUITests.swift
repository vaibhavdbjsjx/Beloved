import CoreLocation
import XCTest

/// The companion in this build answers from the verified library (no server configured),
/// so these check the safety route, verified passages and prayers, and honest labelling.
@MainActor
final class CompanionUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testScriptureQuestionShowsTheVerifiedPassage() {
        let app = onboard(faith: "christianity")
        tap(app.tabBars.buttons["Companion"])
        type(app, "What does Psalm 23:1-3 mean?")
        let passage = app.descendants(matching: .any)["companion.passage"]
        XCTAssertTrue(passage.waitForExistence(timeout: 20), "The verse appears from the verified library")
        XCTAssertTrue(app.staticTexts["From Beloved's library"].exists, "Library answers are labelled as such, not as AI")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "The LORD is my shepherd")).firstMatch.exists)
    }

    func testHinduSuggestionReturnsALibraryPrayer() {
        let app = onboard(faith: "hinduism")
        tap(app.tabBars.buttons["Companion"])
        tap(app.buttons.matching(identifier: "companion.suggestion").firstMatch)
        let reply = app.descendants(matching: .any)["companion.reply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 20))
    }

    func testCrisisLanguageShowsSupportNotAnAnswer() {
        let app = onboard(faith: "islam")
        tap(app.tabBars.buttons["Companion"])
        type(app, "I want to end my life")
        XCTAssertTrue(app.descendants(matching: .any)["companion.support"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["You're not alone"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["companion.prayer"].exists)
    }

    func testStartOverClearsTheConversation() {
        let app = onboard(faith: "christianity")
        tap(app.tabBars.buttons["Companion"])
        type(app, "A prayer for peace")
        XCTAssertTrue(app.descendants(matching: .any)["companion.reply"].waitForExistence(timeout: 20))
        tap(app.buttons["companion.new"])
        tap(app.buttons["Start over"])
        XCTAssertTrue(app.buttons.matching(identifier: "companion.suggestion").firstMatch.waitForExistence(timeout: 10))
    }

    /// Hindu: choose today's deity, see its verified mantra, then ask the companion a story
    /// question (live server). Screenshots attached for review.
    func testHinduDeityTodayAndRealCompanion() {
        let app = onboard(faith: "hinduism")
        tap(app.buttons["today.deity.hinduism.ganesha"])
        XCTAssertTrue(app.buttons["today.deity.change"].waitForExistence(timeout: 10))
        let vakratunda = app.buttons["today.mantra.hinduism.mantra.vakratunda"]
        XCTAssertTrue(vakratunda.waitForExistence(timeout: 10), "Ganesha's mantras are listed")
        XCTAssertTrue(app.buttons["today.mantra.hinduism.stotra.sankatanashana-ganesha"].exists)
        shot(app, "today-ganesha")
        tap(vakratunda)
        tap(app.buttons["mantra.count"])
        let count = app.descendants(matching: .any)["counter.count"].firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 10))
        for _ in 0..<3 { app.tap() }
        XCTAssertEqual(count.label, "3 of 108")
        shot(app, "mala-counter")
        tap(app.buttons["counter.done"])
        tap(app.buttons["mantra.done"])
        tap(app.tabBars.buttons["Companion"])
        type(app, "Who killed Bhishma in the Mahabharata?")
        let reply = app.staticTexts["Companion · AI"]
        XCTAssertTrue(reply.waitForExistence(timeout: 60), "The live companion answers")
        sleep(12)
        shot(app, "companion-bhishma")
    }

    func testMuslimPrayerTimesAndQibla() {
        XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: 51.5074, longitude: -0.1278))
        let app = onboard(faith: "islam")
        tap(app.buttons["salah.locate"])
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow While Using App", "Allow Once"] where springboard.buttons[label].waitForExistence(timeout: 5) {
            springboard.buttons[label].tap()
            break
        }
        let appeared = app.staticTexts["salah.next"].waitForExistence(timeout: 30)
        if !appeared, let dir = ProcessInfo.processInfo.environment["BELOVED_DEBUG_DIR"] {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir + "/salah-fail.png"))
            try? app.debugDescription.write(toFile: dir + "/salah-fail.txt", atomically: true, encoding: .utf8)
        }
        XCTAssertTrue(appeared, "Prayer times appear")
        shot(app, "salah-card")
        tap(app.buttons["salah.qibla"])
        XCTAssertTrue(app.staticTexts["qibla.bearing"].waitForExistence(timeout: 10))
        shot(app, "qibla")
        tap(app.buttons["Done"].firstMatch)
        tap(app.buttons["today.journal"])
        tap(app.buttons["journal.add"])
        let field = app.textViews["journal.text"].exists ? app.textViews["journal.text"] : app.textFields["journal.text"]
        tap(field)
        field.typeText("Health for my mother")
        tap(app.buttons["journal.save"])
        XCTAssertTrue(app.staticTexts["Health for my mother"].waitForExistence(timeout: 10))
        shot(app, "dua-list")
    }

    func testCatholicRosary() {
        let app = onboard(faith: "christianity")
        tap(app.buttons["today.rosary"])
        XCTAssertTrue(app.staticTexts["rosary.prayer"].waitForExistence(timeout: 10))
        shot(app, "rosary-start")
        // Sign of the Cross, Creed, Our Father, then three Hail Marys and the Glory Be.
        for _ in 0..<7 { tap(app.buttons["rosary.next"]) }
        XCTAssertTrue(app.staticTexts["rosary.mystery"].waitForExistence(timeout: 10), "The first mystery is announced")
        shot(app, "rosary-mystery")
        tap(app.buttons["rosary.done"])
        XCTAssertTrue(app.buttons["today.journal"].waitForExistence(timeout: 10))
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    // MARK: - Helpers

    private func type(_ app: XCUIApplication, _ text: String) {
        let field = app.textViews["companion.input"].exists ? app.textViews["companion.input"] : app.textFields["companion.input"]
        tap(field)
        field.typeText(text)
        tap(app.buttons["companion.send"])
    }

    private func onboard(faith: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-PLUITesting"]
        app.launch()
        tap(app.buttons["onboarding.getStarted"])
        tap(app.buttons["faith.\(faith)"])
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
        XCTAssertTrue(app.buttons["today.beginMoment"].waitForExistence(timeout: 15))
        return app
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
