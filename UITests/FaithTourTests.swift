import XCTest

/// Visual QA for each faith's main screens (Today, Pray, Companion, You), using the
/// development-only `-PLPreviewFaith` launch option to skip onboarding. Skipped unless the
/// runner has `PL_SCREENSHOT_TOUR=1`.
@MainActor
final class FaithTourTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PL_SCREENSHOT_TOUR"] == "1",
                          "Set TEST_RUNNER_PL_SCREENSHOT_TOUR=1 to capture the faith tour")
        continueAfterFailure = true
    }

    func testHinduTour() { tour("hinduism") }
    func testMuslimTour() { tour("islam") }
    func testCatholicTour() { tour("christianity", tradition: "christianity.catholic") }

    private func tour(_ faith: String, tradition: String? = nil) {
        let app = XCUIApplication()
        app.launchArguments = ["-PLUITesting", "-PLPreviewFaith", faith] + (tradition.map { ["-PLPreviewTradition", $0] } ?? [])
        app.launch()
        var index = 0
        func shot(_ name: String) {
            index += 1
            sleep(1)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = String(format: "%@ %02d %@", faith, index, name)
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 30))
        shot("today")
        for page in 1...4 { app.swipeUp(); shot("today-\(page)") }

        app.tabBars.buttons["Pray"].tap()
        shot("pray")
        for page in 1...4 { app.swipeUp(); shot("pray-\(page)") }

        app.tabBars.buttons["Companion"].tap()
        shot("companion")

        app.tabBars.buttons["You"].tap()
        shot("you")
    }
}
