//
//  ScreenshotTests.swift
//  SixFourChessAppUITests
//
//  Generates App Store screenshots for 3 languages (EN, FR, IT) in light mode.
//  Run on iPhone 16 Pro Max simulator (6.9") for App Store screenshots.
//
//  Usage:
//    xcodebuild test \
//      -project SixFourChessApp.xcodeproj \
//      -scheme "SixFourChessApp Dev" \
//      -destination "platform=iOS Simulator,name=iPhone 16 Pro Max,OS=18.5" \
//      -only-testing:SixFourChessAppUITests/ScreenshotTests \
//      -resultBundlePath ./screenshots.xcresult
//

import XCTest

final class ScreenshotTests: XCTestCase {

    private let languages: [(code: String, locale: String)] = [
        ("en", "en_US"),
        ("fr", "fr_FR"),
        ("it", "it_IT")
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func launchApp(language: String, locale: String, scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--uitesting"]
        app.launchArguments += ["--screenshot-scenario", scenario]
        app.launchArguments += ["-AppleLanguages", "(\(language))"]
        app.launchArguments += ["-AppleLocale", locale]
        app.launch()
        return app
    }

    private func takeScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Find the settings button in the navigation bar.
    private func tapSettingsButton(_ app: XCUIApplication) {
        let settingsButton = app.navigationBars.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button should exist")
        settingsButton.tap()
    }

    // MARK: - Screenshot 1: Game Board

    @MainActor
    func testGameBoard() throws {
        for lang in languages {
            let app = launchApp(language: lang.code, locale: lang.locale, scenario: "board")

            // Wait for the chess board to appear (AI mode is the default)
            let board = app.otherElements["chessBoardView"]
            XCTAssertTrue(board.waitForExistence(timeout: 10), "Chess board should appear for \(lang.code)")

            Thread.sleep(forTimeInterval: 1.0)

            takeScreenshot(app, name: "\(lang.code)_01_GameBoard")
            app.terminate()
        }
    }

    // MARK: - Screenshot 2: Hint System

    @MainActor
    func testHintSystem() throws {
        for lang in languages {
            let app = launchApp(language: lang.code, locale: lang.locale, scenario: "hint")

            let board = app.otherElements["chessBoardView"]
            XCTAssertTrue(board.waitForExistence(timeout: 10), "Chess board should appear for \(lang.code)")

            let hintSheet = app.otherElements["hintSheetView"]
            XCTAssertTrue(hintSheet.waitForExistence(timeout: 10), "Hint sheet should appear for \(lang.code)")

            takeScreenshot(app, name: "\(lang.code)_02_HintSystem")
            app.terminate()
        }
    }

    // MARK: - Screenshot 3: Settings

    @MainActor
    func testSettings() throws {
        for lang in languages {
            let app = launchApp(language: lang.code, locale: lang.locale, scenario: "settings")

            let board = app.otherElements["chessBoardView"]
            XCTAssertTrue(board.waitForExistence(timeout: 10), "Chess board should appear for \(lang.code)")

            tapSettingsButton(app)
            Thread.sleep(forTimeInterval: 1.0)

            takeScreenshot(app, name: "\(lang.code)_03_Settings")

            app.terminate()
        }
    }

    // MARK: - Screenshot 4: Played Games History

    @MainActor
    func testPlayedGamesHistory() throws {
        for lang in languages {
            let app = launchApp(language: lang.code, locale: lang.locale, scenario: "history")

            let board = app.otherElements["chessBoardView"]
            XCTAssertTrue(board.waitForExistence(timeout: 10), "Chess board should appear for \(lang.code)")

            tapSettingsButton(app)
            let historyLink = app.descendants(matching: .any)["playedGamesHistoryLink"]
            XCTAssertTrue(historyLink.waitForExistence(timeout: 5), "Played games history link should exist for \(lang.code)")
            historyLink.tap()

            Thread.sleep(forTimeInterval: 1.0)

            takeScreenshot(app, name: "\(lang.code)_04_PlayedGames")
            app.terminate()
        }
    }

    // MARK: - Screenshot 5: Replay

    @MainActor
    func testReplay() throws {
        for lang in languages {
            let app = launchApp(language: lang.code, locale: lang.locale, scenario: "replay")

            let board = app.otherElements["chessBoardView"]
            XCTAssertTrue(board.waitForExistence(timeout: 10), "Chess board should appear for \(lang.code)")

            tapSettingsButton(app)
            let historyLink = app.descendants(matching: .any)["playedGamesHistoryLink"]
            XCTAssertTrue(historyLink.waitForExistence(timeout: 5), "Played games history link should exist for \(lang.code)")
            historyLink.tap()

            let firstGame = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "playedGameRow_"))
                .firstMatch
            XCTAssertTrue(firstGame.waitForExistence(timeout: 5), "At least one played game should exist for \(lang.code)")
            firstGame.tap()

            let nextButton = app.buttons["replay_chevron.forward"]
            XCTAssertTrue(nextButton.waitForExistence(timeout: 5), "Replay next button should exist for \(lang.code)")
            nextButton.tap()
            nextButton.tap()

            Thread.sleep(forTimeInterval: 1.0)

            takeScreenshot(app, name: "\(lang.code)_05_Replay")
            app.terminate()
        }
    }
}
