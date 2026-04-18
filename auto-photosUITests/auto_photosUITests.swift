//
//  auto_photosUITests.swift
//  auto-photosUITests
//
//  Created by 박소연 on 4/19/26.
//

import XCTest

final class auto_photosUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testHomeStateShowsPrimaryCTA() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_SCENARIO_HOME")
        app.launch()

        XCTAssertTrue(app.buttons["home.makeVideoButton"].exists)
    }

    @MainActor
    func testInvalidSelectionStateShowsValidationMessage() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_SCENARIO_INVALID_SELECTION")
        app.launch()

        XCTAssertTrue(app.staticTexts["selection.validationText"].exists)
        XCTAssertFalse(app.buttons["selection.generateButton"].isEnabled)
    }

    @MainActor
    func testGeneratingStateShowsProgressCopy() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_SCENARIO_GENERATING")
        app.launch()

        XCTAssertTrue(app.staticTexts["generation.statusText"].exists)
        XCTAssertTrue(app.buttons["generation.cancelButton"].exists)
    }

    @MainActor
    func testPreviewStateShowsSaveAndShareActions() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_SCENARIO_PREVIEW")
        app.launch()

        XCTAssertTrue(app.buttons["preview.saveButton"].exists)
        XCTAssertTrue(app.buttons["preview.shareButton"].exists)
    }

    @MainActor
    func testErrorStateShowsRetryAction() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_SCENARIO_ERROR")
        app.launch()

        XCTAssertTrue(app.buttons["error.retryButton"].exists)
    }
}
