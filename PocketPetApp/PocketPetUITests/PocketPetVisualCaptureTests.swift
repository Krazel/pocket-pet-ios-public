import Foundation
import XCTest

final class PocketPetVisualCaptureTests: XCTestCase {
    private var app: XCUIApplication!
    private var currentScenario = ""
    private var currentLaunchArguments: [String] = []

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testF01WelcomeReady() {
        launch(scenario: "welcome-ready")

        let nameField = require(app.textFields["Pet name"])
        XCTAssertEqual(nameField.value as? String, "Pip")
        XCTAssertTrue(require(app.buttons["Hatch My Pet"]).isEnabled)
        capture("F01-welcome-ready-raw")
    }

    func testF02Hatching() {
        launch(scenario: "hatching")

        require(app.staticTexts["Hello, Pip!"])
        require(app.buttons["capture.hatching.ready"])
        capture("F02-hatching-raw")
    }

    func testF03ChildComfortable() {
        launchHabitat(scenario: "child-comfortable")
        capture("F03-child-comfortable-raw")
    }

    func testF04ChildNeedsCare() {
        launchHabitat(scenario: "child-needs-care")
        capture("F04-child-needs-care-raw")
    }

    func testF05ChildSleeping() {
        launchHabitat(scenario: "child-sleeping")
        capture("F05-child-sleeping-raw")
    }

    func testF06ChildFeedResponse() {
        launchHabitat(scenario: "child-comfortable", settleScene: false)

        require(app.buttons["Feed"]).tap()
        requireLabel(
            "Pip is comfortable. Tasty, thank you!",
            on: require(app.buttons["habitat.scene"]),
            timeout: 4
        )
        settleAnimatedContent(for: 0.25, frame: "F06")
        capture("F06-child-feed-response-raw")
    }

    func testF07AdultEvolution() {
        launch(scenario: "adult-evolution")

        require(app.staticTexts["You grew up!"])
        require(app.buttons["capture.adultEvolution.ready"])
        capture("F07-adult-evolution-raw")
    }

    func testF08AdultComfortable() {
        launchHabitat(scenario: "adult-comfortable")
        capture("F08-adult-comfortable-raw")
    }

    func testF09AdultNeedsCare() {
        launchHabitat(scenario: "adult-needs-care")
        capture("F09-adult-needs-care-raw")
    }

    func testF10AdultSleeping() {
        launchHabitat(scenario: "adult-sleeping")
        capture("F10-adult-sleeping-raw")
    }

    func testF11SettingsMainOff() {
        launchSettings(scenario: "settings-off", reminderValue: "Off")
        capture("F11-settings-main-off-raw")
    }

    func testF12ReminderPrePermission() {
        launchSettings(scenario: "settings-off", reminderValue: "Off")

        tapSettingsRow("Reminders")
        require(app.staticTexts["A gentle reminder?"])
        require(app.buttons["Allow Reminders"])
        capture("F12-reminder-pre-permission-raw")
    }

    func testF13RemindersEnabled() {
        launchSettings(scenario: "settings-on", reminderValue: "On")

        tapSettingsRow("Reminders")
        require(app.staticTexts["Gentle reminders are on"])
        require(app.descendants(matching: .any)["settings.reminderTime"])
        capture("F13-reminders-enabled-raw")
    }

    func testF14RemindersDenied() {
        launchSettings(scenario: "settings-denied", reminderValue: "Off")

        tapSettingsRow("Reminders")
        require(app.staticTexts["Reminders are off"])
        require(app.buttons["Open iOS Settings"])
        capture("F14-reminders-denied-raw")
    }

    func testF15SupportDevelopment() {
        launchSettings(scenario: "settings-off", reminderValue: "Off")

        tapSettingsRow("Support development")
        require(app.staticTexts["Pocket Pet is fully playable without purchases."])
        require(app.buttons["Done"])
        capture("F15-support-development-raw")
    }

    func testF16Privacy() {
        launchSettings(scenario: "settings-off", reminderValue: "Off")

        tapSettingsRow("Privacy")
        require(app.staticTexts["Your pocket, your data."])
        require(app.buttons["Back"])
        capture("F16-privacy-raw")
    }

    func testF17SupportUnavailable() {
        launchSettings(scenario: "settings-off", reminderValue: "Off")

        tapSettingsRow("Support")
        require(app.staticTexts["Support isn't available yet"])
        require(app.buttons["Done"])
        capture("F17-support-unavailable-raw")
    }

