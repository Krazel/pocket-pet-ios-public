import Foundation

public enum PocketPetPantryMetricID: String, CaseIterable, Hashable, Sendable {
    case hungerSatisfaction
    case health
    case joy
    case energy
    case clean

    public var title: String {
        switch self {
        case .hungerSatisfaction: return "Hunger"
        case .health: return "Health"
        case .joy: return "Joy"
        case .energy: return "Energy"
        case .clean: return "Clean"
        }
    }
}

public struct PocketPetPantryMetric: Equatable, Sendable {
    public let id: PocketPetPantryMetricID
    public let title: String
    public let value: Double

    public init(id: PocketPetPantryMetricID, value: Double) {
        self.id = id
        self.title = id.title
        self.value = min(100, max(0, value))
    }
}

public enum PocketPetPantryFoodAvailability: Equatable, Sendable {
    case available
    case outOfStock
}

public struct PocketPetPantryFood: Equatable, Sendable {
    public let id: ItemID
    public let name: String
    public let quantity: Int
    public let availability: PocketPetPantryFoodAvailability
    public let isSelected: Bool

    public var canOffer: Bool {
        isSelected && availability == .available
    }

    public init(
        id: ItemID,
        name: String,
        quantity: Int,
        isSelected: Bool
    ) {
        self.id = id
        self.name = name
        self.quantity = max(0, quantity)
        self.availability = quantity > 0 ? .available : .outOfStock
        self.isSelected = isSelected
    }
}

/// Foundation-only projection for the approved Garden Ribbon Pantry. It keeps
/// live values and product copy out of SwiftUI and SpriteKit without mutating
/// inventory, progression or any care rule.
public struct PocketPetPantryPresentation: Equatable, Sendable {
    public static let displayedFoodIDs: [ItemID] = [
        .dewberry,
        .seedBiscuit,
        .mossMelon,
    ]

    public let metrics: [PocketPetPantryMetric]
    public let level: Int
    public let sunSeeds: Int
    public let foods: [PocketPetPantryFood]

    public init(
        gameState: PocketPetGameState,
        selectedFoodID: ItemID?,
        catalog: PocketPetCatalog = .productBaseline
    ) {
        metrics = [
            PocketPetPantryMetric(
                id: .hungerSatisfaction,
                value: 100 - gameState.pet.needs.hunger
            ),
            PocketPetPantryMetric(
                id: .health,
                value: gameState.vitals.health
            ),
            PocketPetPantryMetric(
                id: .joy,
                value: gameState.pet.needs.happiness
            ),
            PocketPetPantryMetric(
                id: .energy,
                value: gameState.pet.needs.energy
            ),
            PocketPetPantryMetric(
                id: .clean,
                value: gameState.pet.needs.cleanliness
            ),
        ]
        level = gameState.progression.level
        sunSeeds = gameState.wallet.balance
        foods = Self.displayedFoodIDs.map { itemID in
            let definition = catalog.item(withID: itemID)
                ?? PocketPetCatalog.productBaseline.item(withID: itemID)
            return PocketPetPantryFood(
                id: itemID,
                name: definition?.name ?? itemID.rawValue,
                quantity: gameState.inventory.quantity(of: itemID),
                isSelected: selectedFoodID == itemID
            )
        }
    }
}

public enum PocketPetPantryProductMessage: Equatable, Sendable {
    case outOfStock(itemName: String)
    case tooFull
    case unavailableUntilHatched
    case persistenceFailure

    public var text: String {
        switch self {
        case let .outOfStock(itemName):
            return "\(itemName) is out of stock. Visit Market to get more."
        case .tooFull:
            return "Spriglet is too full for another snack right now."
        case .unavailableUntilHatched:
            return "Food will be available after Spriglet hatches."
        case .persistenceFailure:
            return "That snack could not be saved. Nothing was used. Please try again."
        }
    }

    public static func forInteractionError(
        _ error: PocketPetInteractionError,
        itemName: String
    ) -> PocketPetPantryProductMessage? {
        switch error {
        case .outOfStock:
            return .outOfStock(itemName: itemName)
        case .tooFull:
            return .tooFull
        case .unavailableUntilHatched:
            return .unavailableUntilHatched
        default:
            return nil
        }
    }
}

/// Deterministic data for equal-size Pantry captures. This fixture composes the
/// real aggregate and does not alter engine defaults or production start state.
public enum PocketPetPantryFixtures {
    public static let referenceDate = Date(timeIntervalSince1970: 1_735_689_600)

    public static let levelTwo = PocketPetGameState(
        pet: PetState(
            id: UUID(uuidString: "A2642983-3B83-4B15-B837-13194B6B1E04")!,
            name: "Pip",
            createdAt: referenceDate.addingTimeInterval(-7 * 24 * 3_600),
            lastReconciledAt: referenceDate,
            stage: .child,
            hatchedAt: referenceDate.addingTimeInterval(-6 * 24 * 3_600),
            childAgeSeconds: 2 * 24 * 3_600,
            needs: PetNeeds(
                hunger: 22,
                happiness: 52,
                energy: 48,
                cleanliness: 78
            )
        ),
        progression: BondProgression(totalXP: 100),
        wallet: SunSeedWallet(balance: 124),
        inventory: ItemInventory(
            stacks: [
                InventoryStack(itemID: .dewberry, quantity: 8),
                InventoryStack(itemID: .seedBiscuit, quantity: 5),
                InventoryStack(itemID: .mossMelon, quantity: 4),
            ]
        ),
        vitals: CompanionVitals(
            health: 76,
            fullness: 62,
            bodyComfort: 86
        ),
        location: .pantryNook
    )
}
