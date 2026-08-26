import Foundation
import XCTest
@testable import PocketPetCore

final class ReminderDeliveryBoundaryTests: XCTestCase {
    private let boundary = ReminderDeliveryBoundary()

    func testClearedNotificationCenterUsesNowForPossiblyDelayedDelivery() {
        let recorded = Date(timeIntervalSince1970: 1_790_000_000)
        let now = recorded.addingTimeInterval(60 * 60)

        let result = boundary.earliestPermittedFireDate(
            now: now,
            recordedFireDate: recorded,
            latestVisibleDeliveryDate: nil
        )

        XCTAssertEqual(
            result,
            now.addingTimeInterval(ReminderDeliveryBoundary.minimumInterval)
        )
    }

    func testRelaunchProducesSameBoundaryFromPersistedLedger() {
        let recorded = Date(timeIntervalSince1970: 1_790_000_000)
        let now = recorded.addingTimeInterval(3 * 60 * 60)

        let first = boundary.earliestPermittedFireDate(
            now: now,
            recordedFireDate: recorded,
            latestVisibleDeliveryDate: nil
        )
        let afterRelaunch = ReminderDeliveryBoundary().earliestPermittedFireDate(
            now: now,
            recordedFireDate: recorded,
            latestVisibleDeliveryDate: nil
        )

        XCTAssertEqual(first, afterRelaunch)
    }

    func testVisibleDeliveryWinsWhenItIsNewerThanRecordedFire() {
        let recorded = Date(timeIntervalSince1970: 1_790_000_000)
        let visible = recorded.addingTimeInterval(15 * 60)
        let now = visible.addingTimeInterval(60 * 60)

        let result = boundary.earliestPermittedFireDate(
            now: now,
            recordedFireDate: recorded,
            latestVisibleDeliveryDate: visible
        )

        XCTAssertEqual(
            result,
            visible.addingTimeInterval(ReminderDeliveryBoundary.minimumInterval)
        )
    }

    func testOlderVisibleDeliveryDoesNotHideNewerUnobservedScheduledFire() {
        let visible = Date(timeIntervalSince1970: 1_790_000_000)
        let recorded = visible.addingTimeInterval(20 * 60 * 60)
        let now = recorded.addingTimeInterval(2 * 60 * 60)

        let result = boundary.earliestPermittedFireDate(
            now: now,
            recordedFireDate: recorded,
            latestVisibleDeliveryDate: visible
        )

        XCTAssertEqual(
            result,
            now.addingTimeInterval(ReminderDeliveryBoundary.minimumInterval)
        )
    }

    func testDSTLikeTwentyThreeHourCandidateIsRejected() {
        let priorFire = Date(timeIntervalSince1970: 1_790_000_000)
        let earliest = priorFire.addingTimeInterval(24 * 60 * 60)
        let localNextDay = priorFire.addingTimeInterval(23 * 60 * 60)

        XCTAssertFalse(
            boundary.permits(
                fireDate: localNextDay,
                earliestPermittedFireDate: earliest
            )
        )
    }

    func testExactlyTwentyFourHoursIsPermitted() {
        let priorFire = Date(timeIntervalSince1970: 1_790_000_000)
        let earliest = priorFire.addingTimeInterval(24 * 60 * 60)

        XCTAssertTrue(
            boundary.permits(
                fireDate: earliest,
                earliestPermittedFireDate: earliest
            )
        )
    }

    func testFutureRecordedFireDoesNotDelayReplacementBoundary() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)

        XCTAssertEqual(
            boundary.earliestPermittedFireDate(
                now: now,
                recordedFireDate: now.addingTimeInterval(60 * 60),
                latestVisibleDeliveryDate: nil
            ),
            now
        )
    }
}
