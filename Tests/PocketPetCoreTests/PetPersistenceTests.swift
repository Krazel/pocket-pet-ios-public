import Foundation
import XCTest
@testable import PocketPetCore

final class PetPersistenceTests: XCTestCase {
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

    func testNoFilesLoadsAsNewInstallation() throws {
        XCTAssertNil(try makeStore().load())
    }

    func testFirstSaveCreatesPrimaryAndLastKnownGoodSnapshot() throws {
        let store = makeStore()
        let pet = makeState(stage: .child)

        try store.save(pet)

        XCTAssertEqual(try store.load(), pet)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.backupURL.path))
    }

    func testSecondSaveKeepsPreviousPrimaryAsLastKnownGood() throws {
        let store = makeStore()
        let first = makeState(stage: .egg)
        let second = makeState(stage: .child)

        try store.save(first)
        try store.save(second)

        XCTAssertEqual(try store.load(), second)
        XCTAssertEqual(try decodeState(at: store.backupURL), first)
    }

    func testCorruptPrimaryFallsBackWithoutChangingBackup() throws {
        let store = makeStore()
        let first = makeState(stage: .egg)
        let second = makeState(stage: .child)
        try store.save(first)
        try store.save(second)
        let backupBefore = try Data(contentsOf: store.backupURL)
        try Data("not json".utf8).write(to: store.fileURL, options: .atomic)

        let recovered = try store.load()

        XCTAssertEqual(recovered, first)
        XCTAssertEqual(try Data(contentsOf: store.backupURL), backupBefore)
    }

    func testSaveAfterCorruptPrimaryDoesNotOverwriteGoodBackup() throws {
        let store = makeStore()
        let first = makeState(stage: .egg)
        let second = makeState(stage: .child)
        try store.save(first)
        try store.save(second)
        let backupBefore = try Data(contentsOf: store.backupURL)
        try Data("not json".utf8).write(to: store.fileURL, options: .atomic)

        try store.save(second)

        XCTAssertEqual(try Data(contentsOf: store.backupURL), backupBefore)
        XCTAssertEqual(try store.load(), second)
    }

    func testFuturePrimarySchemaIsHardErrorEvenWithValidBackup() throws {
        let store = makeStore()
        let current = makeState(stage: .child)
        try store.save(current)
        let future = makeState(
            stage: .adult,
            schemaVersion: PetState.currentSchemaVersion + 1
        )
        try encode(future).write(to: store.fileURL, options: .atomic)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(
                error as? PetPersistenceError,
                .unsupportedSchema(
                    found: PetState.currentSchemaVersion + 1,
                    latest: PetState.currentSchemaVersion
                )
            )
        }
    }

    func testSavingFutureSchemaIsRejected() throws {
        let store = makeStore()
        let future = makeState(
            stage: .adult,
            schemaVersion: PetState.currentSchemaVersion + 1
        )

        XCTAssertThrowsError(try store.save(future)) { error in
            guard let persistenceError = error as? PetPersistenceError,
                  case .unsupportedSchema = persistenceError else {
                return XCTFail("Expected future-schema error")
            }
        }
    }

    func testFutureBackupSchemaIsHardErrorWhenPrimaryIsCorrupt() throws {
        let store = makeStore()
        try store.save(makeState(stage: .child))
        let future = makeState(
            stage: .adult,
            schemaVersion: PetState.currentSchemaVersion + 1
        )
        try Data("not json".utf8).write(to: store.fileURL, options: .atomic)
        try encode(future).write(to: store.backupURL, options: .atomic)

        XCTAssertThrowsError(try store.load()) { error in
            guard let persistenceError = error as? PetPersistenceError,
                  case .unsupportedSchema = persistenceError else {
                return XCTFail("Expected future-schema error")
            }
        }
    }

    func testFutureBackupSchemaIsHardErrorEvenWithValidPrimary() throws {
        let store = makeStore()
        try store.save(makeState(stage: .child))
        let future = makeState(
            stage: .adult,
            schemaVersion: PetState.currentSchemaVersion + 1
        )
        try encode(future).write(to: store.backupURL, options: .atomic)

        XCTAssertThrowsError(try store.load()) { error in
            guard let persistenceError = error as? PetPersistenceError,
                  case .unsupportedSchema = persistenceError else {
                return XCTFail("Expected future-schema error")
            }
        }
    }

    func testExistingButCorruptSnapshotsNeverBecomeOnboarding() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        try Data("bad primary".utf8).write(to: store.fileURL)
        try Data("bad backup".utf8).write(to: store.backupURL)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? PetPersistenceError, .noUsableLocalSnapshot)
        }
    }

    func testBackupCanRecoverWhenPrimaryIsMissing() throws {
        let store = makeStore()
        let state = makeState(stage: .child)
        try store.save(state)
        try FileManager.default.removeItem(at: store.fileURL)

        XCTAssertEqual(try store.load(), state)
    }

    func testRoundTripPreservesRestMarksAndMilestones() throws {
        let store = makeStore()
        let state = PetState(
            id: UUID(uuidString: "D89B1260-B142-4B26-BEDC-59BC75171967")!,
            name: "Pip",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            lastReconciledAt: Date(timeIntervalSince1970: 1_700_003_600),
            stage: .child,
            hatchedAt: Date(timeIntervalSince1970: 1_700_000_000),
            childAgeSeconds: 3_600,
            needs: PetNeeds(hunger: 21.25, happiness: 79.25, energy: 79, cleanliness: 79.375),
            isResting: true,
            restStartedAt: Date(timeIntervalSince1970: 1_700_003_600),
            restElapsedSeconds: 120,
            careMarks: [Date(timeIntervalSince1970: 1_700_000_000)],
            completedCareActions: 3,
            unseenMilestones: [.hatching]
        )

        try store.save(state)

        XCTAssertEqual(try store.load(), state)
    }

    func testDecodeNormalizesPersistedStateInvariants() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        let json = #"{"careMarks":[1700003600000,1700000000000],"childAgeSeconds":-30,"completedCareActions":-2,"createdAt":1700000000000,"hatchedAt":1700000000000,"id":"D89B1260-B142-4B26-BEDC-59BC75171967","isResting":false,"lastReconciledAt":1699990000000,"name":"Pip","needs":{"cleanliness":101,"energy":50,"happiness":120,"hunger":-20},"restElapsedSeconds":200,"restStartedAt":1700000000000,"schemaVersion":1,"stage":"child","unseenMilestones":["hatching","hatching"]}"#
        try Data(json.utf8).write(to: store.fileURL, options: .atomic)

        let state = try XCTUnwrap(store.load())

        XCTAssertEqual(state.lastReconciledAt, state.createdAt)
        XCTAssertEqual(state.childAgeSeconds, 0)
        XCTAssertEqual(state.completedCareActions, 0)
        XCTAssertEqual(state.careMarks, state.careMarks.sorted())
        XCTAssertEqual(state.careMarks.count, 1)
        XCTAssertFalse(state.isResting)
        XCTAssertNil(state.restStartedAt)
        XCTAssertEqual(state.restElapsedSeconds, 0)
        XCTAssertEqual(state.unseenMilestones, [.hatching])
        XCTAssertEqual(state.needs, PetNeeds(hunger: 0, happiness: 100, energy: 50, cleanliness: 100))
    }

    func testDeleteRemovesBothFilesAndIsIdempotent() throws {
        let store = makeStore()
        try store.save(makeState(stage: .child))

        try store.delete()
        try store.delete()

        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.backupURL.path))
        XCTAssertNil(try store.load())
    }

    func testDecodedNeedValuesAreClamped() throws {
        let data = Data(
            #"{"hunger":-20,"happiness":120,"energy":50,"cleanliness":101}"#.utf8
        )
        let needs = try JSONDecoder().decode(PetNeeds.self, from: data)

        XCTAssertEqual(needs, PetNeeds(hunger: 0, happiness: 100, energy: 50, cleanliness: 100))
    }

    private func makeStore() -> JSONFilePetStateStore {
        JSONFilePetStateStore(
            fileURL: temporaryDirectory.appendingPathComponent("pet.json")
        )
    }

    private func makeState(
        stage: PetStage,
        schemaVersion: Int = PetState.currentSchemaVersion
    ) -> PetState {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        return PetState(
            id: UUID(uuidString: "D89B1260-B142-4B26-BEDC-59BC75171967")!,
            name: "Pip",
            createdAt: date,
            stage: stage,
            hatchedAt: stage == .egg ? nil : date,
            needs: PetNeeds(hunger: 20, happiness: 80, energy: 80, cleanliness: 80),
            unseenMilestones: stage == .egg ? [] : [.hatching],
            schemaVersion: schemaVersion
        )
    }

    private func encode(_ state: PetState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(state)
    }

    private func decodeState(at url: URL) throws -> PetState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(PetState.self, from: Data(contentsOf: url))
    }
}
