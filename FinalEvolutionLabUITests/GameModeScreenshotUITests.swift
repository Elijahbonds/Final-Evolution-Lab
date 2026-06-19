//
//  GameModeScreenshotUITests.swift
//  Captures Arena grid + every registered gameplay shell when run on Simulator or device.
//

import XCTest

final class GameModeScreenshotUITests: XCTestCase {

    /// Must match ``GameModeRegistry.all`` count (all modes including preview).
    private let expectedModeCount = 19

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testScreenshotHarness_ArenaGridAndAllGameplayModes() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-ScreenshotHarness")
        app.launch()

        XCTAssert(app.buttons["ScreenshotHarnessArenaGrid"].waitForExistence(timeout: 8))
        attachScreenshot(from: app, name: "01_arena_mode_grid_all_modes")

        app.buttons["ScreenshotHarnessGameplay"].tap()
        XCTAssert(app.buttons["ScreenshotHarnessNext"].waitForExistence(timeout: 5))

        for i in 0..<expectedModeCount {
            waitForSceneViewportReady(from: app)
            attachScreenshot(from: app, name: String(format: "02_gameplay_%02d", i + 1))
            if i < expectedModeCount - 1 {
                app.buttons["ScreenshotHarnessNext"].tap()
                Thread.sleep(forTimeInterval: 0.15)
            }
        }
    }

    /// Waits for SceneKit warm-up (`GameSceneHostView` sets accessibilityValue to `ready` after first frames).
    private func waitForSceneViewportReady(from app: XCUIApplication, timeout: TimeInterval = 4) {
        let viewport = app.otherElements["GameSceneViewport"]
        guard viewport.waitForExistence(timeout: timeout) else {
            Thread.sleep(forTimeInterval: 0.75)
            return
        }
        let ready = NSPredicate(format: "value == %@", "ready")
        let expectation = XCTNSPredicateExpectation(predicate: ready, object: viewport)
        _ = XCTWaiter.wait(for: [expectation], timeout: timeout)
        Thread.sleep(forTimeInterval: 0.35)
    }

    /// Standard shell: Arena tab → **Modes** segment (Community/Modes picker).
    @MainActor
    func testMainApp_ArenaModesGridFromTabs() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-UITestMode")
        app.launch()
        print("DEBUG HIERARCHY: \(app.debugDescription)")

        let arenaTab = app.tabBars.buttons["Arena"]
        XCTAssert(arenaTab.waitForExistence(timeout: 10))
        arenaTab.tap()

        let segmentedControl = app.segmentedControls["ArenaSegmentedControl"]
        XCTAssert(segmentedControl.waitForExistence(timeout: 5))
        let modesSegment = segmentedControl.buttons["Modes"]
        XCTAssert(modesSegment.waitForExistence(timeout: 5))
        modesSegment.tap()
        Thread.sleep(forTimeInterval: 0.4)
        attachScreenshot(from: app, name: "00_main_app_arena_modes_grid")
    }

    private func attachScreenshot(from app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
