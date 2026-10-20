import CoreLocation
import XCTest

/// App Store screenshots: genuine screens of the running app (no onboarding), full resolution,
/// written to the folder named by `BELOVED_SHOTS_DIR`. Skipped unless it is set:
///
///     TEST_RUNNER_BELOVED_SHOTS_DIR=docs/app-store/screenshots xcodebuild test … \
///       -only-testing:PrayerLockUITests/StoreScreenshotTests
@MainActor
final class StoreScreenshotTests: XCTestCase {
    private var directory: String { ProcessInfo.processInfo.environment["BELOVED_SHOTS_DIR"] ?? "" }

    override func setUpWithError() throws {
        try XCTSkipIf(directory.isEmpty, "Set TEST_RUNNER_BELOVED_SHOTS_DIR to capture App Store screenshots")
        continueAfterFailure = false
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
    }

    private func launch(_ faith: String, tradition: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-PLUITesting", "-PLUnlockPremium", "-PLStoreScreenshots", "-PLPreviewFaith", faith] + (tradition.map { ["-PLPreviewTradition", $0] } ?? [])
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 60))
        return app
    }

    private func shot(_ name: String) {
        sleep(2)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: directory + "/" + name + ".png"))
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let app = XCUIApplication()
        if !element.waitForExistence(timeout: 5) { for _ in 0..<10 where !element.exists { app.swipeUp(velocity: .fast) } }
        XCTAssertTrue(element.waitForExistence(timeout: 20), "\(element) never appeared", file: file, line: line)
        for _ in 0..<10 where element.exists && !element.isHittable { app.swipeUp(velocity: .fast) }
        element.tap()
    }

    func testHindu() {
        let app = launch("hinduism")
        shot("1-hindu-today")
        tap(app.buttons["today.deity.hinduism.ganesha"])
        XCTAssertTrue(app.buttons["today.mantra.hinduism.mantra.vakratunda"].waitForExistence(timeout: 20))
        app.swipeUp(velocity: .slow)
        shot("2-hindu-mantras-by-purpose")
        app.swipeDown(velocity: .fast)
        tap(app.buttons["today.mantra.hinduism.mantra.vakratunda"])
        XCTAssertTrue(app.buttons["mantra.count"].waitForExistence(timeout: 20))
        shot("3-hindu-mantra-sanskrit")
        tap(app.buttons["mantra.done"])
        tap(app.tabBars.buttons["Companion"])
        if app.buttons["companion.new"].waitForExistence(timeout: 5) {
            app.buttons["companion.new"].tap()
            tap(app.buttons["Start over"])
        }
        let field = app.textViews["companion.input"].exists ? app.textViews["companion.input"] : app.textFields["companion.input"]
        tap(field)
        field.typeText("Who killed Bhishma in the Mahabharata, and how? Two short paragraphs please.")
        tap(app.buttons["companion.send"])
        let answered = app.staticTexts["Companion · AI"].waitForExistence(timeout: 180)
        if !answered { shot("debug-companion") }
        XCTAssertTrue(answered)
        sleep(30)
        // Drag down through the keyboard: the chat dismisses it interactively.
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        from.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        sleep(2)
        shot("4-companion-answer")
    }

    func testMuslim() {
        XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: 25.2048, longitude: 55.2708))
        let app = launch("islam")
        tap(app.buttons["salah.locate"])
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow While Using App", "Allow Once"] where springboard.buttons[label].waitForExistence(timeout: 8) {
            springboard.buttons[label].tap(); break
        }
        XCTAssertTrue(app.staticTexts["salah.next"].waitForExistence(timeout: 60))
        shot("5-muslim-prayer-times")
        app.tabBars.buttons["Pray"].tap()
        XCTAssertTrue(app.buttons["pray.salah"].waitForExistence(timeout: 20))
        shot("6-muslim-pray")
    }

    func testChristian() {
        let app = launch("christianity", tradition: "christianity.catholic")
        app.tabBars.buttons["Pray"].tap()
        tap(app.buttons["pray.rosary"])
        XCTAssertTrue(app.staticTexts["rosary.prayer"].waitForExistence(timeout: 20))
        for _ in 0..<7 { tap(app.buttons["rosary.next"]) }
        XCTAssertTrue(app.staticTexts["rosary.mystery"].waitForExistence(timeout: 20))
        shot("7-christian-rosary")
    }
}
