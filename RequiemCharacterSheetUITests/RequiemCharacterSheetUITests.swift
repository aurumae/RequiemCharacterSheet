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

        // Create a character on a blank sheet and give it a name
        app.buttons["New Character"].tap()
        app.buttons["Blank Sheet"].tap()
        let nameField = app.buttons["Tap to edit"].firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        app.textFields.firstMatch.typeText("\(characterName)\n")
        // The name is saved once editing ends and it shows on the sheet
        XCTAssertTrue(app.buttons[characterName].waitForExistence(timeout: 5))

        // Going back keeps the changes
        app.navigationBars.buttons["Characters"].tap()
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

    /// Guided creation shows its checklist, and leaving it keeps the character as a blank sheet.
    @MainActor
    func testGuidedCreationShowsTheStepsAndCanBeLeft() throws {
        let app = XCUIApplication()
        launchSkippingSplash(app)

        app.buttons["New Character"].tap()
        app.buttons["Guided Character Creation"].tap()
        XCTAssertTrue(app.staticTexts["CHARACTER CREATION"].waitForExistence(timeout: 5))
        // The buttons are below the seven steps, and off-screen list rows aren't created until scrolled to
        let finish = app.buttons["Finish Creation"]
        // Slow swipes, so a fast one doesn't carry the button past the screen again
        for _ in 0..<6 where !finish.isHittable {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(finish.exists)

        app.buttons["Leave Guided Creation"].tap()
        app.buttons["Leave Guided Creation"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["CHARACTER CREATION"].waitForNonExistence(timeout: 5))

        // Tidy up: delete the unnamed character
        app.navigationBars.buttons["Characters"].tap()
        let row = app.staticTexts["Unnamed Character"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["Delete"].tap()
        app.buttons["Delete Unnamed Character"].tap()
    }

    /// Launches the app and taps through the splash screen to the character list.
    @MainActor
    private func launchSkippingSplash(_ app: XCUIApplication) {
        app.launch()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["New Character"].waitForExistence(timeout: 5))
    }
}
