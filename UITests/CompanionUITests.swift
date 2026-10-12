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
