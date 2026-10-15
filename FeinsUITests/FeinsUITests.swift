import XCTest

/// End-to-End-Abläufe im Simulator. Die Screenshots landen im Test-Report und von dort in der PR.
final class FeinsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(seed: Bool = false, appearance: String = "light", tab: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-appearance", appearance]
        if seed { app.launchArguments.append("-seed-sample-data") }
        if let tab { app.launchArguments += ["-tab", tab] }
        app.launch()
        return app
    }

    private func screenshot(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testAddDishByTypingCorrectsTypoAndAddsRecipe() {
        let app = launch()
        XCTAssertTrue(app.otherElements["emptyState"].waitForExistence(timeout: 5) || app.staticTexts["Was gits feins?"].exists)
        screenshot("01-leer", app)

        let field = app.textFields["quickAdd.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("spagetti carbonara\n")

        let row = app.descendants(matching: .any)["dish.Spaghetti Carbonara"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Tippfehler wurde nicht korrigiert")
        screenshot("02-gericht-hinzugefuegt", app)

        row.tap()
        XCTAssertTrue(app.staticTexts["Zutaten"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Zubereitung"].exists)
        screenshot("03-rezept", app)
    }

    @MainActor
    func testChooserSuggestsOwnDish() {
        let app = launch(seed: true, tab: "chooser")
        let surprise = app.buttons["chooser.surprise"]
        XCTAssertTrue(surprise.waitForExistence(timeout: 5))
        surprise.tap()

        let name = app.staticTexts["chooser.result.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let ownDishes = ["Älplermagronen", "Poulet-Curry", "Shakshuka", "Kürbissuppe", "Spaghetti Carbonara"]
        XCTAssertTrue(ownDishes.contains(name.label), "\(name.label) ist kein eigenes Gericht")
        XCTAssertTrue(app.staticTexts["Aus deinen Gerichten"].exists)
    }

    @MainActor
    func testChooserFiltersByIngredient() {
        let app = launch(seed: true, tab: "chooser")
        let field = app.textFields["chooser.ingredientField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Kürbis\n")
        app.buttons["chooser.surprise"].tap()

        let name = app.staticTexts["chooser.result.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.label, "Kürbissuppe")
        screenshot("05-chooser-zutaten", app)
    }

    @MainActor
    func testChooserWithNewIdeasCanSaveIdea() {
        let app = launch(tab: "chooser")
        app.buttons["Auch neue Ideen"].tap()
        let field = app.textFields["chooser.ingredientField"]
        field.tap()
        field.typeText("Linsen\n")
        app.buttons["chooser.surprise"].tap()

        let name = app.staticTexts["chooser.result.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.label, "Linsen-Dal")
        XCTAssertTrue(app.staticTexts["Neue Idee"].exists)

        app.buttons["chooser.result.open"].tap()
        let save = app.buttons["idea.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        app.tabBars.buttons["Gerichte"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["dish.Linsen-Dal"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testChooserShowsHintWhenNothingMatches() {
        let app = launch(seed: true, tab: "chooser")
        let field = app.textFields["chooser.ingredientField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Marshmallows\n")
        app.buttons["chooser.surprise"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["chooser.empty"].waitForExistence(timeout: 5))
    }

    /// Screenshots aller Hauptscreens, hell und dunkel.
    @MainActor
    func testScreenshotTour() {
        for appearance in ["light", "dark"] {
            let app = launch(seed: true, appearance: appearance)
            XCTAssertTrue(app.descendants(matching: .any)["dish.Älplermagronen"].waitForExistence(timeout: 5))
            screenshot("10-gerichte-\(appearance)", app)

            app.descendants(matching: .any)["dish.Älplermagronen"].tap()
            XCTAssertTrue(app.staticTexts["Zutaten"].waitForExistence(timeout: 5))
            screenshot("11-rezept-\(appearance)", app)

            app.tabBars.buttons["Was gits feins?"].tap()
            app.buttons["chooser.surprise"].tap()
            XCTAssertTrue(app.staticTexts["chooser.result.name"].waitForExistence(timeout: 5))
            screenshot("12-chooser-\(appearance)", app)

            app.tabBars.buttons["Einstellungen"].tap()
            XCTAssertTrue(app.navigationBars["Einstellungen"].waitForExistence(timeout: 5))
            screenshot("13-einstellungen-\(appearance)", app)
            app.terminate()
        }
    }
}
