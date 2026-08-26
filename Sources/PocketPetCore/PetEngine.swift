import Foundation

public protocol PetClock: Sendable {
    var now: Date { get }
}

public struct SystemPetClock: PetClock {
    public init() {}
    public var now: Date { Date() }
}

/// Deterministic state transitions driven by an injected clock. The engine is
/// Foundation-only and performs no persistence or other I/O.
public struct PetEngine: Sendable {
    public let rules: PetRules
    public let clock: any PetClock

    public init(
        rules: PetRules = .productBaseline,
        clock: any PetClock = SystemPetClock()
    ) {
        self.rules = rules
        self.clock = clock
    }

    public func makeEgg(named rawName: String, id: UUID = UUID()) throws -> PetState {
        let name = try PetName(rawName)
        return PetState(
            id: id,
            name: name.value,
            createdAt: clock.now,
            needs: rules.initialChildNeeds
        )
    }

    /// Explicit, immediate onboarding transition. Time spent as an egg is not
    /// child age and does not decay needs.
    public func hatch(_ state: PetState) -> PetState {
        var result = reconcile(state)
        result.hatch(
            at: result.lastReconciledAt,
            initialNeeds: rules.initialChildNeeds
        )
        return result
    }

    /// Reconciles nonnegative elapsed wall time. Need changes use at most the
    /// first 72 hours, while child lifecycle age receives the full interval.
    public func reconcile(_ state: PetState) -> PetState {
        let now = clock.now
        guard now > state.lastReconciledAt else { return state }

        let fullElapsed = now.timeIntervalSince(state.lastReconciledAt)
        var result = state
        result.addChildAge(fullElapsed)

        if result.stage != .egg {
            let decayElapsed = min(fullElapsed, rules.maximumDecayInterval)
            applyNeedTime(decayElapsed, to: &result)
        }

        result.setCheckpoint(now)
        evaluateAdultEvolution(&result)
        return result
    }

    public func perform(_ action: CareAction, on state: PetState) -> PetState {
        var result = reconcile(state)
        guard result.stage != .egg else { return result }

        if action == .rest {
            if result.isResting {
                result.stopRest()
            } else {
                result.startRest(at: result.lastReconciledAt)
                if result.needs.energy >= 100 {
                    result.stopRest()
                }
            }
        } else {
            if result.isResting {
                result.stopRest()
            }
            if let change = rules.actionChanges[action] {
                var needs = result.needs
                needs.apply(change)
                result.setNeeds(needs)
            }
        }

        result.recordCareAction(
            at: result.lastReconciledAt,
            markWindow: rules.careMarkWindow
        )
        evaluateAdultEvolution(&result)
        return result
    }

    public func markMilestoneSeen(
        _ milestone: PetMilestone,
        in state: PetState
    ) -> PetState {
        var result = state
        result.markMilestoneSeen(milestone)
        return result
    }

    private func applyNeedTime(_ duration: TimeInterval, to state: inout PetState) {
        guard duration > 0 else { return }
        var remaining = duration

        if state.isResting {
            let restRemaining = max(
                0,
                rules.maximumRestInterval - state.restElapsedSeconds
            )
            let timeToFullEnergy: TimeInterval
            let energyRate = rules.sleepingHourlyChange.energy / 3_600
            if state.needs.energy >= 100 {
                timeToFullEnergy = 0
            } else if energyRate > 0 {
                timeToFullEnergy = (100 - state.needs.energy) / energyRate
            } else {
                timeToFullEnergy = .greatestFiniteMagnitude
            }

            let sleepingDuration = min(
                remaining,
                min(restRemaining, timeToFullEnergy)
            )
            apply(rules.sleepingHourlyChange, for: sleepingDuration, to: &state)
            state.addRestElapsed(sleepingDuration)
            remaining -= sleepingDuration

            let energyIsFull = state.needs.energy >= 100 - 0.000_001
            let restTimedOut = state.restElapsedSeconds
                >= (rules.maximumRestInterval - 0.000_001)
            if energyIsFull || restTimedOut {
                state.stopRest()
            }
        }

        if !state.isResting && remaining > 0 {
            apply(rules.awakeHourlyChange, for: remaining, to: &state)
        }
    }

    private func apply(
        _ hourlyChange: NeedChange,
        for duration: TimeInterval,
        to state: inout PetState
    ) {
        guard duration > 0 else { return }
        var needs = state.needs
        needs.apply(hourlyChange.scaled(by: duration / 3_600))
        state.setNeeds(needs)
    }

    private func evaluateAdultEvolution(_ state: inout PetState) {
        guard state.stage == .child,
              state.childAgeSeconds >= rules.adultChildAge,
              state.careMarks.count >= rules.adultCareMarkCount else {
            return
        }
        state.evolveToAdult()
    }
}
