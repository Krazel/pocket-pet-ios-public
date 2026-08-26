import Foundation
import XCTest
@testable import PocketPetCore

final class PocketPetExpandedStateCoordinatorTests: XCTestCase {
    func testStartMigratesLegacyInPlaceAndPreservesOriginalBackup() async throws {
        let fixture = try makeFixture(with: makeChild())
        let originalBytes = try Data(contentsOf: fixture.gameStore.fileURL)
        let coordinator = makeCoordinator(fixture: fixture)

        let snapshot = try await coordinator.startForegroundSession()

        XCTAssertEqual(snapshot.pet?.name, "Pip")
        XCTAssertEqual(snapshot.gameState?.gameSchemaVersion, 2)
        XCTAssertEqual(try Data(contentsOf: fixture.gameStore.backupURL), originalBytes)
        XCTAssertEqual(try fixture.gameStore.load(), snapshot.gameState)
    }

    func testHomeFeedPreservesStarterInventory() async throws {
        let fixture = try makeFixture(with: makeChild())
        let coordinator = makeCoordinator(fixture: fixture)
        let started = try await coordinator.startForegroundSession()
        let quantity = try XCTUnwrap(started.gameState).inventory.quantity(
            of: .dewberry
        )

        let result = try await coordinator.performCareAction(.feed)

        XCTAssertEqual(result.snapshot.pet?.needs.hunger, 0)
        XCTAssertEqual(
            result.snapshot.gameState?.inventory.quantity(of: .dewberry),
            quantity
        )
    }

    func testPantryConsumptionPersistsAndReplaysSafely() async throws {
        let fixture = try makeFixture(with: makeChild())
        let coordinator = makeCoordinator(fixture: fixture)
        _ = try await coordinator.startForegroundSession()
        let commandID = UUID(
            uuidString: "99999999-9999-9999-9999-999999999999"
        )!

        let consumed = try await coordinator.consume(
            itemID: .dewberry,
            commandID: commandID
        )
        let replayed = try await coordinator.consume(
            itemID: .dewberry,
            commandID: commandID
        )

        XCTAssertEqual(consumed.gameState?.inventory.quantity(of: .dewberry), 2)
        XCTAssertEqual(replayed, consumed)
        XCTAssertEqual(try fixture.gameStore.load(), consumed.gameState)
    }

    func testOnboardingCreatesExpandedEggThenHatches() async throws {
        let fixture = try makeFixture(with: nil)
        let coordinator = makeCoordinator(fixture: fixture)
        _ = try await coordinator.startForegroundSession()

        let egg = try await coordinator.createEgg(named: "Pip")
        let hatched = try await coordinator.hatch()

        XCTAssertEqual(egg.snapshot.gameState?.pet.stage, .egg)
        XCTAssertEqual(hatched.snapshot.gameState?.pet.stage, .child)
        XCTAssertEqual(hatched.snapshot.destination, .milestone(.hatching))
    }

    func testPreferencesRemainInTheSharedSnapshot() async throws {
        let fixture = try makeFixture(with: makeChild())
        let coordinator = makeCoordinator(fixture: fixture)
        _ = try await coordinator.startForegroundSession()

        let updated = try await coordinator.updatePreferences(
            .setReduceMotionEnabled(true)
        )

        XCTAssertTrue(updated.preferences.reduceMotionEnabled)
        XCTAssertNotNil(updated.gameState)
        XCTAssertEqual(try fixture.preferencesStore.load(), updated.preferences)
    }

    private func makeCoordinator(
        fixture: ExpandedCoordinatorFixture
    ) -> PocketPetExpandedStateCoordinator {
        PocketPetExpandedStateCoordinator(
            petEngine: PetEngine(
                clock: ExpandedCoordinatorTestClock(now: fixture.now)
            ),
            gameStore: fixture.gameStore,
            preferencesStore: fixture.preferencesStore
        )
    }

    private func makeFixture(
        with pet: PetState?
    ) throws -> ExpandedCoordinatorFixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let gameURL = directory.appendingPathComponent("pet-state.json")
        if let pet {
            try JSONFilePetStateStore(fileURL: gameURL).save(pet)
        }
        let preferencesStore = JSONFilePocketPetPreferencesStore(
            fileURL: directory.appendingPathComponent("preferences.json")
        )
        return ExpandedCoordinatorFixture(
            now: pet?.lastReconciledAt
                ?? Date(timeIntervalSince1970: 1_700_000_000),
            gameStore: JSONFilePocketPetGameStateStore(fileURL: gameURL),
            preferencesStore: preferencesStore
        )
    }

    private func makeChild() -> PetState {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        return PetState(
            name: "Pip",
            createdAt: date,
            lastReconciledAt: date,
            stage: .child,
            hatchedAt: date,
            needs: PetNeeds(
                hunger: 20,
                happiness: 80,
                energy: 80,
                cleanliness: 80
            )
        )
    }
}

private struct ExpandedCoordinatorFixture {
    let now: Date
    let gameStore: JSONFilePocketPetGameStateStore
    let preferencesStore: JSONFilePocketPetPreferencesStore
}

private struct ExpandedCoordinatorTestClock: PetClock {
    let now: Date
}
