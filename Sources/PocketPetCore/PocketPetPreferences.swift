import Foundation

public enum ReminderLocalTimeError: Error, Equatable, Sendable {
    case invalidHour
    case invalidMinute
}

/// A timezone-independent local wall-clock time. The app resolves it in the
/// device's current calendar and timezone when notification support is added.
public struct ReminderLocalTime: Codable, Equatable, Sendable {
    public let hour: Int
    public let minute: Int

    public static let defaultCheckIn = ReminderLocalTime(
        validatedHour: 19,
        validatedMinute: 0
    )

    public init(hour: Int, minute: Int) throws {
        guard (0...23).contains(hour) else {
            throw ReminderLocalTimeError.invalidHour
        }
        guard (0...59).contains(minute) else {
            throw ReminderLocalTimeError.invalidMinute
        }
        self.hour = hour
        self.minute = minute
    }

    private init(validatedHour: Int, validatedMinute: Int) {
        hour = validatedHour
        minute = validatedMinute
    }

    private enum CodingKeys: String, CodingKey {
        case hour
        case minute
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            hour: try container.decode(Int.self, forKey: .hour),
            minute: try container.decode(Int.self, forKey: .minute)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hour, forKey: .hour)
        try container.encode(minute, forKey: .minute)
    }
}

public enum PocketPetPreferenceCommand: Equatable, Sendable {
    case setSoundEnabled(Bool)
    case setReduceMotionEnabled(Bool)
    case setRemindersEnabled(Bool)
    case setReminderTime(ReminderLocalTime)
    case markReminderInvitationShown
    case setLocalNotificationIdentifier(String?)
    case setLastReminderFireDate(Date?)
}

public struct PocketPetPreferences: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let defaults = PocketPetPreferences()

    public let schemaVersion: Int
    public private(set) var soundEnabled: Bool
    public private(set) var reduceMotionEnabled: Bool
    public private(set) var remindersEnabled: Bool
    public private(set) var reminderTime: ReminderLocalTime
    public private(set) var reminderInvitationShown: Bool
    public private(set) var foregroundSessionCount: Int
    public private(set) var localNotificationIdentifier: String?
    public private(set) var lastReminderFireDate: Date?

    public init(
        soundEnabled: Bool = true,
        reduceMotionEnabled: Bool = false,
        remindersEnabled: Bool = false,
        reminderTime: ReminderLocalTime = .defaultCheckIn,
        reminderInvitationShown: Bool = false,
        foregroundSessionCount: Int = 0,
        localNotificationIdentifier: String? = nil,
        lastReminderFireDate: Date? = nil,
        schemaVersion: Int = PocketPetPreferences.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.soundEnabled = soundEnabled
        self.reduceMotionEnabled = reduceMotionEnabled
        self.remindersEnabled = remindersEnabled
        self.reminderTime = reminderTime
        self.reminderInvitationShown = reminderInvitationShown
        self.foregroundSessionCount = max(0, foregroundSessionCount)
        self.localNotificationIdentifier = Self.normalizedIdentifier(
            localNotificationIdentifier
        )
        self.lastReminderFireDate = lastReminderFireDate
    }

    mutating func incrementForegroundSessionCount() {
        foregroundSessionCount += 1
    }

    mutating func apply(_ command: PocketPetPreferenceCommand) {
        switch command {
        case let .setSoundEnabled(isEnabled):
            soundEnabled = isEnabled
        case let .setReduceMotionEnabled(isEnabled):
            reduceMotionEnabled = isEnabled
        case let .setRemindersEnabled(isEnabled):
            remindersEnabled = isEnabled
        case let .setReminderTime(time):
            reminderTime = time
        case .markReminderInvitationShown:
            reminderInvitationShown = true
        case let .setLocalNotificationIdentifier(identifier):
            localNotificationIdentifier = Self.normalizedIdentifier(identifier)
        case let .setLastReminderFireDate(date):
            lastReminderFireDate = date
        }
    }

    private static func normalizedIdentifier(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case soundEnabled
        case reduceMotionEnabled
        case remindersEnabled
        case reminderTime
        case reminderInvitationShown
        case foregroundSessionCount
        case localNotificationIdentifier
        case lastReminderFireDate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            soundEnabled: try container.decode(Bool.self, forKey: .soundEnabled),
            reduceMotionEnabled: try container.decode(
                Bool.self,
                forKey: .reduceMotionEnabled
            ),
            remindersEnabled: try container.decode(
                Bool.self,
                forKey: .remindersEnabled
            ),
            reminderTime: try container.decode(
                ReminderLocalTime.self,
                forKey: .reminderTime
            ),
            reminderInvitationShown: try container.decode(
                Bool.self,
                forKey: .reminderInvitationShown
            ),
            foregroundSessionCount: try container.decode(
                Int.self,
                forKey: .foregroundSessionCount
            ),
            localNotificationIdentifier: try container.decodeIfPresent(
                String.self,
                forKey: .localNotificationIdentifier
            ),
            lastReminderFireDate: try container.decodeIfPresent(
                Date.self,
                forKey: .lastReminderFireDate
            ),
            schemaVersion: try container.decode(Int.self, forKey: .schemaVersion)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(soundEnabled, forKey: .soundEnabled)
        try container.encode(reduceMotionEnabled, forKey: .reduceMotionEnabled)
        try container.encode(remindersEnabled, forKey: .remindersEnabled)
        try container.encode(reminderTime, forKey: .reminderTime)
        try container.encode(
            reminderInvitationShown,
            forKey: .reminderInvitationShown
        )
        try container.encode(foregroundSessionCount, forKey: .foregroundSessionCount)
        try container.encodeIfPresent(
            localNotificationIdentifier,
            forKey: .localNotificationIdentifier
        )
        try container.encodeIfPresent(
            lastReminderFireDate,
            forKey: .lastReminderFireDate
        )
    }
}
