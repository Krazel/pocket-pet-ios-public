import Foundation

public protocol PocketPetGameStatePersisting {
    func load() throws -> PocketPetGameState?
    func save(_ state: PocketPetGameState) throws
    func delete() throws
}

public enum PocketPetGamePersistenceError: Error, Equatable, Sendable {
    case unsupportedGameSchema(found: Int, latest: Int)
    case unsupportedLegacyPetSchema(found: Int, latest: Int)
    case noUsableLocalSnapshot
}

/// Atomic local persistence for the expanded game aggregate. A legacy 0.1
/// PetState file is migrated in memory and is only replaced after an explicit
/// successful save, preserving the old bytes as the last-known-good snapshot.
public final class JSONFilePocketPetGameStateStore: PocketPetGameStatePersisting {
    public let fileURL: URL
    public let backupURL: URL
    private let fileManager: FileManager

    public init(
        fileURL: URL,
        backupURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.backupURL = backupURL ?? fileURL.appendingPathExtension("last-good")
        self.fileManager = fileManager
    }

    public func load() throws -> PocketPetGameState? {
        let primaryExists = fileManager.fileExists(atPath: fileURL.path)
        let backupExists = fileManager.fileExists(atPath: backupURL.path)
        guard primaryExists || backupExists else { return nil }

        try rejectFutureSchemaIfDeclared(at: fileURL)
        try rejectFutureSchemaIfDeclared(at: backupURL)

        if primaryExists {
            do {
                return try decode(Data(contentsOf: fileURL))
            } catch let error as PocketPetGamePersistenceError {
                switch error {
                case .unsupportedGameSchema, .unsupportedLegacyPetSchema:
                    throw error
                case .noUsableLocalSnapshot:
                    break
                }
            } catch {
                // A corrupt primary is recovered from the backup below.
            }
        }

        if backupExists {
            do {
                return try decode(Data(contentsOf: backupURL))
            } catch let error as PocketPetGamePersistenceError {
                switch error {
                case .unsupportedGameSchema, .unsupportedLegacyPetSchema:
                    throw error
                case .noUsableLocalSnapshot:
                    break
                }
            } catch {
                // Existing but unusable local data must not become onboarding.
            }
        }

        throw PocketPetGamePersistenceError.noUsableLocalSnapshot
    }

    public func save(_ state: PocketPetGameState) throws {
        guard state.gameSchemaVersion <= PocketPetGameState.currentSchemaVersion else {
            throw PocketPetGamePersistenceError.unsupportedGameSchema(
                found: state.gameSchemaVersion,
                latest: PocketPetGameState.currentSchemaVersion
            )
        }
        try rejectFutureSchemaIfDeclared(at: fileURL)
        try rejectFutureSchemaIfDeclared(at: backupURL)
        try createParentDirectories()

        let proposedData = try encode(state)
        let normalizedState = try decode(proposedData)
        let newData = try encode(normalizedState)
        var hasUsablePreviousPrimary = false

        if fileManager.fileExists(atPath: fileURL.path) {
            let previousData = try Data(contentsOf: fileURL)
            do {
                _ = try decode(previousData)
                hasUsablePreviousPrimary = true
                try previousData.write(to: backupURL, options: .atomic)
            } catch let error as PocketPetGamePersistenceError {
                switch error {
                case .unsupportedGameSchema, .unsupportedLegacyPetSchema:
                    throw error
                case .noUsableLocalSnapshot:
                    break
                }
            } catch {
                // Never replace a usable backup with a corrupt primary.
            }
        }

        try newData.write(to: fileURL, options: .atomic)
        if !hasUsablePreviousPrimary,
           !fileManager.fileExists(atPath: backupURL.path) {
            try newData.write(to: backupURL, options: .atomic)
        }
    }

    public func delete() throws {
        for url in [fileURL, backupURL]
        where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func createParentDirectories() throws {
        for parent in [
            fileURL.deletingLastPathComponent(),
            backupURL.deletingLastPathComponent(),
        ] {
            try fileManager.createDirectory(
                at: parent,
                withIntermediateDirectories: true
            )
        }
    }

    private func encode(_ state: PocketPetGameState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(state)
    }

    private func decode(_ data: Data) throws -> PocketPetGameState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        if let envelope = try? decoder.decode(GameSchemaEnvelope.self, from: data) {
            guard envelope.gameSchemaVersion
                    <= PocketPetGameState.currentSchemaVersion else {
                throw PocketPetGamePersistenceError.unsupportedGameSchema(
                    found: envelope.gameSchemaVersion,
                    latest: PocketPetGameState.currentSchemaVersion
                )
            }
            return try decoder.decode(PocketPetGameState.self, from: data)
        }

        let legacyEnvelope = try decoder.decode(LegacyPetSchemaEnvelope.self, from: data)
        guard legacyEnvelope.schemaVersion <= PetState.currentSchemaVersion else {
            throw PocketPetGamePersistenceError.unsupportedLegacyPetSchema(
                found: legacyEnvelope.schemaVersion,
                latest: PetState.currentSchemaVersion
            )
        }
        return PocketPetGameState(
            migrating: try decoder.decode(PetState.self, from: data)
        )
    }

    private func rejectFutureSchemaIfDeclared(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        if let envelope = try? decoder.decode(GameSchemaEnvelope.self, from: data),
           envelope.gameSchemaVersion > PocketPetGameState.currentSchemaVersion {
            throw PocketPetGamePersistenceError.unsupportedGameSchema(
                found: envelope.gameSchemaVersion,
                latest: PocketPetGameState.currentSchemaVersion
            )
        }
        if let envelope = try? decoder.decode(LegacyPetSchemaEnvelope.self, from: data),
           envelope.schemaVersion > PetState.currentSchemaVersion {
            throw PocketPetGamePersistenceError.unsupportedLegacyPetSchema(
                found: envelope.schemaVersion,
                latest: PetState.currentSchemaVersion
            )
        }
    }
}

private struct GameSchemaEnvelope: Decodable {
    let gameSchemaVersion: Int
}

private struct LegacyPetSchemaEnvelope: Decodable {
    let schemaVersion: Int
}