    private func launch(scenario: String) {
        let application = XCUIApplication()
        application.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "--visual-state", scenario,
            "--visual-static",
        ]
        currentScenario = scenario
        currentLaunchArguments = application.launchArguments
        application.launch()
        app = application
    }

    private func launchHabitat(
        scenario: String,
        settleScene: Bool = true
    ) {
        launch(scenario: scenario)
        require(app.staticTexts["Pip's Habitat"])
        require(app.buttons["Feed"])
        let scene = require(app.buttons["habitat.scene"])
        let stage = require(app.descendants(matching: .any)["habitat.stage"])
        requireLabel(expectedSceneLabel(for: scenario), on: scene)
        XCTAssertEqual(stage.label, expectedStageLabel(for: scenario))
        if settleScene {
            settleAnimatedContent(for: 0.25, frame: scenario)
        }
    }

    private func launchSettings(scenario: String, reminderValue: String) {
        launch(scenario: scenario)
        let reminders = require(app.buttons["Reminders"])
        XCTAssertEqual(reminders.value as? String, reminderValue)
        require(app.buttons["Support development"])
        require(app.buttons["Privacy"])
        require(app.buttons["Support"])
    }

    private func tapSettingsRow(
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let row = require(app.buttons[label], file: file, line: line)
        if !row.isHittable {
            let scrollView = require(
                app.scrollViews.firstMatch,
                file: file,
                line: line
            )
            for _ in 0..<4 where !row.isHittable {
                scrollView.swipeUp()
            }
        }
        XCTAssertTrue(
            row.isHittable,
            "Settings row is not reachable: \(label)",
            file: file,
            line: line
        )
        row.tap()
    }

    @discardableResult
    private func require(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "Expected semantic element did not appear: \(element)",
            file: file,
            line: line
        )
        return element
    }

    private func requireLabel(
        _ label: String,
        on element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected label did not appear: \(label)",
            file: file,
            line: line
        )
    }

    private func expectedSceneLabel(for scenario: String) -> String {
        switch scenario {
        case "child-needs-care", "adult-needs-care":
            return "Pip could use care. Priority need: hunger. A little snack?"
        case "child-sleeping", "adult-sleeping":
            return "Pip is sleeping. Resting peacefully."
        default:
            return "Pip is comfortable. Lovely morning!"
        }
    }

    private func expectedStageLabel(for scenario: String) -> String {
        scenario.hasPrefix("adult-") ? "Pip, adult" : "Pip, child"
    }

    /// Static-capture SpriteKit and milestone fades take 0.2 seconds. Semantic
    /// waits alone cannot observe those render-only cues.
    private func settleAnimatedContent(for duration: TimeInterval, frame: String) {
        let settled = expectation(description: "Settle render-only animation for \(frame)")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            settled.fulfill()
        }
        wait(for: [settled], timeout: duration + 0.5)
    }

    private func capture(
        _ frame: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            app.state == .runningForeground,
            "The app must be foregrounded before capturing \(frame)",
            file: file,
            line: line
        )
        let screenshot = XCUIScreen.main.screenshot()
        let png = screenshot.pngRepresentation
        // Store the exact PNG bytes measured below so exported attachment size
        // and native dimensions can be cross-checked without re-encoding.
        let attachment = XCTAttachment(
            data: png,
            uniformTypeIdentifier: "public.png"
        )
        attachment.name = frame
        attachment.lifetime = .keepAlways
        add(attachment)

        let environment = ProcessInfo.processInfo.environment
        let metadata = [
            "frame=\(frame)",
            "scenario=\(currentScenario)",
            "candidateCommit=\(environment["POCKET_PET_CANDIDATE_COMMIT"] ?? "unknown")",
            "device=\(environment["SIMULATOR_DEVICE_NAME"] ?? "unknown")",
            "udid=\(environment["SIMULATOR_UDID"] ?? "unknown")",
            "runtime=\(environment["SIMULATOR_RUNTIME_VERSION"] ?? "unknown")",
            "orientation=portrait",
            "language=en",
            "locale=en_US",
            "appearance=light",
            "visualStatic=true",
            "fixtureClock=2025-01-01T00:00:00Z",
            "launchArguments=\(currentLaunchArguments.joined(separator: " "))",
            "nativePixels=\(pngDimension(png, offset: 16))x\(pngDimension(png, offset: 20))",
            "pngBytes=\(png.count)",
        ].joined(separator: "\n")
        let metadataAttachment = XCTAttachment(string: metadata)
        metadataAttachment.name = "\(frame)-metadata"
        metadataAttachment.lifetime = .keepAlways
        add(metadataAttachment)
    }

    private func pngDimension(_ data: Data, offset: Int) -> Int {
        guard data.count >= offset + 4 else { return 0 }
        return data[offset..<(offset + 4)].reduce(0) { value, byte in
            (value << 8) | Int(byte)
        }
    }
}

