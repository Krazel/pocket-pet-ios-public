import Foundation

public protocol PetStatePersisting {
    func load() throws -> PetState?
    func save(_ state: PetState) throws
    func delete() throws
}

public enum PetPersistenceError: Error, Equatable, Sendable {
    case unsupportedSchema(found: Int, latest: Int)
    case noUsableLocalSnapshot
}

/// Atomic JSON storage with a separate last-known-good snapshot. The iOS app
/// supplies an Application Support URL; this type never chooses cloud storage.
public final class JSONFilePetStateStore: PetStatePersisting {
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

    public func load() throws -> PetState? {
        let primaryExists = fileManager.fileExists(atPath: fileURL.path)
        let backupExists = fileManager.fileExists(atPath: backupURL.path)
        guard primaryExists || backupExists else { return nil }

        try rejectFutureSchemaIfDeclared(at: fileURL)
        try rejectFutureSchemaIfDeclared(at: backupURL)

        if primaryExists {
            do {
                return try decode(Data(contentsOf: fileURL))
            } catch let error as PetPersistenceError {
                if case .unsupportedSchema = error { throw error }
            } catch {
                // A corrupt primary is recovered below without modifying files.
            }
        }

        if backupExists {
            do {
                return try decode(Data(contentsOf: backupURL))
            } catch let error as PetPersistenceError {
                if case .unsupportedSchema = error { throw error }
            } catch {
                // Existing but unusable local data must not become onboarding.
            }
        }

        throw PetPersistenceError.noUsableLocalSnapshot
    }

    public func save(_ state: PetState) throws {
        guard state.schemaVersion <= PetState.currentSchemaVersion else {
            throw PetPersistenceError.unsupportedSchema(
                found: state.schemaVersion,
                latest: PetState.currentSchemaVersion
            )
        }
        try rejectFutureSchemaIfDeclared(at: fileURL)
        try rejectFutureSchemaIfDeclared(at: backupURL)
        let parent = fileURL.deletingLastPathComponent()
        let backupParent = backupURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: parent,
            withIntermediateDirectories: true
        )
        if backupParent != parent {
            try fileManager.createDirectory(
                at: backupParent,
                withIntermediateDirectories: true
            )
        }

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
            } catch let error as PetPersistenceError {
                if case .unsupportedSchema = error { throw error }
                // Never replace the backup with corrupt primary data.
            } catch {
                // Never replace the backup with corrupt primary data.
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

    private func encode(_ state: PetState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(state)
    }

    private func decode(_ data: Data) throws -> PetState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let envelope = try decoder.decode(SchemaEnvelope.self, from: data)
        guard envelope.schemaVersion <= PetState.currentSchemaVersion else {
            throw PetPersistenceError.unsupportedSchema(
                found: envelope.schemaVersion,
                latest: PetState.currentSchemaVersion
            )
        }
        return try decoder.decode(PetState.self, from: data)
    }

    private func rejectFutureSchemaIfDeclared(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        guard let envelope = try? decoder.decode(SchemaEnvelope.self, from: data),
              envelope.schemaVersion > PetState.currentSchemaVersion else {
            return
        }
        throw PetPersistenceError.unsupportedSchema(
            found: envelope.schemaVersion,
            latest: PetState.currentSchemaVersion
        )
    }
}

private struct SchemaEnvelope: Decodable {
    let schemaVersion: Int
}
