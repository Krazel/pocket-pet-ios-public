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
            timeout: 0.7
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
