import Foundation
import XCTest
@testable import PocketPetCore

private enum CoordinatorTestError: Error {
    case forcedLoadFailure
    case forcedSaveFailure
}

private final class CoordinatorOperationLog {
    var entries: [String] = []
}

private final class RecordingPetStore: PetStatePersisting {
    var state: PetState?
    var loadError: Error?
    var saveAttempts = 0
    var failOnSaveAttempt: Int?
    let log: CoordinatorOperationLog

    init(state: PetState?, log: CoordinatorOperationLog) {
        self.state = state
        self.log = log
    }

    func load() throws -> PetState? {
        log.entries.append("pet.load")
        if let loadError { throw loadError }
        return state
    }

    func save(_ state: PetState) throws {
        saveAttempts += 1
        log.entries.append("pet.save")
        if saveAttempts == failOnSaveAttempt {
            throw CoordinatorTestError.forcedSaveFailure
        }
        self.state = state
    }

    func delete() throws {
        state = nil
    }
}

private final class RecordingPreferencesStore: PocketPetPreferencesPersisting {
    var preferences: PocketPetPreferences?
    var saveAttempts = 0
    var failOnSaveAttempt: Int?
    let log: CoordinatorOperationLog

    init(
        preferences: PocketPetPreferences?,
        log: CoordinatorOperationLog
    ) {
        self.preferences = preferences
        self.log = log
    }

    func load() throws -> PocketPetPreferences? {
        log.entries.append("preferences.load")
        return preferences
    }

    func save(_ preferences: PocketPetPreferences) throws {
        saveAttempts += 1
        log.entries.append("preferences.save")
        if saveAttempts == failOnSaveAttempt {
            throw CoordinatorTestError.forcedSaveFailure
        }
        self.preferences = preferences
    }
}

private final class LockedDateBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(_ value: Date) {
        self.value = value
    }

    func read() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(_ value: Date) {
        lock.lock()
        self.value = value
        lock.unlock()
    }
}

private struct MutableCoordinatorClock: PetClock {
    let box: LockedDateBox
    var now: Date { box.read() }
}

final class PocketPetStateCoordinatorTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testStartLoadsReconcilesSavesThenReturnsSnapshot() async throws {
        let log = CoordinatorOperationLog()
        let child = makeChild(lastReconciledAt: start)
        let petStore = RecordingPetStore(state: child, log: log)
        let preferencesStore = RecordingPreferencesStore(
            preferences: .defaults,
            log: log
        )
        let owner = makeOwner(
            at: start.addingTimeInterval(3_600),
            petStore: petStore,
            preferencesStore: preferencesStore
        )

        let snapshot = try await owner.startForegroundSession()

