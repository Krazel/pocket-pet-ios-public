import Foundation
import XCTest
@testable import PocketPetCore

private struct FixedClock: PetClock {
    let now: Date
}

final class PetEngineTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testNameIsTrimmedAndSupportsUserPerceivedEmojiCharacters() throws {
        let egg = try engine(at: start).makeEgg(named: "  Pip 🐣  ")
        XCTAssertEqual(egg.name, "Pip 🐣")
    }

    func testNameRejectsEmptyLongAndControlCharacterValues() {
        XCTAssertThrowsError(try PetName("   ")) { error in
            XCTAssertEqual(error as? PetNameError, .empty)
        }
        XCTAssertThrowsError(try PetName("1234567890123")) { error in
            XCTAssertEqual(error as? PetNameError, .tooLong(maximum: 12))
        }
    }

    func testNameRejectsEverySupportedLineSeparator() {
        XCTAssertThrowsError(try PetName("Pip\nPet")) { error in
            XCTAssertEqual(error as? PetNameError, .containsControlCharacter)
        }
        XCTAssertThrowsError(try PetName("Pip\u{2028}Pet")) { error in
            XCTAssertEqual(error as? PetNameError, .containsControlCharacter)
        }
        XCTAssertThrowsError(try PetName("Pip\u{2029}Pet")) { error in
            XCTAssertEqual(error as? PetNameError, .containsControlCharacter)
        }
    }

    func testEggDoesNotDecayOrAccumulateChildAge() throws {
        let egg = try engine(at: start).makeEgg(named: "Pip")
        let later = start.addingTimeInterval(100 * 3_600)

        let reconciled = engine(at: later).reconcile(egg)

        XCTAssertEqual(reconciled.stage, .egg)
        XCTAssertEqual(reconciled.needs, PetRules.productBaseline.initialChildNeeds)
        XCTAssertEqual(reconciled.childAgeSeconds, 0)
        XCTAssertEqual(reconciled.lastReconciledAt, later)
    }

    func testExplicitHatchStartsChildAgeAndStoresUnseenMilestone() throws {
        let egg = try engine(at: start).makeEgg(named: "Pip")
        let hatchDate = start.addingTimeInterval(100 * 3_600)
        let oldEgg = engine(at: hatchDate).reconcile(egg)

        let child = engine(at: hatchDate).hatch(oldEgg)

        XCTAssertEqual(child.stage, .child)
        XCTAssertEqual(child.hatchedAt, hatchDate)
        XCTAssertEqual(child.childAgeSeconds, 0)
        XCTAssertEqual(child.needs, PetRules.productBaseline.initialChildNeeds)
        XCTAssertEqual(child.unseenMilestones, [.hatching])
    }

    func testHatchingIsIdempotent() throws {
        let child = try makeChild(at: start)
        let repeated = engine(at: start).hatch(child)

        XCTAssertEqual(repeated, child)
    }

    func testAwakeRatesMatchFourHourBaseline() throws {
        let child = try makeChild(at: start)
        let result = engine(at: start.addingTimeInterval(4 * 3_600)).reconcile(child)

        XCTAssertEqual(result.needs.hunger, 25, accuracy: 0.000_001)
        XCTAssertEqual(result.needs.happiness, 77, accuracy: 0.000_001)
        XCTAssertEqual(result.needs.energy, 76, accuracy: 0.000_001)
        XCTAssertEqual(result.needs.cleanliness, 77.5, accuracy: 0.000_001)
        XCTAssertEqual(result.childAgeSeconds, 4 * 3_600)
    }

    func testConditionUsesUrgentThresholdsAndSleepingPrecedence() {
        XCTAssertEqual(
            PetNeeds(hunger: 69.99, happiness: 30, energy: 30, cleanliness: 30)
                .condition(isResting: false),
            .comfortable
        )
        XCTAssertEqual(
            PetNeeds(hunger: 70, happiness: 100, energy: 100, cleanliness: 100)
                .condition(isResting: false),
            .needsCare
        )
        XCTAssertEqual(
            PetNeeds(hunger: 100, happiness: 0, energy: 0, cleanliness: 0)
                .condition(isResting: true),
            .sleeping
        )
    }

    func testNeedStatusesMatchEveryBoundary() {
        let needs = PetNeeds(
            hunger: 40,
            happiness: 60,
            energy: 30,
            cleanliness: 29.99
        )

        XCTAssertEqual(needs.status(for: .hunger), .attention)
        XCTAssertEqual(needs.status(for: .happiness), .comfortable)
        XCTAssertEqual(needs.status(for: .energy), .attention)
        XCTAssertEqual(needs.status(for: .cleanliness), .urgent)

        let hungerBoundaries = PetNeeds(
            hunger: 70,
            happiness: 100,
            energy: 100,
            cleanliness: 100
        )
        XCTAssertEqual(hungerBoundaries.status(for: .hunger), .urgent)
    }

    func testMostUrgentNeedUsesNormalizedSeverityAndStableTies() {
        let energyDominates = PetNeeds(
            hunger: 70,
            happiness: 20,
            energy: 0,
            cleanliness: 20
        )
        XCTAssertEqual(energyDominates.mostUrgentNeed, .energy)

        let stableTie = PetNeeds(
            hunger: 100,
            happiness: 0,
            energy: 0,
            cleanliness: 0
        )
        XCTAssertEqual(stableTie.mostUrgentNeed, .hunger)
    }

    func testBackwardClockCannotReverseOrDoubleApplyProgress() throws {
        let child = try makeChild(at: start)
        let future = start.addingTimeInterval(2 * 3_600)
        let advanced = engine(at: future).reconcile(child)

        let movedBackward = engine(at: start.addingTimeInterval(3_600))
            .reconcile(advanced)
        let returnedToCheckpoint = engine(at: future).reconcile(movedBackward)

        XCTAssertEqual(movedBackward, advanced)
        XCTAssertEqual(returnedToCheckpoint, advanced)
    }

    func testNeedDecayCapsAt72HoursWhileChildAgeUsesFullWallTime() throws {
        let child = try makeChild(at: start)
        let result = engine(at: start.addingTimeInterval(100 * 3_600))
            .reconcile(child)

        XCTAssertEqual(result.needs.hunger, 100, accuracy: 0.000_001)
        XCTAssertEqual(result.needs.happiness, 26, accuracy: 0.000_001)
        XCTAssertEqual(result.needs.energy, 8, accuracy: 0.000_001)
        XCTAssertEqual(result.needs.cleanliness, 35, accuracy: 0.000_001)
        XCTAssertEqual(result.childAgeSeconds, 100 * 3_600)
        XCTAssertEqual(result.stage, .child)
    }

    func testCareActionsChangeOnlyTheirTargetNeed() {
        let child = childState(
            needs: PetNeeds(hunger: 50, happiness: 50, energy: 50, cleanliness: 50)
        )

        let fed = engine(at: start).perform(.feed, on: child)
        XCTAssertEqual(fed.needs, PetNeeds(hunger: 15, happiness: 50, energy: 50, cleanliness: 50))

        let played = engine(at: start).perform(.play, on: child)
        XCTAssertEqual(played.needs, PetNeeds(hunger: 50, happiness: 80, energy: 50, cleanliness: 50))

        let cleaned = engine(at: start).perform(.clean, on: child)
        XCTAssertEqual(cleaned.needs, PetNeeds(hunger: 50, happiness: 50, energy: 50, cleanliness: 90))
    }

    func testRepeatedActionsClampWithoutHarmfulSideEffects() throws {
        var child = try makeChild(at: start)
        for _ in 0..<10 {
            child = engine(at: start).perform(.feed, on: child)
            child = engine(at: start).perform(.play, on: child)
            child = engine(at: start).perform(.clean, on: child)
        }

        XCTAssertEqual(child.needs.hunger, 0)
        XCTAssertEqual(child.needs.happiness, 100)
        XCTAssertEqual(child.needs.energy, 80)
        XCTAssertEqual(child.needs.cleanliness, 100)
        XCTAssertEqual(child.completedCareActions, 30)
    }

    func testCareActionOnSleepingPetWakesThenApplies() throws {
        let child = try makeChild(at: start)
        let resting = engine(at: start).perform(.rest, on: child)

        let fed = engine(at: start).perform(.feed, on: resting)

        XCTAssertFalse(fed.isResting)
        XCTAssertEqual(fed.needs.hunger, 0)
        XCTAssertEqual(fed.completedCareActions, 2)
    }

    func testRestActionTogglesRestAndWake() throws {
        let child = try makeChild(at: start)

        let resting = engine(at: start).perform(.rest, on: child)
        let awake = engine(at: start).perform(.rest, on: resting)

        XCTAssertTrue(resting.isResting)
        XCTAssertEqual(resting.condition, .sleeping)
        XCTAssertFalse(awake.isResting)
        XCTAssertEqual(awake.completedCareActions, 2)
    }

    func testRestAtFullEnergyAcknowledgesActionWithoutRemainingAsleep() {
        let fullEnergy = childState(
            needs: PetNeeds(hunger: 20, happiness: 80, energy: 100, cleanliness: 80)
        )

        let result = engine(at: start).perform(.rest, on: fullEnergy)

        XCTAssertFalse(result.isResting)
        XCTAssertEqual(result.completedCareActions, 1)
    }

    func testSleepingRatesApplyUntilEnergyReachesFull() throws {
        let child = try makeChild(at: start)
        let resting = engine(at: start).perform(.rest, on: child)
        let halfHour = engine(at: start.addingTimeInterval(1_800))
            .reconcile(resting)

        XCTAssertTrue(halfHour.isResting)
        XCTAssertEqual(halfHour.needs.hunger, 20.3125, accuracy: 0.000_001)
        XCTAssertEqual(halfHour.needs.happiness, 79.8125, accuracy: 0.000_001)
        XCTAssertEqual(halfHour.needs.energy, 92.5, accuracy: 0.000_001)
        XCTAssertEqual(halfHour.needs.cleanliness, 79.84375, accuracy: 0.000_001)
    }

    func testRemainingElapsedTimeProcessesAwakeAfterEnergyFills() throws {
        let child = try makeChild(at: start)
        let resting = engine(at: start).perform(.rest, on: child)
        let result = engine(at: start.addingTimeInterval(2 * 3_600))
            .reconcile(resting)

        XCTAssertFalse(result.isResting)
        XCTAssertEqual(result.needs.hunger, 22, accuracy: 0.000_001)
        XCTAssertEqual(result.needs.happiness, 78.8, accuracy: 0.000_001)
        XCTAssertEqual(result.needs.energy, 98.8, accuracy: 0.000_001)
        XCTAssertEqual(result.needs.cleanliness, 79, accuracy: 0.000_001)
    }

    func testRestTimesOutAtTwoHoursThenProcessesRemainingTimeAwake() {
        let lowEnergy = childState(
            needs: PetNeeds(hunger: 20, happiness: 80, energy: 0, cleanliness: 80)
        )
        let resting = engine(at: start).perform(.rest, on: lowEnergy)
        let result = engine(at: start.addingTimeInterval(3 * 3_600))
            .reconcile(resting)

        XCTAssertFalse(result.isResting)
        XCTAssertEqual(result.needs.hunger, 22.5, accuracy: 0.000_001)
        XCTAssertEqual(result.needs.happiness, 78.5, accuracy: 0.000_001)
        XCTAssertEqual(result.needs.energy, 49, accuracy: 0.000_001)
        XCTAssertEqual(result.needs.cleanliness, 78.75, accuracy: 0.000_001)
    }

    func testFailedMarkOpportunityDoesNotConsumeWindow() {
        let neglected = childState(
            needs: PetNeeds(hunger: 80, happiness: 20, energy: 80, cleanliness: 20)
        )

        let fed = engine(at: start).perform(.feed, on: neglected)
        let played = engine(at: start).perform(.play, on: fed)
        let cleaned = engine(at: start).perform(.clean, on: played)

        XCTAssertTrue(fed.careMarks.isEmpty)
        XCTAssertTrue(played.careMarks.isEmpty)
        XCTAssertEqual(cleaned.careMarks, [start])
        XCTAssertGreaterThanOrEqual(cleaned.needs.careQuality, 0.60)
    }

    func testCareQualityExactly60PercentEarnsMark() {
        let exactThreshold = childState(
            needs: PetNeeds(hunger: 40, happiness: 60, energy: 60, cleanliness: 60)
        )

        let result = engine(at: start).perform(.rest, on: exactThreshold)

        XCTAssertEqual(result.needs.careQuality, 0.60, accuracy: 0.000_001)
        XCTAssertEqual(result.careMarks, [start])
    }

    func testCareMarksUseRolling18HourWindow() throws {
        let child = try makeChild(at: start)
        let first = engine(at: start).perform(.feed, on: child)
        let insideWindow = engine(at: start.addingTimeInterval((18 * 3_600) - 1))
            .perform(.play, on: first)
        let atBoundary = engine(at: start.addingTimeInterval(18 * 3_600))
            .perform(.clean, on: insideWindow)

        XCTAssertEqual(first.careMarks.count, 1)
        XCTAssertEqual(insideWindow.careMarks.count, 1)
        XCTAssertEqual(atBoundary.careMarks.count, 2)
    }

    func testAdultRequires72ChildHoursAndThreeCareMarks() throws {
        var child = try makeChild(at: start)
        child = engine(at: start).markMilestoneSeen(.hatching, in: child)
        child = engine(at: start).perform(.feed, on: child)
        child = engine(at: start.addingTimeInterval(18 * 3_600)).perform(.play, on: child)
        child = engine(at: start.addingTimeInterval(36 * 3_600)).perform(.clean, on: child)

        let tooYoung = engine(at: start.addingTimeInterval(71 * 3_600))
            .reconcile(child)
        let adult = engine(at: start.addingTimeInterval(72 * 3_600))
            .reconcile(tooYoung)

        XCTAssertEqual(tooYoung.stage, .child)
        XCTAssertEqual(tooYoung.careMarks.count, 3)
        XCTAssertEqual(adult.stage, .adult)
        XCTAssertEqual(adult.unseenMilestones, [.adultEvolution])
    }

    func testAdultEligibilityIsEvaluatedImmediatelyAfterThirdAction() {
        let oldChild = PetState(
            name: "Pip",
            createdAt: start,
            lastReconciledAt: start.addingTimeInterval(72 * 3_600),
            stage: .child,
            hatchedAt: start,
            childAgeSeconds: 72 * 3_600,
            needs: PetNeeds(hunger: 20, happiness: 80, energy: 80, cleanliness: 80),
            careMarks: [start.addingTimeInterval(36 * 3_600), start.addingTimeInterval(54 * 3_600)]
        )

        let adult = engine(at: start.addingTimeInterval(72 * 3_600))
            .perform(.feed, on: oldChild)

        XCTAssertEqual(adult.careMarks.count, 3)
        XCTAssertEqual(adult.stage, .adult)
        XCTAssertTrue(adult.unseenMilestones.contains(.adultEvolution))
    }

    func testStagesAndCareMarksNeverRegress() throws {
        let adult = PetState(
            name: "Pip",
            createdAt: start,
            lastReconciledAt: start.addingTimeInterval(72 * 3_600),
            stage: .adult,
            hatchedAt: start,
            childAgeSeconds: 72 * 3_600,
            needs: PetNeeds(hunger: 100, happiness: 0, energy: 0, cleanliness: 0),
            careMarks: [start, start.addingTimeInterval(18 * 3_600), start.addingTimeInterval(36 * 3_600)]
        )
        let result = engine(at: start.addingTimeInterval(500 * 3_600))
            .reconcile(adult)

        XCTAssertEqual(result.stage, .adult)
        XCTAssertEqual(result.careMarks, adult.careMarks)
    }

    func testMilestoneRemainsUnseenUntilExplicitlyMarkedSeen() throws {
        let child = try makeChild(at: start)
        let reconciled = engine(at: start.addingTimeInterval(3_600)).reconcile(child)
        XCTAssertTrue(reconciled.unseenMilestones.contains(.hatching))

        let seen = engine(at: start).markMilestoneSeen(.hatching, in: reconciled)
        XCTAssertFalse(seen.unseenMilestones.contains(.hatching))
    }

    func testCareActionsDoNothingBeforeHatching() throws {
        let egg = try engine(at: start).makeEgg(named: "Pip")
        let result = engine(at: start).perform(.feed, on: egg)

        XCTAssertEqual(result, egg)
    }

    private func engine(at date: Date) -> PetEngine {
        PetEngine(clock: FixedClock(now: date))
    }

    private func makeChild(at date: Date) throws -> PetState {
        let currentEngine = engine(at: date)
        return currentEngine.hatch(try currentEngine.makeEgg(named: "Pip"))
    }

    private func childState(needs: PetNeeds) -> PetState {
        PetState(
            name: "Pip",
            createdAt: start,
            stage: .child,
            hatchedAt: start,
            needs: needs
        )
    }
}
