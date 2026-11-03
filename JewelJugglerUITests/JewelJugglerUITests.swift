import XCTest

/// End-to-end checks. Identifiers mirror `AccessibilityID` in the app.
final class JewelJugglerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @discardableResult
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"] + extra
        app.launch()
        self.app = app
        return app
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func tap(_ id: String, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        let e = element(id)
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "Missing \(id)", file: file, line: line)
        e.tap()
    }

    @discardableResult
    private func waitHittable(_ id: String, timeout: TimeInterval = 8) -> XCUIElement {
        let e = element(id)
        let predicate = NSPredicate(format: "exists == true AND isHittable == true")
        let exp = expectation(for: predicate, evaluatedWith: e)
        wait(for: [exp], timeout: timeout)
        return e
    }

    private func toastLabel(timeout: TimeInterval = 5) -> String {
        let toast = element("toast")
        XCTAssertTrue(toast.waitForExistence(timeout: timeout), "No toast")
        return toast.label
    }

    private func digits(_ s: String) -> Int {
        Int(s.filter(\.isNumber)) ?? -1
    }

    private func back() { tap("common.back") }

    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    // MARK: - Stage and navigation

    func testStageShowsTheMainActions() {
        launch()
        XCTAssertTrue(element("stage.screen").waitForExistence(timeout: 10))
        for id in ["stage.raiseCurtain", "stage.festival", "stage.ducats", "stage.settings", "stage.guide",
                   "stage.card.wardrobe", "stage.card.trunk", "stage.card.acts", "stage.card.playbills"] {
            XCTAssertTrue(element(id).exists, "Missing \(id)")
        }
        XCTAssertEqual(digits(element("stage.ducats").label), 5000)
    }

    func testEveryScreenOpensAndReturns() {
        launch()
        XCTAssertTrue(element("stage.screen").waitForExistence(timeout: 10))
        let routes = [("stage.card.wardrobe", "wardrobe.screen"), ("stage.card.trunk", "trunk.screen"),
                      ("stage.card.acts", "acts.screen"), ("stage.card.playbills", "playbills.screen"),
                      ("stage.settings", "settings.screen"), ("stage.guide", "guide.screen")]
        for (button, screen) in routes {
            tap(button)
            XCTAssertTrue(element(screen).waitForExistence(timeout: 5), "\(screen) did not open")
            back()
            XCTAssertTrue(waitHittable("stage.raiseCurtain").exists, "Did not return from \(screen)")
        }
    }

    // MARK: - Shop

    func testBuyingAPropRaisesItsLevel() {
        launch()
        tap("stage.card.trunk")
        XCTAssertTrue(element("trunk.screen").waitForExistence(timeout: 5))
        XCTAssertEqual(element("trunk.level.velvetGloves").label, "Level 0 of 5")
        tap("trunk.buy.velvetGloves")
        XCTAssertTrue(toastLabel().hasPrefix("Velvet Gloves raised"))
        XCTAssertEqual(element("trunk.level.velvetGloves").label, "Level 1 of 5")
    }

    func testBuyingWithoutDucatsIsRefused() {
        launch(["--freshstart"])
        tap("stage.card.trunk")
        tap("trunk.buy.silverBells")
        XCTAssertTrue(toastLabel().hasPrefix("You need"))
        XCTAssertEqual(element("trunk.level.silverBells").label, "Level 0 of 5")
    }

    func testBuyingAndWearingACostume() {
        launch()
        tap("stage.card.wardrobe")
        tap("wardrobe.costume.moonlitFool")
        let action = element("wardrobe.action")
        XCTAssertTrue(action.waitForExistence(timeout: 3))
        XCTAssertTrue(action.label.hasPrefix("Buy for"))
        action.tap()
        XCTAssertTrue(toastLabel().contains("joins your wardrobe"))
        XCTAssertEqual(element("wardrobe.action").label, "Wearing")
        tap("wardrobe.costume.motley")
        tap("wardrobe.action")
        XCTAssertTrue(toastLabel().hasPrefix("Now wearing Classic Motley"))
    }

    func testLockedActExplainsWhy() {
        launch()
        tap("stage.card.acts")
        XCTAssertTrue(element("acts.screen").waitForExistence(timeout: 5))
        XCTAssertEqual(element("acts.act.1").value as? String, "Locked")
        tap("acts.act.1")
        XCTAssertTrue(toastLabel().hasPrefix("Earn a rose"))
    }

    func testResetProgressClearsThePurse() {
        launch()
        tap("stage.settings")
        tap("settings.reset")
        let confirm = app.buttons.matching(identifier: "settings.confirmReset").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertTrue(toastLabel().hasPrefix("A fresh season"))
        back()
        XCTAssertEqual(digits(element("stage.ducats").label), 0)
    }

    // MARK: - Shows

    func testShowStartsPausesResumesAndLeaves() {
        launch(["--invincible"])
        tap("stage.raiseCurtain")
        tap("game.begin")
        let pause = waitHittable("game.pause")
        XCTAssertTrue(element("game.bells").exists)
        XCTAssertTrue(element("game.bank").exists)
        XCTAssertTrue(element("game.jingle").exists)
        pause.tap()
        tap("game.resume")
        waitHittable("game.pause").tap()
        tap("game.quit")
        XCTAssertTrue(waitHittable("stage.raiseCurtain").exists)
    }

    func testBankButtonArmsTheChest() {
        launch(["--invincible"])
        tap("stage.raiseCurtain")
        tap("game.begin")
        waitHittable("game.pause")
        // The HUD must leave the stage most of the screen.
        XCTAssertLessThan(element("game.applause").frame.height, 80)
        XCTAssertGreaterThan(element("game.bank").frame.minY, app.windows.firstMatch.frame.height * 0.75)
        let bank = element("game.bank")
        XCTAssertEqual(bank.value as? String, "Off")
        bank.tap()
        XCTAssertEqual(bank.value as? String, "Armed")
        bank.tap()
        XCTAssertEqual(bank.value as? String, "Off")
    }

    func testFirstShowOpensTheGuide() {
        launch(["--freshstart"])
        tap("stage.raiseCurtain")
        XCTAssertTrue(element("guide.screen").waitForExistence(timeout: 5))
        tap("guide.next")
        XCTAssertTrue(element("guide.screen").exists)
        // Skip lives on the first page; the last page has "To the stage!".
        for _ in 0..<7 { tap("guide.next") }
        tap("guide.done")
        XCTAssertTrue(element("game.begin").waitForExistence(timeout: 5))
    }

    func testAutopilotCompletesTheFirstAct() {
        launch(["--autopilot"])
        tap("stage.card.acts")
        tap("acts.act.0")
        tap("game.begin")
        XCTAssertTrue(element("curtain.screen").waitForExistence(timeout: 150), "The act never reached the curtain call")
        XCTAssertTrue(waitHittable("curtain.leave", timeout: 10).exists)
        sleep(1)
        attach("14-curtain")
        XCTAssertTrue(element("curtain.next").exists, "A completed first act offers the next one")
        tap("curtain.leave")
        // The act was started from the programme, so the show returns there.
        XCTAssertTrue(element("acts.screen").waitForExistence(timeout: 5))
        XCTAssertNotEqual(element("acts.act.1").value as? String, "Locked")
    }

    // MARK: - iPad

    func testLandscapeLayoutOnPad() throws {
        launch()
        // The runner's idiom is unreliable on iPad simulators; the app window width is not.
        try XCTSkipUnless(app.windows.firstMatch.frame.width >= 700, "iPad only")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(waitHittable("stage.raiseCurtain").exists)
        XCTAssertTrue(waitHittable("stage.card.playbills").exists)
        attach("ipad-landscape-stage")
        tap("stage.card.trunk")
        XCTAssertTrue(waitHittable("trunk.buy.lanternOil").exists)
        attach("ipad-landscape-trunk")
        back()
        tap("stage.raiseCurtain")
        tap("game.begin")
        XCTAssertTrue(waitHittable("game.pause").exists)
        attach("ipad-landscape-show")
    }

    // MARK: - Screenshot tour (site and review)

    func testTour() throws {
        launch(["--autopilot", "--invincible"])
        XCTAssertTrue(element("stage.screen").waitForExistence(timeout: 10))
        sleep(1)
        attach("01-stage")
        tap("stage.card.wardrobe"); sleep(1); attach("02-wardrobe"); back()
        tap("stage.card.trunk"); sleep(1); attach("03-trunk"); back()
        tap("stage.card.acts"); sleep(1); attach("04-acts"); back()
        tap("stage.guide"); sleep(1); attach("05-guide")
        for _ in 1..<5 { tap("guide.next") }
        sleep(1)
        attach("06-guide-chord")
        back()
        tap("stage.raiseCurtain")
        sleep(1)
        attach("07-playbill")
        tap("game.begin")
        waitHittable("game.pause")
        for (i, wait) in [8, 14, 18, 20].enumerated() {
            sleep(UInt32(wait))
            attach(String(format: "%02d-show", 8 + i))
        }
        waitHittable("game.pause").tap()
        attach("12-pause")
        tap("game.quit")
        tap("stage.card.playbills"); sleep(1); attach("13-playbills")
    }
}