        XCTAssertEqual(
            log.entries,
            ["preferences.load", "pet.load", "pet.save", "preferences.save"]
        )
        XCTAssertEqual(snapshot.pet, petStore.state)
        XCTAssertEqual(snapshot.pet?.needs.hunger, 21.25)
        XCTAssertEqual(snapshot.preferences.foregroundSessionCount, 1)
        XCTAssertEqual(snapshot.destination, .home)
    }

    func testStartPersistsMissingPreferenceDefaultsBeforePresenting() async throws {
        let log = CoordinatorOperationLog()
        let petStore = RecordingPetStore(state: nil, log: log)
        let preferencesStore = RecordingPreferencesStore(
            preferences: nil,
            log: log
        )
        let owner = makeOwner(
            at: start,
            petStore: petStore,
            preferencesStore: preferencesStore
        )

        let snapshot = try await owner.startForegroundSession()

        XCTAssertEqual(
            log.entries,
            [
                "preferences.load",
                "preferences.save",
                "pet.load",
                "preferences.save",
            ]
        )
        XCTAssertEqual(snapshot.preferences.foregroundSessionCount, 1)
        XCTAssertEqual(preferencesStore.preferences, snapshot.preferences)
        XCTAssertEqual(snapshot.destination, .onboarding)
    }

    func testForegroundSessionCountsOnceUntilEnded() async throws {
        let context = makeContext(state: makeChild())
        let owner = context.owner

        let first = try await owner.startForegroundSession()
        let duplicate = try await owner.startForegroundSession()
        _ = try await owner.endForegroundSession()
        let second = try await owner.startForegroundSession()

        XCTAssertEqual(first.preferences.foregroundSessionCount, 1)
        XCTAssertEqual(duplicate.preferences.foregroundSessionCount, 1)
        XCTAssertEqual(second.preferences.foregroundSessionCount, 2)
    }

    func testCreateEggAndHatchReturnOnlyPersistedResults() async throws {
        let context = makeContext(state: nil)
        let owner = context.owner
        _ = try await owner.startForegroundSession()

        let egg = try await owner.createEgg(
            named: "Pip",
            id: UUID(uuidString: "D89B1260-B142-4B26-BEDC-59BC75171967")!
        )
        XCTAssertEqual(egg.event, .eggCreated)
        XCTAssertEqual(egg.snapshot.destination, .onboarding)
        XCTAssertEqual(context.petStore.state, egg.snapshot.pet)

        let hatch = try await owner.hatch()
        XCTAssertEqual(hatch.event, .hatched)
        XCTAssertEqual(hatch.snapshot.destination, .milestone(.hatching))
        XCTAssertEqual(context.petStore.state, hatch.snapshot.pet)
        XCTAssertEqual(context.petStore.state?.stage, .child)
    }

    func testPendingHatchingMilestoneBlocksCareUntilAcknowledged() async throws {
        let child = makeChild(unseenMilestones: [.hatching])
        let context = makeContext(state: child)
        let owner = context.owner

        let started = try await owner.startForegroundSession()
        XCTAssertEqual(started.destination, .milestone(.hatching))

        do {
            _ = try await owner.performCareAction(.feed)
            XCTFail("Care should be blocked by the milestone")
        } catch {
            XCTAssertEqual(
                error as? PocketPetCoordinatorError,
                .milestonePending(.hatching)
            )
        }
        XCTAssertEqual(context.petStore.state?.completedCareActions, 0)

        let acknowledged = try await owner.acknowledgeMilestone(.hatching)
        XCTAssertEqual(acknowledged.snapshot.destination, .home)
        let care = try await owner.performCareAction(.feed)
        XCTAssertEqual(context.petStore.state, care.snapshot.pet)
        XCTAssertEqual(context.petStore.state?.completedCareActions, 1)
    }

    func testHatchingPrecedesAdultWhenBothMilestonesAreRecovered() async throws {
        let adult = makeAdult(
            unseenMilestones: [.adultEvolution, .hatching]
        )
        let context = makeContext(state: adult)
        let owner = context.owner

        let started = try await owner.startForegroundSession()
        XCTAssertEqual(started.destination, .milestone(.hatching))

        let next = try await owner.acknowledgeMilestone(.hatching)
        XCTAssertEqual(next.snapshot.destination, .milestone(.adultEvolution))
    }

    func testReconciliationThatQueuesAdultMilestoneBlocksCare() async throws {
        let clockBox = LockedDateBox(start.addingTimeInterval(71 * 3_600))
        let log = CoordinatorOperationLog()
        let child = makeChild(
            lastReconciledAt: start.addingTimeInterval(71 * 3_600),
            childAgeSeconds: 71 * 3_600,
            careMarks: [
                start,
                start.addingTimeInterval(18 * 3_600),
                start.addingTimeInterval(36 * 3_600),
            ]
        )
        let petStore = RecordingPetStore(state: child, log: log)
        let preferencesStore = RecordingPreferencesStore(
            preferences: .defaults,
            log: log
        )
        let owner = PocketPetStateCoordinator(
            engine: PetEngine(clock: MutableCoordinatorClock(box: clockBox)),
            petStore: petStore,
            preferencesStore: preferencesStore
        )
        _ = try await owner.startForegroundSession()
        clockBox.set(start.addingTimeInterval(72 * 3_600))

        do {
            _ = try await owner.performCareAction(.clean)
            XCTFail("Care should be blocked by newly queued evolution")
        } catch {
            XCTAssertEqual(
                error as? PocketPetCoordinatorError,
                .milestonePending(.adultEvolution)
            )
        }

        XCTAssertEqual(petStore.state?.stage, .adult)
        XCTAssertEqual(petStore.state?.completedCareActions, 0)
        XCTAssertTrue(
            petStore.state?.unseenMilestones.contains(.adultEvolution) == true
        )
    }

    func testCareResultReportsMarkAndEvolutionAfterSave() async throws {
        let checkpoint = start.addingTimeInterval(72 * 3_600)
        let child = makeChild(
            lastReconciledAt: checkpoint,
            childAgeSeconds: 72 * 3_600,
            careMarks: [
                start.addingTimeInterval(36 * 3_600),
                start.addingTimeInterval(54 * 3_600),
            ]
        )
        let context = makeContext(state: child, date: checkpoint)
        let owner = context.owner
        _ = try await owner.startForegroundSession()

        let result = try await owner.performCareAction(.feed)

        XCTAssertEqual(
            result.event,
            .carePerformed(
                action: .feed,
                earnedCareMark: true,
                evolvedToAdult: true
            )
        )
        XCTAssertEqual(context.petStore.state, result.snapshot.pet)
        XCTAssertEqual(result.snapshot.destination, .milestone(.adultEvolution))
    }

    func testFailedActionSaveDoesNotExposeOrKeepUncommittedAction() async throws {
        let context = makeContext(state: makeChild())
        let owner = context.owner
        _ = try await owner.startForegroundSession()
        context.petStore.failOnSaveAttempt = context.petStore.saveAttempts + 2

        do {
            _ = try await owner.performCareAction(.feed)
            XCTFail("Expected the action save to fail")
        } catch {
            XCTAssertTrue(error is CoordinatorTestError)
        }

        XCTAssertEqual(context.petStore.state?.completedCareActions, 0)
        let recovered = try await owner.refresh()
        XCTAssertEqual(recovered.pet?.completedCareActions, 0)
    }

    func testPreferenceCommandsArePersistedBeforeSnapshotReturns() async throws {
        let context = makeContext(state: makeChild())
        let owner = context.owner
        _ = try await owner.startForegroundSession()

        _ = try await owner.updatePreferences(.setSoundEnabled(false))
        _ = try await owner.updatePreferences(.setReduceMotionEnabled(true))
        _ = try await owner.updatePreferences(.setRemindersEnabled(true))
        _ = try await owner.updatePreferences(
            .setReminderTime(try ReminderLocalTime(hour: 8, minute: 30))
        )
        _ = try await owner.updatePreferences(.markReminderInvitationShown)
        let result = try await owner.updatePreferences(
            .setLocalNotificationIdentifier("daily-check-in")
        )

        XCTAssertEqual(context.preferencesStore.preferences, result.preferences)
        XCTAssertFalse(result.preferences.soundEnabled)
        XCTAssertTrue(result.preferences.reduceMotionEnabled)
        XCTAssertTrue(result.preferences.remindersEnabled)
        XCTAssertEqual(result.preferences.reminderTime.hour, 8)
        XCTAssertEqual(result.preferences.reminderTime.minute, 30)
        XCTAssertTrue(result.preferences.reminderInvitationShown)
        XCTAssertEqual(
            result.preferences.localNotificationIdentifier,
            "daily-check-in"
        )
    }

    func testReminderInvitationEligibilityRequiresValueAndTwoSessions() async throws {
        let child = makeChild(completedCareActions: 3)
        let preferences = PocketPetPreferences(foregroundSessionCount: 1)
        let context = makeContext(state: child, preferences: preferences)
        let owner = context.owner

        let eligible = try await owner.startForegroundSession()
        XCTAssertTrue(eligible.reminderInvitationIsEligible)

        let shown = try await owner.updatePreferences(
            .markReminderInvitationShown
        )
        XCTAssertFalse(shown.reminderInvitationIsEligible)
    }

    func testReminderInvitationWaitsUntilMilestonesAreAcknowledged() async throws {
        let child = makeChild(
            completedCareActions: 3,
            unseenMilestones: [.hatching]
        )
        let preferences = PocketPetPreferences(foregroundSessionCount: 1)
        let context = makeContext(state: child, preferences: preferences)

        let milestone = try await context.owner.startForegroundSession()
        XCTAssertEqual(milestone.destination, .milestone(.hatching))
        XCTAssertFalse(milestone.reminderInvitationIsEligible)

        let home = try await context.owner.acknowledgeMilestone(.hatching)
        XCTAssertEqual(home.snapshot.destination, .home)
        XCTAssertTrue(home.snapshot.reminderInvitationIsEligible)
    }

    func testEndForegroundSessionReconcilesAndAllowsNextSessionCount() async throws {
        let clockBox = LockedDateBox(start)
        let context = makeContext(state: makeChild(), clockBox: clockBox)
        let owner = context.owner
        _ = try await owner.startForegroundSession()
        clockBox.set(start.addingTimeInterval(3_600))

        let ended = try await owner.endForegroundSession()
        XCTAssertEqual(ended.pet?.needs.hunger, 21.25)
        XCTAssertEqual(context.petStore.state, ended.pet)

        let next = try await owner.startForegroundSession()
        XCTAssertEqual(next.preferences.foregroundSessionCount, 2)
    }

    func testPreferenceSaveFailureDoesNotAdvanceInMemoryPreferences() async throws {
        let context = makeContext(state: makeChild())
        let owner = context.owner
        _ = try await owner.startForegroundSession()
        context.preferencesStore.failOnSaveAttempt =
            context.preferencesStore.saveAttempts + 1

        do {
            _ = try await owner.updatePreferences(.setSoundEnabled(false))
            XCTFail("Expected preference save failure")
        } catch {
            XCTAssertTrue(error is CoordinatorTestError)
        }

        let snapshot = try await owner.refresh()
        XCTAssertTrue(snapshot.preferences.soundEnabled)
        XCTAssertTrue(context.preferencesStore.preferences?.soundEnabled == true)
    }

    func testLoadFailurePropagatesInsteadOfReturningOnboarding() async throws {
        let context = makeContext(state: nil)
        context.petStore.loadError = CoordinatorTestError.forcedLoadFailure

        do {
            _ = try await context.owner.startForegroundSession()
            XCTFail("Expected load failure")
        } catch {
            XCTAssertTrue(error is CoordinatorTestError)
        }
    }

    func testCreatingSecondPetIsRejectedWithoutChangingSavedPet() async throws {
        let child = makeChild()
        let context = makeContext(state: child)
        _ = try await context.owner.startForegroundSession()

        do {
            _ = try await context.owner.createEgg(named: "Other")
            XCTFail("Expected existing-pet error")
        } catch {
            XCTAssertEqual(
                error as? PocketPetCoordinatorError,
                .petAlreadyExists
            )
        }
        XCTAssertEqual(context.petStore.state?.id, child.id)
    }

    private func makeOwner(
        at date: Date,
        petStore: RecordingPetStore,
        preferencesStore: RecordingPreferencesStore
    ) -> PocketPetStateCoordinator {
        PocketPetStateCoordinator(
            engine: PetEngine(clock: MutableCoordinatorClock(box: LockedDateBox(date))),
            petStore: petStore,
            preferencesStore: preferencesStore
        )
    }

    private func makeContext(
        state: PetState?,
        preferences: PocketPetPreferences = .defaults,
        date: Date? = nil,
        clockBox: LockedDateBox? = nil
    ) -> (
        owner: PocketPetStateCoordinator,
        petStore: RecordingPetStore,
        preferencesStore: RecordingPreferencesStore
    ) {
        let log = CoordinatorOperationLog()
        let petStore = RecordingPetStore(state: state, log: log)
        let preferencesStore = RecordingPreferencesStore(
            preferences: preferences,
            log: log
        )
        let box = clockBox ?? LockedDateBox(date ?? start)
        let owner = PocketPetStateCoordinator(
            engine: PetEngine(clock: MutableCoordinatorClock(box: box)),
            petStore: petStore,
            preferencesStore: preferencesStore
        )
        return (owner, petStore, preferencesStore)
    }

    private func makeChild(
        lastReconciledAt: Date? = nil,
        childAgeSeconds: TimeInterval = 0,
        careMarks: [Date] = [],
        completedCareActions: Int = 0,
        unseenMilestones: [PetMilestone] = []
    ) -> PetState {
        PetState(
            id: UUID(uuidString: "D89B1260-B142-4B26-BEDC-59BC75171967")!,
            name: "Pip",
            createdAt: start,
            lastReconciledAt: lastReconciledAt,
            stage: .child,
            hatchedAt: start,
            childAgeSeconds: childAgeSeconds,
            needs: PetNeeds(hunger: 20, happiness: 80, energy: 80, cleanliness: 80),
            careMarks: careMarks,
            completedCareActions: completedCareActions,
            unseenMilestones: unseenMilestones
        )
    }

    private func makeAdult(
        unseenMilestones: [PetMilestone]
    ) -> PetState {
        PetState(
            name: "Pip",
            createdAt: start,
            lastReconciledAt: start.addingTimeInterval(72 * 3_600),
            stage: .adult,
            hatchedAt: start,
            childAgeSeconds: 72 * 3_600,
            needs: PetNeeds(hunger: 20, happiness: 80, energy: 80, cleanliness: 80),
            careMarks: [
                start,
                start.addingTimeInterval(18 * 3_600),
                start.addingTimeInterval(36 * 3_600),
            ],
            unseenMilestones: unseenMilestones
        )
    }
}
