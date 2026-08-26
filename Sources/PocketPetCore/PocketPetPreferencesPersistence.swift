import Foundation

public protocol PocketPetPreferencesPersisting {
    func load() throws -> PocketPetPreferences?
    func save(_ preferences: PocketPetPreferences) throws
}

public enum PocketPetPreferencesPersistenceError: Error, Equatable, Sendable {
    case unsupportedSchema(found: Int, latest: Int)
}

/// A separate atomic preferences file keeps app settings independent from the
/// lifecycle schema and from the pet's last-known-good progress snapshots.
public final class JSONFilePocketPetPreferencesStore: PocketPetPreferencesPersisting {
    public let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func load() throws -> PocketPetPreferences? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try decode(data)
    }

    public func save(_ preferences: PocketPetPreferences) throws {
        guard preferences.schemaVersion <= PocketPetPreferences.currentSchemaVersion else {
            throw PocketPetPreferencesPersistenceError.unsupportedSchema(
                found: preferences.schemaVersion,
                latest: PocketPetPreferences.currentSchemaVersion
            )
        }

        let parent = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: parent,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(preferences)
        try data.write(to: fileURL, options: .atomic)
    }

    private func decode(_ data: Data) throws -> PocketPetPreferences {
        let decoder = JSONDecoder()
        let envelope = try decoder.decode(PreferencesSchemaEnvelope.self, from: data)
        guard envelope.schemaVersion <= PocketPetPreferences.currentSchemaVersion else {
            throw PocketPetPreferencesPersistenceError.unsupportedSchema(
                found: envelope.schemaVersion,
                latest: PocketPetPreferences.currentSchemaVersion
            )
        }
        return try decoder.decode(PocketPetPreferences.self, from: data)
    }
}

private struct PreferencesSchemaEnvelope: Decodable {
    let schemaVersion: Int
}
