//
//  RequiemCharacterSheetUITests.swift
//  RequiemCharacterSheetUITests
//
//  Created by Oisín McColgan on 16/09/2024.
//

import XCTest

/// End-to-end check of the core flow: create a character, name it, and find it again after relaunching.
final class RequiemCharacterSheetUITests: XCTestCase {
    private let characterName = "UI Test Vampire \(Int.random(in: 1000...9999))"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCreatedCharacterIsSavedAndCanBeDeleted() throws {
        let app = XCUIApplication()
        launchSkippingSplash(app)

        // Create a character and give it a name
        app.buttons["New Character"].tap()
        let nameField = app.buttons["Tap to edit"].firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        app.textFields.firstMatch.typeText("\(characterName)\n")

        // Going back keeps the changes
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts[characterName].waitForExistence(timeout: 5))

        // The character is still there after relaunching
        app.terminate()
        launchSkippingSplash(app)
        let row = app.staticTexts[characterName]
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        // Delete it again, confirming when asked
        row.swipeLeft()
        app.buttons["Delete"].tap()
        app.buttons["Delete \(characterName)"].tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: 5))
    }

    /// Launches the app and taps through the splash screen to the character list.
    @MainActor
    private func launchSkippingSplash(_ app: XCUIApplication) {
        app.launch()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["New Character"].waitForExistence(timeout: 5))
    }
}
