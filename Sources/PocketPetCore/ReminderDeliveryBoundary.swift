import Foundation

/// Conservatively enforces the product's rolling delivery interval without
/// depending on Notification Center history remaining visible. A previously
/// scheduled fire date that has passed is treated as a possible delivery.
/// iOS does not callback the app for every background delivery; if the system
/// delays one and it is cleared before the app observes it, only the intended
/// fire date remains knowable and the actual delayed instant cannot be proven.
public struct ReminderDeliveryBoundary: Equatable, Sendable {
    public static let minimumInterval: TimeInterval = 24 * 60 * 60

    public init() {}

    /// The earliest absolute instant at which another notification may fire.
    /// Future recorded dates represent pending work and do not constrain a
    /// replacement. An elapsed scheduled fire without a matching visible
    /// delivery is treated as possibly delivered at `now`: iOS may have
    /// delayed it and the player may already have cleared Notification Center.
    public func earliestPermittedFireDate(
        now: Date,
        recordedFireDate: Date?,
        latestVisibleDeliveryDate: Date?
    ) -> Date {
        let elapsedRecordedFire = recordedFireDate.flatMap {
            $0 <= now ? $0 : nil
        }
        let visibleDelivery = latestVisibleDeliveryDate.flatMap {
            $0 <= now ? $0 : nil
        }

        let hasUnobservedElapsedFire: Bool
        if let elapsedRecordedFire {
            if let visibleDelivery {
                hasUnobservedElapsedFire = visibleDelivery < elapsedRecordedFire
            } else {
                hasUnobservedElapsedFire = true
            }
        } else {
            hasUnobservedElapsedFire = false
        }

        let possibleDeliveries = [elapsedRecordedFire, visibleDelivery]
            .compactMap { $0 }

        if hasUnobservedElapsedFire {
            return now.addingTimeInterval(Self.minimumInterval)
        }

        guard let latestPossibleDelivery = possibleDeliveries.max() else {
            return now
        }
        return max(
            now,
            latestPossibleDelivery.addingTimeInterval(Self.minimumInterval)
        )
    }

    public func permits(
        fireDate: Date,
        earliestPermittedFireDate: Date
    ) -> Bool {
        fireDate >= earliestPermittedFireDate
    }
}