/// Runtime QA intentionally lives outside PocketPetVisualCaptureTests so the
/// immutable F01-F17 comparator continues to receive exactly 17 frame pairs.
enum PocketPetRuntimeQAScrollDirection {
    case up
    case down
}

class PocketPetRuntimeQATestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func launch(
        scenario: String,
        staticPresentation: Bool = true,
        extraArguments: [String] = []
    ) {
        let application = XCUIApplication()
        var arguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "--visual-state", scenario,
        ]
        if staticPresentation {
            arguments.append("--visual-static")
        }
        arguments.append(contentsOf: extraArguments)
        application.launchArguments = arguments
        application.launch()
        app = application
    }

    @discardableResult
    func require(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "Expected semantic element did not appear: \(element)",
            file: file,
            line: line
        )
        return element
    }

    func requireLabel(
        _ label: String,
        on element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected label did not appear: \(label)",
            file: file,
            line: line
        )
    }

    func makeHittable(
        _ element: XCUIElement,
        direction: PocketPetRuntimeQAScrollDirection = .up,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        require(element, file: file, line: line)
        for _ in 0..<8 where !element.isHittable {
            switch direction {
            case .down: app.swipeDown()
            case .up: app.swipeUp()
            }
        }
        XCTAssertTrue(
            element.isHittable,
            "Element is present but not reachable: \(element)",
            file: file,
            line: line
        )
    }

    func tapReachable(
        _ element: XCUIElement,
        direction: PocketPetRuntimeQAScrollDirection = .up,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        makeHittable(element, direction: direction, file: file, line: line)
        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [enabled], timeout: 4),
            .completed,
            "Element did not become enabled: \(element)",
            file: file,
            line: line
        )
        element.tap()
    }

    func attachScreen(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func attachHierarchy(_ name: String) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func settle(_ duration: TimeInterval = 0.4) {
        let settled = expectation(description: "Settle runtime QA presentation")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            settled.fulfill()
        }
        wait(for: [settled], timeout: duration + 0.5)
    }

    func assertStableScreen(
        _ name: String,
        delay: TimeInterval = 0.35,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let first = XCUIScreen.main.screenshot()
        settle(delay)
        let second = XCUIScreen.main.screenshot()
        XCTAssertEqual(
            first.pngRepresentation,
            second.pngRepresentation,
            "Reduced-motion presentation continued changing: \(name)",
            file: file,
            line: line
        )
        let firstAttachment = XCTAttachment(screenshot: first)
        firstAttachment.name = "\(name)-first"
        firstAttachment.lifetime = .keepAlways
        add(firstAttachment)
        let secondAttachment = XCTAttachment(screenshot: second)
        secondAttachment.name = "\(name)-second"
        secondAttachment.lifetime = .keepAlways
        add(secondAttachment)
    }

    func exerciseCareAction(_ title: String, response: String) {
        let action = require(app.buttons[title])
        tapReachable(action)
        let scene = require(app.buttons["habitat.scene"])
        makeHittable(scene, direction: .down)
        requireLabel(response, on: scene, timeout: 4)
    }
}

