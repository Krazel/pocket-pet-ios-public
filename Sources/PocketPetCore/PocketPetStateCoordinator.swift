import Foundation

public enum PocketPetDestination: Equatable, Sendable {
    case onboarding
    case milestone(PetMilestone)
    case home
}

public struct PocketPetSnapshot: Equatable, Sendable {
    public let pet: PetState?
    public let preferences: PocketPetPreferences
    public let destination: PocketPetDestination

    public var reminderInvitationIsEligible: Bool {
        guard destination == .home,
              let pet,
              pet.stage != .egg,
              pet.completedCareActions >= 3,
              preferences.foregroundSessionCount >= 2,
              !preferences.reminderInvitationShown,
              !preferences.remindersEnabled else {
            return false
        }
        return true
    }
}

public enum PersistedPetEvent: Equatable, Sendable {
    case eggCreated
    case hatched
    case carePerformed(
        action: CareAction,
        earnedCareMark: Bool,
        evolvedToAdult: Bool
    )
    case milestoneAcknowledged(PetMilestone)
}

/// Returned only after the associated essential pet state has been saved.
public struct PersistedPetCommandResult: Equatable, Sendable {
    public let snapshot: PocketPetSnapshot
    public let event: PersistedPetEvent
}

public enum PocketPetCoordinatorError: Error, Equatable, Sendable {
    case petAlreadyExists
    case noPet
    case hatchingRequired
    case milestonePending(PetMilestone)
    case milestoneNotPending(PetMilestone)
}

