import Foundation

/// Migration-safe app owner for the 0.2 aggregate. It exposes the established
/// snapshot and event API so onboarding, milestones and reminders keep their
/// behavior while Home gains inventory, progression and room systems.
public actor PocketPetExpandedStateCoordinator {
    private let petEngine: PetEngine
    private let gameEngine: PocketPetGameEngine
    private let gameStore: any PocketPetGameStatePersisting
    private let preferencesStore: any PocketPetPreferencesPersisting

    private var gameState: PocketPetGameState?
    private var preferences = PocketPetPreferences.defaults
    private var isLoaded = false
    private var isForegroundSessionActive = false

    public init(
        petEngine: PetEngine = PetEngine(),
        gameEngine: PocketPetGameEngine = PocketPetGameEngine(),
        gameStore: any PocketPetGameStatePersisting,
        preferencesStore: any PocketPetPreferencesPersisting
    ) {
        self.petEngine = petEngine
        self.gameEngine = gameEngine
        self.gameStore = gameStore
        self.preferencesStore = preferencesStore
    }

    public func startForegroundSession() throws -> PocketPetSnapshot {
        try loadIfNeeded()
        try reconcileAndPersistGame()
        if !isForegroundSessionActive {
            var candidate = preferences
            candidate.incrementForegroundSessionCount()
            try preferencesStore.save(candidate)
            preferences = candidate
            isForegroundSessionActive = true
        }
        return makeSnapshot()
    }

    public func refresh() throws -> PocketPetSnapshot {
        try loadIfNeeded()
        try reconcileAndPersistGame()
        return makeSnapshot()
    }

    public func endForegroundSession() throws -> PocketPetSnapshot {
        try loadIfNeeded()
        try reconcileAndPersistGame()
        isForegroundSessionActive = false
        return makeSnapshot()
    }

    public func createEgg(
        named name: String,
        id: UUID = UUID()
    ) throws -> PersistedPetCommandResult {
        try loadIfNeeded()
        guard gameState == nil else {
            throw PocketPetCoordinatorError.petAlreadyExists
        }
        let pet = try petEngine.makeEgg(named: name, id: id)
        let candidate = PocketPetGameState(migrating: pet)
        try gameStore.save(candidate)
        gameState = candidate
        return makeCommandResult(event: .eggCreated)
    }

    public func hatch() throws -> PersistedPetCommandResult {
        try loadIfNeeded()
        guard var candidate = gameState else {
            throw PocketPetCoordinatorError.noPet
        }
        guard candidate.pet.stage == .egg else {
            throw PocketPetCoordinatorError.hatchingRequired
        }
        candidate.pet = petEngine.hatch(candidate.pet)
        try gameStore.save(candidate)
        gameState = candidate
        return makeCommandResult(event: .hatched)
    }

    public func performCareAction(
        _ action: CareAction
    ) throws -> PersistedPetCommandResult {
        try loadIfNeeded()
        guard let current = gameState else {
            throw PocketPetCoordinatorError.noPet
        }
        let reconciled = gameEngine.reconcile(current, using: petEngine)
        try gameStore.save(reconciled)
        gameState = reconciled

        if let milestone = Self.pendingMilestone(in: reconciled.pet) {
            throw PocketPetCoordinatorError.milestonePending(milestone)
        }
        guard reconciled.pet.stage != .egg else {
            throw PocketPetCoordinatorError.hatchingRequired
        }

        let previousMarkCount = reconciled.pet.careMarks.count
        let previousStage = reconciled.pet.stage
        var candidate = reconciled
        candidate.pet = petEngine.perform(action, on: reconciled.pet)
        try gameStore.save(candidate)
        gameState = candidate
        return makeCommandResult(
            event: .carePerformed(
                action: action,
                earnedCareMark: candidate.pet.careMarks.count > previousMarkCount,
                evolvedToAdult: previousStage != .adult
                    && candidate.pet.stage == .adult
            )
        )
    }

    public func consume(
        itemID: ItemID,
        commandID: UUID
    ) throws -> PocketPetSnapshot {
        try loadIfNeeded()
        guard let current = gameState else {
            throw PocketPetCoordinatorError.noPet
        }
        let candidate = try gameEngine.consume(
            itemID: itemID,
            commandID: commandID,
            in: gameEngine.reconcile(current, using: petEngine)
        )
        try gameStore.save(candidate)
        gameState = candidate
        return makeSnapshot()
    }

    public func purchase(
        itemID: ItemID,
        transactionID: UUID,
        market: PocketPetMarket = PocketPetMarket()
    ) throws -> PocketPetSnapshot {
        try loadIfNeeded()
        guard let current = gameState else {
            throw PocketPetCoordinatorError.noPet
        }
        let candidate = try market.purchase(
            itemID: itemID,
            transactionID: transactionID,
            in: current
        )
        try gameStore.save(candidate)
        gameState = candidate
        return makeSnapshot()
    }

    public func equip(itemID: ItemID) throws -> PocketPetSnapshot {
        try loadIfNeeded()
        guard let current = gameState else {
            throw PocketPetCoordinatorError.noPet
        }
        let candidate = try gameEngine.equip(itemID: itemID, in: current)
        try gameStore.save(candidate)
        gameState = candidate
        return makeSnapshot()
    }

    public func acknowledgeMilestone(
        _ milestone: PetMilestone
    ) throws -> PersistedPetCommandResult {
        try loadIfNeeded()
        guard var candidate = gameState else {
            throw PocketPetCoordinatorError.noPet
        }
        candidate = gameEngine.reconcile(candidate, using: petEngine)
        guard Self.pendingMilestone(in: candidate.pet) == milestone else {
            try gameStore.save(candidate)
            gameState = candidate
            throw PocketPetCoordinatorError.milestoneNotPending(milestone)
        }
        candidate.pet = petEngine.markMilestoneSeen(milestone, in: candidate.pet)
        try gameStore.save(candidate)
        gameState = candidate
        return makeCommandResult(event: .milestoneAcknowledged(milestone))
    }

    public func updatePreferences(
        _ command: PocketPetPreferenceCommand
    ) throws -> PocketPetSnapshot {
        try loadIfNeeded()
        try reconcileAndPersistGame()
        var candidate = preferences
        candidate.apply(command)
        try preferencesStore.save(candidate)
        preferences = candidate
        return makeSnapshot()
    }

    private func loadIfNeeded() throws {
        guard !isLoaded else { return }
        if let existing = try preferencesStore.load() {
            preferences = existing
        } else {
            try preferencesStore.save(preferences)
        }
        gameState = try gameStore.load()
        isLoaded = true
    }

    private func reconcileAndPersistGame() throws {
        guard let current = gameState else { return }
        let candidate = gameEngine.reconcile(current, using: petEngine)
        try gameStore.save(candidate)
        gameState = candidate
    }

    private func makeSnapshot() -> PocketPetSnapshot {
        let pet = gameState?.pet
        return PocketPetSnapshot(
            pet: pet,
            gameState: gameState,
            preferences: preferences,
            destination: Self.destination(for: pet)
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

    private static func pendingMilestone(in pet: PetState) -> PetMilestone? {
        if pet.unseenMilestones.contains(.hatching) { return .hatching }
        if pet.unseenMilestones.contains(.adultEvolution) {
            return .adultEvolution
        }
        return nil
    }
}
