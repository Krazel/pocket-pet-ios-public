import Foundation
import XCTest
@testable import PocketPetCore

final class ReminderProjectionTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "en_US_POSIX")
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    func testEggNeverProducesReminder() throws {
        let now = date(2026, 1, 1, 10, 0)
        let egg = PetState(
            name: "Pip",
            createdAt: now,
            needs: PetRules.productBaseline.initialChildNeeds
        )

        XCTAssertNil(
            ReminderProjection().nextReminderDate(
                for: egg,
                after: now,
                localTime: try ReminderLocalTime(hour: 19, minute: 0),
                calendar: calendar
            )
        )
    }

    func testSelectsFirstLocalTimeWithAttentionNeed() throws {
        let now = date(2026, 1, 1, 10, 0)
        let state = child(at: now, needs: .init(
            hunger: 20,
            happiness: 80,
            energy: 80,
            cleanliness: 80
        ))

        let result = ReminderProjection().nextReminderDate(
            for: state,
            after: now,
            localTime: try ReminderLocalTime(hour: 19, minute: 0),
            calendar: calendar
        )

        XCTAssertEqual(result, date(2026, 1, 2, 19, 0))
    }

    func testAlreadyAttentionStateUsesNextSelectedTime() throws {
        let now = date(2026, 1, 1, 18, 0)
        let state = child(at: now, needs: .init(
            hunger: 45,
            happiness: 80,
            energy: 80,
            cleanliness: 80
        ))

        let result = ReminderProjection().nextReminderDate(
            for: state,
            after: now,
            localTime: try ReminderLocalTime(hour: 19, minute: 0),
            calendar: calendar
        )

        XCTAssertEqual(result, date(2026, 1, 1, 19, 0))
    }

    func testExactSelectedTimeAdvancesToFollowingDay() throws {
        let now = date(2026, 1, 1, 19, 0)
        let state = child(at: now, needs: .init(
            hunger: 45,
            happiness: 80,
            energy: 80,
            cleanliness: 80
        ))

        let result = ReminderProjection().nextReminderDate(
            for: state,
            after: now,
            localTime: try ReminderLocalTime(hour: 19, minute: 0),
            calendar: calendar
        )

        XCTAssertEqual(result, date(2026, 1, 2, 19, 0))
    }

    func testReturnsNilWhenNoNeedChangesWithinSevenDays() throws {
        let now = date(2026, 1, 1, 10, 0)
        let rules = PetRules(
            initialChildNeeds: PetNeeds(
                hunger: 0,
                happiness: 100,
                energy: 100,
                cleanliness: 100
            ),
            awakeHourlyChange: NeedChange(),
            sleepingHourlyChange: NeedChange(),
            actionChanges: [:],
            maximumDecayInterval: 72 * 60 * 60,
            maximumRestInterval: 2 * 60 * 60,
            careMarkWindow: 18 * 60 * 60,
            adultChildAge: 72 * 60 * 60,
            adultCareMarkCount: 3
        )
        let state = child(at: now, needs: rules.initialChildNeeds)

        let result = ReminderProjection(rules: rules).nextReminderDate(
            for: state,
            after: now,
            localTime: try ReminderLocalTime(hour: 19, minute: 0),
            calendar: calendar
        )

        XCTAssertNil(result)
    }

    func testSuppliedTimezoneDefinesLocalReminderTime() throws {
        let now = date(2026, 1, 1, 8, 0)
        let state = child(at: now, needs: .init(
            hunger: 45,
            happiness: 80,
            energy: 80,
            cleanliness: 80
        ))
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        let result = try XCTUnwrap(
            ReminderProjection().nextReminderDate(
                for: state,
                after: now,
                localTime: try ReminderLocalTime(hour: 19, minute: 30),
                calendar: tokyo
            )
        )
        let components = tokyo.dateComponents(
            [.hour, .minute],
            from: result
        )

        XCTAssertEqual(components.hour, 19)
        XCTAssertEqual(components.minute, 30)
    }

    func testReminderCopyDoesNotExposePetNameOrState() {
        XCTAssertEqual(
            ReminderProjection.privacyPreservingBody,
            "A little friend could use a quick check-in."
        )
        XCTAssertFalse(ReminderProjection.privacyPreservingBody.contains("Pip"))
        XCTAssertFalse(ReminderProjection.privacyPreservingBody.contains("%"))
    }

    private func child(at date: Date, needs: PetNeeds) -> PetState {
        PetState(
            name: "Pip",
            createdAt: date,
            lastReconciledAt: date,
            stage: .child,
            hatchedAt: date,
            needs: needs
        )
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