/// The serialized app-facing owner of Pocket Pet's local domain state.
///
/// Every public result is constructed after required writes complete. A failed
/// save throws without advancing the coordinator's in-memory state, so visual
/// feedback cannot legitimately begin from an uncommitted command result.
public actor PocketPetStateCoordinator {
    private let engine: PetEngine
    private let petStore: any PetStatePersisting
    private let preferencesStore: any PocketPetPreferencesPersisting

    private var petState: PetState?
    private var preferences = PocketPetPreferences.defaults
    private var isLoaded = false
    private var isForegroundSessionActive = false

    public init(
        engine: PetEngine = PetEngine(),
        petStore: any PetStatePersisting,
        preferencesStore: any PocketPetPreferencesPersisting
    ) {
        self.engine = engine
        self.petStore = petStore
        self.preferencesStore = preferencesStore
    }

    /// Loads once, reconciles and persists progress, records at most one count
    /// for the current foreground activation, then exposes the snapshot.
    public func startForegroundSession() throws -> PocketPetSnapshot {
        try loadIfNeeded()
        try reconcileAndPersistPet()

        if !isForegroundSessionActive {
            var candidate = preferences
            candidate.incrementForegroundSessionCount()
            try preferencesStore.save(candidate)
            preferences = candidate
            isForegroundSessionActive = true
        }

        return makeSnapshot()
    }

    /// Reconciles and saves without changing the foreground-session count.
    public func refresh() throws -> PocketPetSnapshot {
        try loadIfNeeded()
        try reconcileAndPersistPet()
        return makeSnapshot()
    }

    /// Persists a final reconciled checkpoint before the app becomes inactive.
    public func endForegroundSession() throws -> PocketPetSnapshot {
        try loadIfNeeded()
        try reconcileAndPersistPet()
        isForegroundSessionActive = false
        return makeSnapshot()
    }

    public func createEgg(
        named name: String,
        id: UUID = UUID()
    ) throws -> PersistedPetCommandResult {
        try loadIfNeeded()
        guard petState == nil else {
            throw PocketPetCoordinatorError.petAlreadyExists
        }

        let candidate = try engine.makeEgg(named: name, id: id)
        try petStore.save(candidate)
        petState = candidate
        return makeCommandResult(event: .eggCreated)
    }

    public func hatch() throws -> PersistedPetCommandResult {
        try loadIfNeeded()
        guard let current = petState else {
            throw PocketPetCoordinatorError.noPet
        }
        guard current.stage == .egg else {
            throw PocketPetCoordinatorError.hatchingRequired
        }

        let candidate = engine.hatch(current)
        try petStore.save(candidate)
        petState = candidate
        return makeCommandResult(event: .hatched)
    }

    public func performCareAction(
        _ action: CareAction
    ) throws -> PersistedPetCommandResult {
        try loadIfNeeded()
        guard let current = petState else {
            throw PocketPetCoordinatorError.noPet
        }

        let reconciled = engine.reconcile(current)
        try petStore.save(reconciled)
        petState = reconciled

        if let milestone = Self.pendingMilestone(in: reconciled) {
            throw PocketPetCoordinatorError.milestonePending(milestone)
        }
        guard reconciled.stage != .egg else {
            throw PocketPetCoordinatorError.hatchingRequired
        }

        let previousMarkCount = reconciled.careMarks.count
        let previousStage = reconciled.stage
        let candidate = engine.perform(action, on: reconciled)
        try petStore.save(candidate)
        petState = candidate

        return makeCommandResult(
            event: .carePerformed(
                action: action,
                earnedCareMark: candidate.careMarks.count > previousMarkCount,
                evolvedToAdult: previousStage != .adult && candidate.stage == .adult
            )
        )
    }

    public func acknowledgeMilestone(
        _ milestone: PetMilestone
    ) throws -> PersistedPetCommandResult {
        try loadIfNeeded()
        guard let current = petState else {
            throw PocketPetCoordinatorError.noPet
        }

        let reconciled = engine.reconcile(current)
        guard Self.pendingMilestone(in: reconciled) == milestone else {
            try petStore.save(reconciled)
            petState = reconciled
            throw PocketPetCoordinatorError.milestoneNotPending(milestone)
        }

        let candidate = engine.markMilestoneSeen(milestone, in: reconciled)
        try petStore.save(candidate)
        petState = candidate
        return makeCommandResult(event: .milestoneAcknowledged(milestone))
    }

    public func updatePreferences(
        _ command: PocketPetPreferenceCommand
    ) throws -> PocketPetSnapshot {
        try loadIfNeeded()
        try reconcileAndPersistPet()

        var candidate = preferences
        candidate.apply(command)
        try preferencesStore.save(candidate)
        preferences = candidate
        return makeSnapshot()
    }

    private func loadIfNeeded() throws {
        guard !isLoaded else { return }

        let loadedPreferences: PocketPetPreferences
        if let existing = try preferencesStore.load() {
            loadedPreferences = existing
        } else {
            loadedPreferences = .defaults
            try preferencesStore.save(loadedPreferences)
        }
        let loadedPet = try petStore.load()

        preferences = loadedPreferences
        petState = loadedPet
        isLoaded = true
    }

    private func reconcileAndPersistPet() throws {
        guard let current = petState else { return }
        let candidate = engine.reconcile(current)
        try petStore.save(candidate)
        petState = candidate
    }

    private func makeSnapshot() -> PocketPetSnapshot {
        PocketPetSnapshot(
            pet: petState,
            preferences: preferences,
            destination: Self.destination(for: petState)
        )
    }

    private func makeCommandResult(
        event: PersistedPetEvent
    ) -> PersistedPetCommandResult {
        PersistedPetCommandResult(snapshot: makeSnapshot(), event: event)
    }

    private static func destination(for pet: PetState?) -> PocketPetDestination {
        guard let pet, pet.stage != .egg else { return .onboarding }
        if let milestone = pendingMilestone(in: pet) {
            return .milestone(milestone)
        }
        return .home
    }

    /// Hatching always precedes adult evolution if recovery exposes both.
    private static func pendingMilestone(in pet: PetState) -> PetMilestone? {
        if pet.unseenMilestones.contains(.hatching) { return .hatching }
        if pet.unseenMilestones.contains(.adultEvolution) {
            return .adultEvolution
        }
        return nil
    }
}