final class PocketPetDynamicTypeTests: PocketPetRuntimeQATestCase {
    func testD01WelcomeKeyboardValidationAndValidName() {
        launch(scenario: "welcome-empty")
        let field = require(app.textFields["Pet name"])
        field.tap()
        field.typeText("ThirteenCharsX")
        require(app.staticTexts["Name error: Use 12 characters or fewer."])
        XCTAssertFalse(require(app.buttons["Hatch My Pet"]).isEnabled)
        attachScreen("D01-welcome-invalid-AX5")

        app.terminate()
        launch(scenario: "welcome-empty")
        let validField = require(app.textFields["Pet name"])
        validField.tap()
        validField.typeText("TwelveChar12")
        XCTAssertTrue(require(app.buttons["Hatch My Pet"]).isEnabled)
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Name error:'")
        ).firstMatch.exists)
        attachScreen("D01-welcome-valid-AX5")
    }

    func testD02HatchingContinueReachable() {
        launch(scenario: "hatching")
        require(app.staticTexts["Hello, Pip!"])
        let button = require(app.buttons["Continue"])
        attachScreen("D02-hatching-top-AX5")
        makeHittable(button)
        attachScreen("D02-hatching-bottom-AX5")
        XCTAssertTrue(button.isEnabled)
    }

    func testD03AdultEvolutionContinueReachable() {
        launch(scenario: "adult-evolution")
        require(app.staticTexts["You grew up!"])
        let button = require(app.buttons["Continue"])
        attachScreen("D03-adult-evolution-top-AX5")
        makeHittable(button)
        attachScreen("D03-adult-evolution-bottom-AX5")
        XCTAssertTrue(button.isEnabled)
    }

    func testD04HomeCareCopyReflowsAndRemainsReachable() {
        launch(
            scenario: "child-comfortable",
            extraArguments: ["--runtime-qa-extended-reactions"]
        )
        require(app.staticTexts["Pip's Habitat"])
        attachScreen("D04-home-top-AX5")
        exerciseCareAction(
            "Feed",
            response: "Pip is comfortable. Tasty, thank you!"
        )
        attachScreen("D04-feed-response-AX5")
        exerciseCareAction(
            "Play",
            response: "Pip is comfortable. That was fun!"
        )
        attachScreen("D04-play-response-AX5")
        exerciseCareAction(
            "Rest",
            response: "Pip is sleeping. Cozy time."
        )
        attachScreen("D04-rest-response-AX5")
        exerciseCareAction(
            "Wake",
            response: "Pip is comfortable. Good morning!"
        )
        attachScreen("D04-wake-response-AX5")
        exerciseCareAction(
            "Clean",
            response: "Pip is comfortable. Fresh and comfy!"
        )
        attachScreen("D04-clean-response-AX5")
    }

    func testD05SettingsMainScrollReach() {
        launch(scenario: "settings-off")
        require(app.staticTexts["Settings"])
        attachScreen("D05-settings-top-AX5")
        makeHittable(require(app.buttons["Support"]))
        attachScreen("D05-settings-bottom-AX5")
    }

    func testD06ReminderPrePermissionSheetScrollReach() {
        launch(scenario: "settings-off")
        tapReachable(require(app.buttons["Reminders"]))
        require(app.staticTexts["A gentle reminder?"])
        attachScreen("D06-reminder-sheet-top-AX5")
        makeHittable(require(app.buttons["Not Now"]))
        attachScreen("D06-reminder-sheet-bottom-AX5")
    }

    func testD07ReminderTimePickerScrollReach() {
        launch(scenario: "settings-on")
        tapReachable(require(app.buttons["Reminders"]))
        require(app.staticTexts["Gentle reminders are on"])
        require(app.descendants(matching: .any)["settings.reminderTime"])
        attachScreen("D07-reminders-enabled-top-AX5")
        makeHittable(require(app.buttons["Turn Off Reminders"]))
        attachScreen("D07-reminders-enabled-bottom-AX5")
    }

    func testD08PermissionDeniedScrollReach() {
        launch(scenario: "settings-denied")
        tapReachable(require(app.buttons["Reminders"]))
        require(app.staticTexts["Reminders are off"])
        attachScreen("D08-reminders-denied-top-AX5")
        makeHittable(require(app.buttons["Not Now"]))
        attachScreen("D08-reminders-denied-bottom-AX5")
    }

    func testD09SupportDevelopmentScrollReach() {
        launch(scenario: "settings-off")
        tapReachable(require(app.buttons["Support development"]))
        require(app.staticTexts["Pocket Pet is fully playable without purchases."])
        attachScreen("D09-support-development-top-AX5")
        makeHittable(require(app.buttons["Done"]))
        attachScreen("D09-support-development-bottom-AX5")
    }

    func testD10PrivacyScrollReach() {
        launch(scenario: "settings-off")
        tapReachable(require(app.buttons["Privacy"]))
        require(app.staticTexts["Your pocket, your data."])
        attachScreen("D10-privacy-top-AX5")
        makeHittable(require(app.buttons["Done"]))
        attachScreen("D10-privacy-bottom-AX5")
    }
}

