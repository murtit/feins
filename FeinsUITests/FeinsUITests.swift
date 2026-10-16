import XCTest

/// End-to-End-Abläufe im Simulator. Die Screenshots landen im Test-Report und von dort in der PR.
final class FeinsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(seed: Bool = false, appearance: String = "light", tab: String? = nil, speech: String? = nil, aiStatus: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-appearance", appearance]
        if seed { app.launchArguments.append("-seed-sample-data") }
        if let speech { app.launchArguments += ["-simulate-speech", speech] }
        if let tab { app.launchArguments += ["-tab", tab] }
        if let aiStatus { app.launchArguments += ["-ai-status", aiStatus] }
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

        let add = app.buttons["addDish.button"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        let field = app.textFields["quickAdd.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("spagetti carbonara")
        // Der Simulator zeigt beim ersten Tippen manchmal eine Tastatur-Einführung über der App.
        let keyboardTip = app.buttons["Continue"]
        if keyboardTip.waitForExistence(timeout: 1) { keyboardTip.tap() }
        screenshot("01b-eintippen", app)
        app.buttons["quickAdd.submit"].tap()

        let row = app.descendants(matching: .any)["dish.Spaghetti Carbonara"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Tippfehler wurde nicht korrigiert")
        screenshot("02-gericht-hinzugefuegt", app)

        row.tap()
        XCTAssertTrue(app.staticTexts["Zutaten"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Zubereitung"].exists)
        screenshot("03-rezept", app)
    }

    @MainActor
    func testAddDishBySwipingUpAndSpeaking() {
        let app = launch(speech: "zürcher geschnezeltes")
        let add = app.buttons["addDish.button"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))

        // Kreis greifen und nach oben ziehen: das startet das Einsprechen.
        let start = add.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -160)))

        let bubble = app.descendants(matching: .any)["addDish.bubble"].firstMatch
        XCTAssertTrue(bubble.waitForExistence(timeout: 6), "Einsprechen wurde nicht gestartet")
        screenshot("04-einsprechen", app)

        let row = app.descendants(matching: .any)["dish.Zürcher Geschnetzeltes"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Eingesprochenes Gericht fehlt")
        XCTAssertFalse(app.textFields["quickAdd.field"].exists, "Nach dem Wischen soll keine Tastatur aufgehen")
    }

    @MainActor
    func testTypingBarCanBeClosed() {
        let app = launch()
        let add = app.buttons["addDish.button"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(app.textFields["quickAdd.field"].waitForExistence(timeout: 5))
        app.buttons["quickAdd.close"].tap()
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["quickAdd.field"].exists)
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
    func testTappingTheDieRollsADish() {
        let app = launch(seed: true, tab: "chooser")
        let die = app.buttons["chooser.die"]
        XCTAssertTrue(die.waitForExistence(timeout: 5))
        screenshot("06-wuerfel", app)
        die.tap()

        let name = app.staticTexts["chooser.result.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "Würfeln hat kein Gericht geliefert")
        XCTAssertTrue(app.buttons["chooser.surprise"].label.contains("Nochmal"))
        screenshot("07-gewuerfelt", app)
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
        XCTAssertTrue(app.descendants(matching: .any)["dish.Linsen-Dal"].firstMatch.waitForExistence(timeout: 5))
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

    /// Kein Schlüssel mehr: Die Einstellungen zeigen nur noch, ob Apple Intelligence auf dem iPhone mitarbeitet.
    @MainActor
    func testSettingsShowOnDeviceAIWithoutKeyField() {
        for (status, label) in [("ready", "Aktiv"), ("unsupported", "Nicht verfügbar")] {
            let app = launch(tab: "settings", aiStatus: status)
            let row = app.descendants(matching: .any)["settings.ai"].firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            XCTAssertTrue(row.label.contains(label), "Status \(status) zeigt „\(row.label)“")
            XCTAssertFalse(app.secureTextFields.firstMatch.exists, "Es darf kein Schlüsselfeld mehr geben")
            screenshot("08-ki-\(status)", app)
            app.terminate()
        }
    }

    /// Screenshots aller Hauptscreens, hell und dunkel.
    @MainActor
    func testScreenshotTour() {
        for appearance in ["light", "dark"] {
            let app = launch(seed: true, appearance: appearance)
            XCTAssertTrue(app.descendants(matching: .any)["dish.Älplermagronen"].firstMatch.waitForExistence(timeout: 5))
            screenshot("10-gerichte-\(appearance)", app)

            app.descendants(matching: .any)["dish.Älplermagronen"].firstMatch.tap()
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
