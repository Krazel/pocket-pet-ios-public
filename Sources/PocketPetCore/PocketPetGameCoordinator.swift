import Foundation

public enum PocketPetGameCoordinatorError: Error, Equatable, Sendable {
    case noGame
    case notStarted
}

/// Serialized owner for the expanded aggregate. Every returned state has
/// already been saved; failed writes never replace the in-memory last-known
/// good state.
public actor PocketPetGameCoordinator {
    private let store: any PocketPetGameStatePersisting
    private let petEngine: PetEngine
    private let gameEngine: PocketPetGameEngine
    private let market: PocketPetMarket
    private var state: PocketPetGameState?

    public init(
        store: any PocketPetGameStatePersisting,
        petEngine: PetEngine = PetEngine(),
        gameEngine: PocketPetGameEngine = PocketPetGameEngine(),
        market: PocketPetMarket = PocketPetMarket()
    ) {
        self.store = store
        self.petEngine = petEngine
        self.gameEngine = gameEngine
        self.market = market
    }

    @discardableResult
    public func start() throws -> PocketPetGameState {
        guard let loaded = try store.load() else {
            throw PocketPetGameCoordinatorError.noGame
        }
        let reconciled = gameEngine.reconcile(loaded, using: petEngine)
        if reconciled != loaded {
            try store.save(reconciled)
        }
        state = reconciled
        return reconciled
    }

    public func snapshot() throws -> PocketPetGameState {
        guard let state else {
            throw PocketPetGameCoordinatorError.notStarted
        }
        return state
    }

    @discardableResult
    public func refresh() throws -> PocketPetGameState {
        let current = try snapshot()
        return try commit(gameEngine.reconcile(current, using: petEngine))
    }

    @discardableResult
    public func purchase(
        itemID: ItemID,
        transactionID: UUID
    ) throws -> PocketPetGameState {
        try commit(
            market.purchase(
                itemID: itemID,
                transactionID: transactionID,
                in: try snapshot()
            )
        )
    }

    @discardableResult
    public func consume(
        itemID: ItemID,
        commandID: UUID
    ) throws -> PocketPetGameState {
        try commit(
            gameEngine.consume(
                itemID: itemID,
                commandID: commandID,
                in: try snapshot()
            )
        )
    }

    @discardableResult
    public func equip(itemID: ItemID) throws -> PocketPetGameState {
        try commit(gameEngine.equip(itemID: itemID, in: try snapshot()))
    }

    @discardableResult
    public func performCare(
        _ action: CareAction,
        commandID: UUID
    ) throws -> PocketPetGameState {
        try commit(
            gameEngine.performCare(
                action,
                commandID: commandID,
                using: petEngine,
                in: try snapshot()
            )
        )
    }

    @discardableResult
    public func performNestRest(commandID: UUID) throws -> PocketPetGameState {
        try commit(
            gameEngine.performNestRest(
                commandID: commandID,
                using: petEngine,
                in: try snapshot()
            )
        )
    }

    @discardableResult
    public func recordArcadeResult(
        gameID: ArcadeGameID,
        score: Int,
        commandID: UUID
    ) throws -> PocketPetGameState {
        try commit(
            gameEngine.recordArcadeResult(
                gameID: gameID,
                score: score,
                commandID: commandID,
                in: try snapshot()
            )
        )
    }

    @discardableResult
    public func claimKeepsake(
        _ id: KeepsakeID,
        commandID: UUID
    ) throws -> PocketPetGameState {
        try commit(
            gameEngine.claimKeepsake(
                id,
                commandID: commandID,
                in: try snapshot()
            )
        )
    }

    private func commit(
        _ candidate: PocketPetGameState
    ) throws -> PocketPetGameState {
        guard candidate != state else { return candidate }
        try store.save(candidate)
        state = candidate
        return candidate
    }
}
