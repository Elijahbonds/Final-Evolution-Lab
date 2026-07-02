//
//  GameModeScreenshotUITests.swift
//  Captures Arena grid + every registered gameplay shell when run on Simulator or device.
//

import XCTest

final class GameModeScreenshotUITests: XCTestCase {

    /// Must match ``GameModeRegistry.all`` count (all modes including preview).
    private let expectedModeCount = 21

    /// Split dunk contest cartridges — IRL camera H2H + in-engine 3D H2H.
    private let dunkModeIds = ["basketball_dunk_irl", "basketball_dunk_3d"]

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

    /// Standard shell: Arena tab → **Play** segment (Community/Play/Create picker).
    @MainActor
    func testMainApp_ArenaModesGridFromTabs() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-UITestMode")
        app.launch()
        print("DEBUG HIERARCHY: \(app.debugDescription)")

        navigateToPlayArena(in: app)
        attachScreenshot(from: app, name: "00_main_app_arena_modes_grid")
    }

    /// Product smoke: brain brawl trivia + dunk lobby + arcade flows.
    @MainActor
    func testProductSmoke_BrainBrawlAndDunkFlows() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-UITestMode")
        app.launch()

        navigateToPlayArena(in: app)

        let brainCard = modeLaunchButton(for: "brain_brawl", in: app)
        if brainCard.waitForExistence(timeout: 6) {
            brainCard.tap()
            XCTAssert(app.otherElements["BrainBrawlRoot"].waitForExistence(timeout: 10))
            attachScreenshot(from: app, name: "smoke_brain_brawl_hub")
            let start = app.buttons["BrainBrawlStartButton"]
            if start.waitForExistence(timeout: 4) {
                start.tap()
                XCTAssert(app.otherElements["BrainBrawlCategoryWheel"].waitForExistence(timeout: 8))
                attachScreenshot(from: app, name: "smoke_brain_brawl_wheel")
            }
            app.buttons["BACK"].firstMatch.tap()
        }

        for modeId in dunkModeIds {
            tapArenaPlaySegment(in: app)
            let modeButton = modeLaunchButton(for: modeId, in: app)
            XCTAssert(modeButton.waitForExistence(timeout: 8), "Missing mode card \(modeId)")
            modeButton.tap()
            if modeId == "basketball_dunk_irl" {
                XCTAssert(app.otherElements["DunkMatchmakingHeader"].waitForExistence(timeout: 12))
                attachScreenshot(from: app, name: "smoke_dunk_irl_lobby")
                let closeLobby = app.buttons["DunkMatchmakingClose"]
                if closeLobby.waitForExistence(timeout: 4) {
                    closeLobby.tap()
                } else {
                    app.buttons.matching(NSPredicate(format: "label CONTAINS 'BACK' OR label CONTAINS 'Exit' OR label CONTAINS 'DISMISS' OR label == 'Close'")).firstMatch.tap()
                }
            } else {
                let exit = gameplayExitButton(in: app)
                XCTAssert(exit.waitForExistence(timeout: 18))
                exit.tap()
            }
            XCTAssert(arcadeLibraryReady(in: app))
        }
    }

    /// Product smoke: Arcade library, Create generator, Status Studio, Agent tool chip.
    @MainActor
    func testProductSmoke_KeySimulatorFlows() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-UITestMode")
        app.launch()

        navigateToPlayArena(in: app)

        for modeId in dunkModeIds + ["karate_endless", "court_carnival"] {
            tapArenaPlaySegment(in: app)
            let modeButton = modeLaunchButton(for: modeId, in: app)
            XCTAssert(modeButton.waitForExistence(timeout: 8), "Missing mode card \(modeId)")
            if !modeButton.isHittable {
                app.swipeUp()
                Thread.sleep(forTimeInterval: 0.25)
            }
            modeButton.tap()
            if modeId == "basketball_dunk_irl" {
                XCTAssert(app.otherElements["DunkMatchmakingHeader"].waitForExistence(timeout: 12), "IRL dunk lobby failed for \(modeId)")
                attachScreenshot(from: app, name: "smoke_dunk_irl_lobby")
                let closeLobby = app.buttons["DunkMatchmakingClose"]
                if closeLobby.waitForExistence(timeout: 4) {
                    closeLobby.tap()
                } else {
                    app.buttons.matching(NSPredicate(format: "label CONTAINS 'BACK' OR label CONTAINS 'Exit' OR label CONTAINS 'DISMISS' OR label == 'Close'")).firstMatch.tap()
                }
            } else {
                let exit = gameplayExitButton(in: app)
                XCTAssert(exit.waitForExistence(timeout: 18), "GamePlayView failed to open for \(modeId)")
                waitForSceneViewportReady(from: app)
                attachScreenshot(from: app, name: "smoke_gameplay_\(modeId)")
                exit.tap()
            }
            XCTAssert(arcadeLibraryReady(in: app), "Arcade library did not return after exit for \(modeId)")
            Thread.sleep(forTimeInterval: 0.35)
        }

        app.buttons["ArenaSegment_create"].tap()
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssert(app.staticTexts["Early Access · Game Creator"].waitForExistence(timeout: 5))
        app.buttons["NexusGameTemplate_basketball_dunk"].tap()
        app.buttons["NexusGameGeneratorGenerateButton"].tap()
        let playNow = app.buttons["Play now"]
        XCTAssert(playNow.waitForExistence(timeout: 15), "Generator did not produce a playable spec")
        attachScreenshot(from: app, name: "smoke_generator_spec")
        playNow.tap()
        let generatorExit = gameplayExitButton(in: app)
        XCTAssert(generatorExit.waitForExistence(timeout: 12))
        waitForSceneViewportReady(from: app)
        attachScreenshot(from: app, name: "smoke_generator_play")
        generatorExit.tap()

        let statusTab = app.tabBars.buttons["Status"]
        XCTAssert(statusTab.waitForExistence(timeout: 5))
        statusTab.tap()
        let openStudio = app.buttons["OPEN NEXUS STUDIO"]
        XCTAssert(openStudio.waitForExistence(timeout: 8))
        openStudio.tap()
        XCTAssert(app.navigationBars["NEXUS Studio"].waitForExistence(timeout: 8))
        attachScreenshot(from: app, name: "smoke_studio_ide")
        let runPanel = app.segmentedControls.buttons["Run"]
        if runPanel.waitForExistence(timeout: 4) {
            runPanel.tap()
            attachScreenshot(from: app, name: "smoke_studio_run")
        }
        app.buttons["Close"].tap()
        XCTAssert(app.tabBars.firstMatch.waitForExistence(timeout: 8))

        statusTab.tap()
        let agentRow = app.buttons["Agent"]
        if agentRow.waitForExistence(timeout: 5) {
            agentRow.tap()
        } else {
            let agentStatic = app.staticTexts["Agent"]
            XCTAssert(agentStatic.waitForExistence(timeout: 5))
            agentStatic.tap()
        }
        XCTAssert(app.staticTexts["Early Access · Agent Tools"].waitForExistence(timeout: 8))
        let listModesChip = app.buttons["List Modes"].firstMatch
        XCTAssert(listModesChip.waitForExistence(timeout: 5))
        listModesChip.tap()
        Thread.sleep(forTimeInterval: 1.5)
        attachScreenshot(from: app, name: "smoke_agent_list_modes")
    }


    /// Premium design QA — Arena library, IRL + 3D Dunk, Dojo Breach, Dashboard (Status tab).
    @MainActor
    func testPremiumDesign_ScreenshotPathSmoke() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-UITestMode")
        app.launch()

        let playTab = app.tabBars.buttons["Play"]
        XCTAssert(playTab.waitForExistence(timeout: 10))
        playTab.tap()

        let librarySearch = app.otherElements["ArcadeLibrarySearch"]
        XCTAssert(librarySearch.waitForExistence(timeout: 10), "Arcade library shell not visible")
        attachScreenshot(from: app, name: "premium_arena_library")

        assertBothDunkModeCardsVisible(in: app)

        try launchGameplayMode(app, modeId: "basketball_dunk_irl", screenshotName: "premium_dunk_irl_gameplay")
        try launchGameplayMode(app, modeId: "basketball_dunk_3d", screenshotName: "premium_dunk_3d_gameplay")
        try launchGameplayMode(app, modeId: "karate_endless", screenshotName: "premium_dojo_breach_gameplay")

        let statusTab = app.tabBars.buttons["Status"]
        XCTAssert(statusTab.waitForExistence(timeout: 5))
        statusTab.tap()
        Thread.sleep(forTimeInterval: 0.6)
        attachScreenshot(from: app, name: "premium_dashboard_status")
    }

    private func launchGameplayMode(_ app: XCUIApplication, modeId: String, screenshotName: String) throws {
        let playTab = app.tabBars.buttons["Play"]
        if playTab.waitForExistence(timeout: 3) {
            playTab.tap()
        }
        XCTAssert(app.otherElements["ArcadeLibrarySearch"].waitForExistence(timeout: 8))
        let sprintCard = app.buttons["NexusSprintMode_\(modeId)"]
        let gridCard = app.buttons["GameModeCard_\(modeId)"]
        if sprintCard.waitForExistence(timeout: 2) {
            if !sprintCard.isHittable { app.swipeUp(); Thread.sleep(forTimeInterval: 0.2) }
            sprintCard.tap()
        } else {
            XCTAssert(gridCard.waitForExistence(timeout: 6), "Missing cartridge \(modeId)")
            if !gridCard.isHittable { app.swipeUp(); Thread.sleep(forTimeInterval: 0.2) }
            gridCard.tap()
        }
        let exit = app.buttons["EXIT"]
        XCTAssert(exit.waitForExistence(timeout: 18), "GamePlayView failed for \(modeId)")
        waitForSceneViewportReady(from: app)
        attachScreenshot(from: app, name: screenshotName)
        exit.tap()
        XCTAssert(app.otherElements["ArcadeLibrarySearch"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.3)
    }

    private func attachScreenshot(from app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func navigateToPlayArena(in app: XCUIApplication) {
        navigateToTab(named: "Play", in: app)

        let arenaHub = app.otherElements["ArenaHubRoot"]
        XCTAssert(arenaHub.waitForExistence(timeout: 8))

        tapArenaPlaySegment(in: app)
        XCTAssert(arcadeLibraryReady(in: app), "Arcade library did not appear on Play segment")
        assertBothDunkModeCardsVisible(in: app)
    }

    private func assertBothDunkModeCardsVisible(in app: XCUIApplication) {
        for modeId in dunkModeIds {
            var button = modeLaunchButton(for: modeId, in: app)
            if !button.waitForExistence(timeout: 6) {
                app.swipeUp()
                Thread.sleep(forTimeInterval: 0.25)
                button = modeLaunchButton(for: modeId, in: app)
            }
            XCTAssert(button.waitForExistence(timeout: 6), "Missing dunk mode card \(modeId)")
        }
    }

    private func tapArenaPlaySegment(in app: XCUIApplication) {
        let segmentedControl = app.otherElements["ArenaSegmentedControl"]
        XCTAssert(segmentedControl.waitForExistence(timeout: 5))
        let playSegment = app.buttons["ArenaSegment_modes"]
        XCTAssert(playSegment.waitForExistence(timeout: 5))
        playSegment.tap()
        Thread.sleep(forTimeInterval: 0.4)
    }

    private func arcadeLibraryReady(in app: XCUIApplication) -> Bool {
        app.scrollViews["ArcadeLibraryRoot"].waitForExistence(timeout: 8)
            || app.otherElements["ArcadeLibraryRoot"].waitForExistence(timeout: 2)
            || app.otherElements["ArcadeLibrarySearch"].waitForExistence(timeout: 2)
            || app.buttons["NexusSprintMode_basketball_dunk_3d"].waitForExistence(timeout: 2)
            || app.buttons["GameModeCard_basketball_dunk_3d"].waitForExistence(timeout: 2)
            || app.buttons["GameModeCard_basketball_dunk_irl"].waitForExistence(timeout: 2)
    }

    private func modeLaunchButton(for modeId: String, in app: XCUIApplication) -> XCUIElement {
        let candidates = [
            app.buttons["NexusSprintMode_\(modeId)"],
            app.buttons["GameModeCard_\(modeId)"],
            app.buttons["ArcadePinned_\(modeId)"],
        ]
        for candidate in candidates {
            if candidate.waitForExistence(timeout: 2) {
                return candidate
            }
        }
        return app.buttons["GameModeCard_\(modeId)"]
    }

    private func gameplayExitButton(in app: XCUIApplication) -> XCUIElement {
        let identified = app.buttons["GameplayExitButton"]
        if identified.waitForExistence(timeout: 2) { return identified }
        let labeled = app.buttons["Exit"]
        if labeled.waitForExistence(timeout: 2) { return labeled }
        return app.buttons["EXIT"]
    }

    private func navigateToTab(named label: String, in app: XCUIApplication) {
        let tabBar = app.tabBars.firstMatch
        XCTAssert(tabBar.waitForExistence(timeout: 8))
        let direct = tabBar.buttons[label]
        if direct.waitForExistence(timeout: 2) {
            direct.tap()
            return
        }
        let more = tabBar.buttons["More"]
        XCTAssert(more.waitForExistence(timeout: 3), "Tab \(label) not visible and More overflow missing")
        more.tap()
        let candidates = [
            app.buttons[label],
            app.staticTexts[label],
            app.cells[label],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch,
        ]
        for candidate in candidates {
            if candidate.waitForExistence(timeout: 3) {
                candidate.tap()
                return
            }
        }
        XCTFail("Tab \(label) missing from tab bar and overflow menu")
    }
}
