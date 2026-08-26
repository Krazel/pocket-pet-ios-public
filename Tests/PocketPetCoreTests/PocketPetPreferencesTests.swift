import Foundation
import XCTest
@testable import PocketPetCore

final class PocketPetPreferencesTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: temporaryDirectory.path) {
            try FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
    }

    func testDefaultsMatchProductSystem() {
        let preferences = PocketPetPreferences.defaults

        XCTAssertTrue(preferences.soundEnabled)
        XCTAssertFalse(preferences.reduceMotionEnabled)
        XCTAssertFalse(preferences.remindersEnabled)
        XCTAssertEqual(preferences.reminderTime, .defaultCheckIn)
        XCTAssertEqual(preferences.reminderTime.hour, 19)
        XCTAssertEqual(preferences.reminderTime.minute, 0)
        XCTAssertFalse(preferences.reminderInvitationShown)
        XCTAssertEqual(preferences.foregroundSessionCount, 0)
        XCTAssertNil(preferences.localNotificationIdentifier)
        XCTAssertNil(preferences.lastReminderFireDate)
    }

    func testReminderLocalTimeRejectsInvalidComponents() {
        XCTAssertThrowsError(try ReminderLocalTime(hour: -1, minute: 0)) { error in
            XCTAssertEqual(error as? ReminderLocalTimeError, .invalidHour)
        }
        XCTAssertThrowsError(try ReminderLocalTime(hour: 24, minute: 0)) { error in
            XCTAssertEqual(error as? ReminderLocalTimeError, .invalidHour)
        }
        XCTAssertThrowsError(try ReminderLocalTime(hour: 19, minute: 60)) { error in
            XCTAssertEqual(error as? ReminderLocalTimeError, .invalidMinute)
        }
    }

    func testPreferencesNormalizeCountersAndEmptyIdentifier() {
        let preferences = PocketPetPreferences(
            foregroundSessionCount: -5,
            localNotificationIdentifier: ""
        )

        XCTAssertEqual(preferences.foregroundSessionCount, 0)
        XCTAssertNil(preferences.localNotificationIdentifier)
    }

    func testReminderFireDateCommandCanSetAndClearLedger() {
        let fireDate = Date(timeIntervalSince1970: 1_790_001_600)
        var preferences = PocketPetPreferences.defaults

        preferences.apply(.setLastReminderFireDate(fireDate))
        XCTAssertEqual(preferences.lastReminderFireDate, fireDate)

        preferences.apply(.setLastReminderFireDate(nil))
        XCTAssertNil(preferences.lastReminderFireDate)
    }

    func testAtomicFileStoreRoundTripsEveryPreference() throws {
        let store = makeStore()
        let fireDate = Date(timeIntervalSince1970: 1_790_001_600)
        let preferences = PocketPetPreferences(
            soundEnabled: false,
            reduceMotionEnabled: true,
            remindersEnabled: true,
            reminderTime: try ReminderLocalTime(hour: 8, minute: 45),
            reminderInvitationShown: true,
            foregroundSessionCount: 4,
            localNotificationIdentifier: "pocket-pet-daily",
            lastReminderFireDate: fireDate
        )

        try store.save(preferences)

        XCTAssertEqual(try store.load(), preferences)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    func testMissingReminderFireDateDecodesBackwardCompatibly() throws {
        let legacyJSON = """
        {
          "schemaVersion": 1,
          "soundEnabled": true,
          "reduceMotionEnabled": false,
          "remindersEnabled": false,
          "reminderTime": { "hour": 19, "minute": 0 },
          "reminderInvitationShown": false,
          "foregroundSessionCount": 1
        }
        """

        let preferences = try JSONDecoder().decode(
            PocketPetPreferences.self,
            from: Data(legacyJSON.utf8)
        )

        XCTAssertNil(preferences.lastReminderFireDate)
        XCTAssertEqual(preferences.reminderTime, .defaultCheckIn)
    }

    func testMissingPreferencesFileLoadsAsNil() throws {
        XCTAssertNil(try makeStore().load())
    }

    func testCorruptPreferencesDoNotSilentlyBecomeDefaults() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(to: store.fileURL, options: .atomic)

        XCTAssertThrowsError(try store.load())
    }

    func testFuturePreferencesSchemaIsRejectedOnLoad() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        let future = PocketPetPreferences(
            schemaVersion: PocketPetPreferences.currentSchemaVersion + 1
        )
        let encoder = JSONEncoder()
        try encoder.encode(future).write(to: store.fileURL, options: .atomic)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(
                error as? PocketPetPreferencesPersistenceError,
                .unsupportedSchema(
                    found: PocketPetPreferences.currentSchemaVersion + 1,
                    latest: PocketPetPreferences.currentSchemaVersion
                )
            )
        }
    }

    func testFuturePreferencesSchemaIsRejectedOnSave() throws {
        let future = PocketPetPreferences(
            schemaVersion: PocketPetPreferences.currentSchemaVersion + 1
        )

        XCTAssertThrowsError(try makeStore().save(future)) { error in
            guard let persistenceError = error as? PocketPetPreferencesPersistenceError,
                 case .unsupportedSchema = persistenceError else {
                return XCTFail("Expected future-schema error")
            }
        }
    }

    private func makeStore() -> JSONFilePocketPetPreferencesStore {
        JSONFilePocketPetPreferencesStore(
            fileURL: temporaryDirectory.appendingPathComponent("preferences.json")
        )
    }
}
