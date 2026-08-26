import Foundation

/// A deterministic, side-effect-free projection for the single gentle local
/// reminder allowed by Pocket Pet 0.1. Notification authorization and request
/// scheduling remain app-layer responsibilities.
public struct ReminderProjection: Sendable {
    public static let maximumProjectionDays = 7
    public static let privacyPreservingBody =
        "A little friend could use a quick check-in."

    public let rules: PetRules

    public init(rules: PetRules = .productBaseline) {
        self.rules = rules
    }

    /// Returns the first upcoming selected local time, within seven calendar
    /// days, at which any projected need is attention or urgent.
    ///
    /// The returned date is strictly after `now`. Calendar arithmetic preserves
    /// the supplied timezone and follows its daylight-saving transitions.
    public func nextReminderDate(
        for state: PetState,
        after now: Date,
        localTime: ReminderLocalTime,
        calendar suppliedCalendar: Calendar = .current
    ) -> Date? {
        guard state.stage != .egg else { return nil }

        var components = DateComponents()
        components.hour = localTime.hour
        components.minute = localTime.minute
        components.second = 0

        guard let firstCandidate = suppliedCalendar.nextDate(
            after: now,
            matching: components,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) else {
            return nil
        }

        for dayOffset in 0..<Self.maximumProjectionDays {
            guard let candidate = suppliedCalendar.date(
                byAdding: .day,
                value: dayOffset,
                to: firstCandidate
            ) else {
                continue
            }

            let projected = PetEngine(
                rules: rules,
                clock: ReminderProjectionClock(now: candidate)
            ).reconcile(state)
            if Self.hasAttentionOrUrgentNeed(projected.needs) {
                return candidate
            }
        }

        return nil
    }

    private static func hasAttentionOrUrgentNeed(_ needs: PetNeeds) -> Bool {
        PetNeed.allCases.contains { needs.status(for: $0) != .comfortable }
    }
}

private struct ReminderProjectionClock: PetClock {
    let now: Date
}
