import Foundation
import XCTest
@testable import PocketPetCore

final class PocketPetGameCoordinatorTests: XCTestCase {
    func testSnapshotRequiresStart() async {
        let coordinator = PocketPetGameCoordinator(
            store: GameCoordinatorTestStore(state: makeGame())
        )

        do {
            _ = try await coordinator.snapshot()
            XCTFail("Expected notStarted")
        } catch {
            XCTAssertEqual(
                error as? PocketPetGameCoordinatorError,
                .notStarted
            )
        }
    }

    func testStartReconcilesAndSavesBeforeReturning() async throws {
        let initial = makeGame()
        let store = GameCoordinatorTestStore(state: initial)
        let now = initial.pet.lastReconciledAt.addingTimeInterval(3_600)
        let coordinator = PocketPetGameCoordinator(
            store: store,
            petEngine: PetEngine(clock: GameCoordinatorTestClock(now: now))
        )

        let started = try await coordinator.start()

        XCTAssertEqual(started.pet.lastReconciledAt, now)
        XCTAssertEqual(store.state, started)
        XCTAssertEqual(store.saveCount, 1)
    }

    func testConsumeCommitsExpandedStateBeforeReturning() async throws {
        let initial = makeGame()
        let store = GameCoordinatorTestStore(state: initial)
        let coordinator = PocketPetGameCoordinator(
            store: store,
            petEngine: PetEngine(
                clock: GameCoordinatorTestClock(
                    now: initial.pet.lastReconciledAt
                )
            )
        )
        _ = try await coordinator.start()

        let consumed = try await coordinator.consume(
            itemID: .dewberry,
            commandID: UUID()
        )

        XCTAssertEqual(consumed.inventory.quantity(of: .dewberry), 2)
        XCTAssertEqual(store.state, consumed)
        XCTAssertEqual(store.saveCount, 1)
    }

    func testFailedSaveDoesNotReplaceCoordinatorSnapshot() async throws {
        let initial = makeGame()
        let store = GameCoordinatorTestStore(state: initial)
        let coordinator = PocketPetGameCoordinator(
            store: store,
            petEngine: PetEngine(
                clock: GameCoordinatorTestClock(
                    now: initial.pet.lastReconciledAt
                )
            )
        )
        _ = try await coordinator.start()
        store.shouldFailSave = true

        do {
            _ = try await coordinator.performCare(.clean, commandID: UUID())
            XCTFail("Expected save failure")
        } catch {
            XCTAssertEqual(error as? GameCoordinatorTestError, .saveFailed)
        }

        let snapshot = try await coordinator.snapshot()
        XCTAssertEqual(snapshot, initial)
        XCTAssertEqual(store.state, initial)
    }

    func testReplayedCommandDoesNotWriteAgain() async throws {
        let initial = makeGame()
        let store = GameCoordinatorTestStore(state: initial)
        let coordinator = PocketPetGameCoordinator(
            store: store,
            petEngine: PetEngine(
                clock: GameCoordinatorTestClock(
                    now: initial.pet.lastReconciledAt
                )
            )
        )
        _ = try await coordinator.start()
        let commandID = UUID()
        let first = try await coordinator.consume(
            itemID: .dewberry,
            commandID: commandID
        )
        let replayed = try await coordinator.consume(
            itemID: .dewberry,
            commandID: commandID
        )

        XCTAssertEqual(replayed, first)
        XCTAssertEqual(store.saveCount, 1)
    }

    private func makeGame() -> PocketPetGameState {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let pet = PetState(
            name: "Pip",
            createdAt: createdAt,
            lastReconciledAt: createdAt,
            stage: .child,
            hatchedAt: createdAt,
            needs: PetNeeds(
                hunger: 20,
                happiness: 80,
                energy: 80,
                cleanliness: 80
            )
        )
        return PocketPetGameState(migrating: pet)
    }
}

private enum GameCoordinatorTestError: Error, Equatable {
    case saveFailed
}

private final class GameCoordinatorTestStore: PocketPetGameStatePersisting {
    var state: PocketPetGameState?
    var shouldFailSave = false
    private(set) var saveCount = 0

    init(state: PocketPetGameState?) {
        self.state = state
    }

    func load() throws -> PocketPetGameState? {
        state
    }

    func save(_ state: PocketPetGameState) throws {
        guard !shouldFailSave else { throw GameCoordinatorTestError.saveFailed }
        self.state = state
        saveCount += 1
    }

    func delete() throws {
        state = nil
    }
}

private struct GameCoordinatorTestClock: PetClock {
    let now: Date
}