final class PocketPetSemanticAccessibilityTests: PocketPetRuntimeQATestCase {
    func testV01WelcomeValidationSemantics() {
        launch(scenario: "welcome-empty")
        let field = require(app.textFields["Pet name"])
        XCTAssertEqual(field.label, "Pet name")
        XCTAssertFalse(require(app.buttons["Hatch My Pet"]).isEnabled)
        field.tap()
        field.typeText("ThirteenCharsX")
        require(app.staticTexts["Name error: Use 12 characters or fewer."])
        attachHierarchy("V01-welcome-semantics")
    }

    func testV02HatchingSemanticsAndImmediateContinue() {
        launch(scenario: "hatching", staticPresentation: false)
        require(app.staticTexts["Hello, Pip!"])
        require(app.staticTexts["Your little friend is ready."])
        let button = require(app.buttons["Continue"])
        XCTAssertTrue(button.isEnabled)
        attachHierarchy("V02-hatching-semantics")
    }

    func testV03AdultEvolutionSemanticsAndImmediateContinue() {
        launch(scenario: "adult-evolution", staticPresentation: false)
        require(app.staticTexts["You grew up!"])
        require(app.staticTexts["Pip is an adult now."])
        let button = require(app.buttons["Continue"])
        XCTAssertTrue(button.isEnabled)
        attachHierarchy("V03-adult-evolution-semantics")
    }

    func testV04HomeNeedsSceneActionsAndResponses() {
        launch(
            scenario: "child-comfortable",
            extraArguments: ["--runtime-qa-extended-reactions"]
        )
        require(app.staticTexts["Pip's Habitat"])
        XCTAssertEqual(
            require(app.descendants(matching: .any)["habitat.stage"]).label,
            "Pip, child"
        )
        XCTAssertEqual(require(app.descendants(matching: .any)["Hunger"]).value as? String,
                       "80 percent satisfied, comfortable")
        XCTAssertEqual(require(app.descendants(matching: .any)["Happiness"]).value as? String,
                       "80 percent, comfortable")
        XCTAssertEqual(require(app.descendants(matching: .any)["Energy"]).value as? String,
                       "80 percent, comfortable")
        XCTAssertEqual(require(app.descendants(matching: .any)["Cleanliness"]).value as? String,
                       "80 percent, comfortable")
        requireLabel(
            "Pip is comfortable. Lovely morning!",
            on: require(app.buttons["habitat.scene"])
        )
        for label in ["Feed", "Play", "Rest", "Clean", "Settings"] {
            require(app.buttons[label])
        }
        exerciseCareAction("Feed", response: "Pip is comfortable. Tasty, thank you!")
        exerciseCareAction("Play", response: "Pip is comfortable. That was fun!")
        exerciseCareAction("Rest", response: "Pip is sleeping. Cozy time.")
        exerciseCareAction("Wake", response: "Pip is comfortable. Good morning!")
        exerciseCareAction("Clean", response: "Pip is comfortable. Fresh and comfy!")
        attachHierarchy("V04-home-semantics-and-responses")
    }

    func testV05ReminderSheetDismissalReturnsToRow() {
        launch(scenario: "settings-off")
        tapReachable(require(app.buttons["Reminders"]))
        require(app.staticTexts["A gentle reminder?"])
        tapReachable(require(app.buttons["Not Now"]))
        require(app.buttons["Reminders"])
        attachHierarchy("V05-reminder-dismissal-semantics")
    }

    func testV06EnabledReminderTimeSemantics() {
        launch(scenario: "settings-on")
        tapReachable(require(app.buttons["Reminders"]))
        require(app.staticTexts["Gentle reminders are on"])
        let picker = require(app.descendants(matching: .any)["settings.reminderTime"])
        XCTAssertFalse(picker.label.isEmpty)
        attachHierarchy("V06-reminder-time-semantics")
    }

    func testV07PermissionDeniedHasExplicitSettingsAction() {
        launch(scenario: "settings-denied")
        tapReachable(require(app.buttons["Reminders"]))
        require(app.descendants(matching: .any)["Permission denied"])
        require(app.buttons["Open iOS Settings"])
        attachHierarchy("V07-denied-semantics")
    }

    func testV08AboutSheetsDismissAndReturnToRows() {
        launch(scenario: "settings-off")
        tapReachable(require(app.buttons["Support development"]))
        tapReachable(require(app.buttons["Done"]))
        require(app.buttons["Support development"])

        tapReachable(require(app.buttons["Privacy"]))
        tapReachable(require(app.buttons["Done"]))
        require(app.buttons["Privacy"])

        tapReachable(require(app.buttons["Support"]))
        require(app.staticTexts["Support isn't available yet"])
        tapReachable(require(app.buttons["Done"]))
        require(app.buttons["Support"])
        attachHierarchy("V08-about-dismissal-semantics")
    }
}

