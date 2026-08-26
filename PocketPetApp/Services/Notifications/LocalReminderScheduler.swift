import Foundation
import UserNotifications

enum LocalReminderAuthorization: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

protocol LocalReminderScheduling: Sendable {
    func authorizationStatus() async -> LocalReminderAuthorization
    func requestAuthorization() async throws -> LocalReminderAuthorization
    func replaceReminder(
        identifier: String,
        fireDate: Date,
        body: String
    ) async throws
    func cancelReminder(identifier: String) async
    func latestDeliveryDate(identifier: String) async -> Date?
    func pendingReminderFireDate(identifier: String) async -> Date?
}

/// The only adapter that touches UserNotifications. It deliberately exposes
/// app-level values so scheduling policy remains independently replaceable in
/// tests and the rest of the app never depends on UN request types.
actor UserNotificationReminderScheduler: LocalReminderScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> LocalReminderAuthorization {
        let settings = await center.notificationSettings()
        return Self.map(settings.authorizationStatus)
    }

    func requestAuthorization() async throws -> LocalReminderAuthorization {
        _ = try await center.requestAuthorization(options: [.alert, .sound])
        return await authorizationStatus()
    }

    func replaceReminder(
        identifier: String,
        fireDate: Date,
        body: String
    ) async throws {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Pocket Pet"
        content.body = body
        content.sound = .default

        var components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        components.calendar = Calendar.current
        components.timeZone = TimeZone.current
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    func cancelReminder(identifier: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func latestDeliveryDate(identifier: String) async -> Date? {
        let notifications = await center.deliveredNotifications()
        return notifications
            .filter { $0.request.identifier == identifier }
            .map(\.date)
            .max()
    }

    func pendingReminderFireDate(identifier: String) async -> Date? {
        let requests = await center.pendingNotificationRequests()
        guard let trigger = requests
            .first(where: { $0.identifier == identifier })?
            .trigger else {
            return nil
        }
        guard let calendarTrigger = trigger as? UNCalendarNotificationTrigger else {
            return nil
        }
        return calendarTrigger.nextTriggerDate()
    }

    private static func map(
        _ status: UNAuthorizationStatus
    ) -> LocalReminderAuthorization {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            return .authorized
        @unknown default:
            return .notDetermined
        }
    }
}
