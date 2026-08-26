import Foundation
import XCTest
@testable import PocketPetCore

final class PocketPetGamePersistenceTests: XCTestCase {
    func testMissingFilesLoadAsNoGame() throws {
        XCTAssertNil(try makeStore().load())
    }

    func testLegacyPetLoadsAsExpandedGameWithoutReplacingLegacyBytes() throws {
        let store = try makeStore()
        let legacy = makeLegacyPet()
        let legacyData = try encodeLegacy(legacy)
        try legacyData.write(to: store.fileURL, options: .atomic)

        let migrated = try XCTUnwrap(store.load())

        XCTAssertEqual(migrated.pet, legacy)
        XCTAssertEqual(migrated.gameSchemaVersion, 2)
        XCTAssertEqual(try Data(contentsOf: store.fileURL), legacyData)
    }

    func testSavingMigrationPreservesLegacyAsBackupThenRoundTripsGame() throws {
        let store = try makeStore()
        let legacy = makeLegacyPet()
        let legacyData = try encodeLegacy(legacy)
        try legacyData.write(to: store.fileURL, options: .atomic)
        let migrated = try XCTUnwrap(store.load())

        try store.save(migrated)

        XCTAssertEqual(try Data(contentsOf: store.backupURL), legacyData)
        XCTAssertEqual(try store.load(), migrated)
    }

    func testCorruptPrimaryFallsBackToLastKnownGoodExpandedGame() throws {
        let store = try makeStore()
        let game = PocketPetGameState(migrating: makeLegacyPet())
        try store.save(game)
        try Data("broken".utf8).write(to: store.fileURL, options: .atomic)

        XCTAssertEqual(try store.load(), game)
    }

    func testFutureExpandedSchemaIsRejectedBeforeFallback() throws {
        let store = try makeStore()
        try Data(#"{"gameSchemaVersion":99}"#.utf8).write(
            to: store.fileURL,
            options: .atomic
        )

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(
                error as? PocketPetGamePersistenceError,
                .unsupportedGameSchema(found: 99, latest: 2)
            )
        }
    }

    func testFutureLegacySchemaIsRejectedBeforeFallback() throws {
        let store = try makeStore()
        try Data(#"{"schemaVersion":99}"#.utf8).write(
            to: store.fileURL,
            options: .atomic
        )

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(
                error as? PocketPetGamePersistenceError,
                .unsupportedLegacyPetSchema(found: 99, latest: 1)
            )
        }
    }

    func testDeleteRemovesPrimaryAndBackup() throws {
        let store = try makeStore()
        try store.save(PocketPetGameState(migrating: makeLegacyPet()))

        try store.delete()

        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.backupURL.path))
    }

    private func makeStore() throws -> JSONFilePocketPetGameStateStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return JSONFilePocketPetGameStateStore(
            fileURL: directory.appendingPathComponent("pet-state.json")
        )
    }

    private func makeLegacyPet() -> PetState {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        return PetState(
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
    }

    private func encodeLegacy(_ pet: PetState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(pet)
    }
}