final class PocketPetReduceMotionTests: PocketPetRuntimeQATestCase {
    func testR01SystemReducedHatchingSettlesAndContinueIsImmediate() {
        launch(
            scenario: "hatching",
            staticPresentation: false,
            extraArguments: ["--runtime-qa-system-reduce-motion"]
        )
        XCTAssertTrue(require(app.buttons["Continue"]).isEnabled)
        require(app.buttons["capture.hatching.ready"])
        assertStableScreen("R01-system-reduced-hatching")
    }

    func testR02SystemReducedAdultEvolutionSettlesAndContinueIsImmediate() {
        launch(
            scenario: "adult-evolution",
            staticPresentation: false,
            extraArguments: ["--runtime-qa-system-reduce-motion"]
        )
        XCTAssertTrue(require(app.buttons["Continue"]).isEnabled)
        require(app.buttons["capture.adultEvolution.ready"])
        assertStableScreen("R02-system-reduced-adult-evolution")
    }

    func testR03LocalReducedHomeAndAllCareCuesRemainStatic() {
        launch(
            scenario: "child-comfortable",
            staticPresentation: false,
            extraArguments: [
                "--runtime-qa-local-reduce-motion",
                "--runtime-qa-extended-reactions",
            ]
        )
        exerciseCareAction("Feed", response: "Pip is comfortable. Tasty, thank you!")
        assertStableScreen("R03-feed")
        exerciseCareAction("Play", response: "Pip is comfortable. That was fun!")
        assertStableScreen("R03-play")
        exerciseCareAction("Rest", response: "Pip is sleeping. Cozy time.")
        assertStableScreen("R03-rest")
        exerciseCareAction("Wake", response: "Pip is comfortable. Good morning!")
        assertStableScreen("R03-wake")
        exerciseCareAction("Clean", response: "Pip is comfortable. Fresh and comfy!")
        assertStableScreen("R03-clean")
    }

    func testR04EffectiveReducedSettingsNavigationAndSheetsSettle() {
        launch(
            scenario: "settings-off",
            staticPresentation: false,
            extraArguments: ["--runtime-qa-local-reduce-motion"]
        )
        tapReachable(require(app.buttons["Privacy"]))
        require(app.staticTexts["Your pocket, your data."])
        assertStableScreen("R04-settings-navigation")
        tapReachable(require(app.buttons["Done"]))
        tapReachable(require(app.buttons["Support development"]))
        require(app.staticTexts["Pocket Pet is fully playable without purchases."])
        assertStableScreen("R04-settings-sheet")
    }
}

/// These sequences are captured by the simulator video in the runtime QA job.
/// They retain real timing while the R-series independently proves the static
/// reduced-motion equivalents.
final class PocketPetNormalMotionTimingTests: PocketPetRuntimeQATestCase {
    func testN01NormalHatchingMotionAndImmediateContinue() {
        launch(scenario: "hatching", staticPresentation: false)
        XCTAssertTrue(require(app.buttons["Continue"]).isEnabled)
        require(app.buttons["capture.hatching.ready"])
        settle(0.8)
    }

    func testN02NormalAdultEvolutionMotionAndImmediateContinue() {
        launch(scenario: "adult-evolution", staticPresentation: false)
        XCTAssertTrue(require(app.buttons["Continue"]).isEnabled)
        require(app.buttons["capture.adultEvolution.ready"])
        settle(0.8)
    }

    func testN03NormalHomeCareMotionReturnsToRest() {
        launch(scenario: "child-comfortable", staticPresentation: false)
        exerciseCareAction("Feed", response: "Pip is comfortable. Tasty, thank you!")
        exerciseCareAction("Play", response: "Pip is comfortable. That was fun!")
        exerciseCareAction("Rest", response: "Pip is sleeping. Cozy time.")
        exerciseCareAction("Wake", response: "Pip is comfortable. Good morning!")
        exerciseCareAction("Clean", response: "Pip is comfortable. Fresh and comfy!")
        settle(1.2)
        requireLabel(
            "Pip is comfortable. Lovely morning!",
            on: require(app.buttons["habitat.scene"]),
            timeout: 3
        )
    }
}
