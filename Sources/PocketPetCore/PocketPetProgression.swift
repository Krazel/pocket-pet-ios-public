import Foundation

public struct ItemID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension ItemID {
    static let dewberry = ItemID(rawValue: "food.dewberry")
    static let seedBiscuit = ItemID(rawValue: "food.seed-biscuit")
    static let mossMelon = ItemID(rawValue: "food.moss-melon")
    static let mendDew = ItemID(rawValue: "tonic.mend-dew")
    static let brightSap = ItemID(rawValue: "tonic.bright-sap")
    static let restingTea = ItemID(rawValue: "tonic.resting-tea")
    static let pollenBall = ItemID(rawValue: "toy.pollen-ball")
    static let leafCap = ItemID(rawValue: "wearable.leaf-cap")
    static let fernWallpaper = ItemID(rawValue: "decor.fern-wallpaper")
    static let basicBrush = ItemID(rawValue: "tool.basic-brush")
    static let sunnyPatio = ItemID(rawValue: "decor.sunny-patio")
}

public enum StoreItemKind: String, Codable, CaseIterable, Sendable {
    case food
    case tonic
    case toy
    case wearable
    case decor
    case tool

    public var isConsumable: Bool {
        self == .food || self == .tonic
    }
}

public enum EquipmentSlot: String, Codable, CaseIterable, Sendable {
    case headwear
    case toy
    case wallpaper
    case washTool
}

public struct ItemEffect: Codable, Equatable, Sendable {
    public var hunger: Double
    public var health: Double
    public var joy: Double
    public var energy: Double
    public var cleanliness: Double
    public var fullness: Double
    public var bodyComfort: Double

    public init(
        hunger: Double = 0,
        health: Double = 0,
        joy: Double = 0,
        energy: Double = 0,
        cleanliness: Double = 0,
        fullness: Double = 0,
        bodyComfort: Double = 0
    ) {
        self.hunger = hunger
        self.health = health
        self.joy = joy
        self.energy = energy
        self.cleanliness = cleanliness
        self.fullness = fullness
        self.bodyComfort = bodyComfort
    }
}

public struct StoreItemDefinition: Codable, Equatable, Sendable {
    public let id: ItemID
    public let name: String
    public let kind: StoreItemKind
    public let price: Int
    public let requiredLevel: Int
    public let equipmentSlot: EquipmentSlot?
    public let effect: ItemEffect

    public init(
        id: ItemID,
        name: String,
        kind: StoreItemKind,
        price: Int,
        requiredLevel: Int = 1,
        equipmentSlot: EquipmentSlot? = nil,
        effect: ItemEffect = ItemEffect()
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.price = max(0, price)
        self.requiredLevel = max(1, requiredLevel)
        self.equipmentSlot = equipmentSlot
        self.effect = effect
    }
}

public struct PocketPetCatalog: Equatable, Sendable {
    public let items: [StoreItemDefinition]

    public init(items: [StoreItemDefinition]) {
        var seen = Set<ItemID>()
        self.items = items.filter { seen.insert($0.id).inserted }
    }

    public func item(withID id: ItemID) -> StoreItemDefinition? {
        items.first { $0.id == id }
    }

    public static let productBaseline = PocketPetCatalog(items: [
        StoreItemDefinition(
            id: .dewberry,
            name: "Dewberry",
            kind: .food,
            price: 4,
            effect: ItemEffect(hunger: -15, health: 1, fullness: 15)
        ),
        StoreItemDefinition(
            id: .seedBiscuit,
            name: "Seed Biscuit",
            kind: .food,
            price: 7,
            requiredLevel: 2,
            effect: ItemEffect(hunger: -24, joy: 4, fullness: 24)
        ),
        StoreItemDefinition(
            id: .mossMelon,
            name: "Moss Melon",
            kind: .food,
            price: 11,
            requiredLevel: 4,
            effect: ItemEffect(hunger: -36, health: 2, fullness: 36)
        ),
        StoreItemDefinition(
            id: .mendDew,
            name: "Mend Dew",
            kind: .tonic,
            price: 10,
            effect: ItemEffect(health: 25)
        ),
        StoreItemDefinition(
            id: .brightSap,
            name: "Bright Sap",
            kind: .tonic,
            price: 24,
            requiredLevel: 3,
            effect: ItemEffect(health: 10, joy: 20)
        ),
        StoreItemDefinition(
            id: .restingTea,
            name: "Resting Tea",
            kind: .tonic,
            price: 30,
            requiredLevel: 5,
            effect: ItemEffect(energy: 50)
        ),
        StoreItemDefinition(
            id: .pollenBall,
            name: "Pollen Ball",
            kind: .toy,
            price: 40,
            equipmentSlot: .toy
        ),
        StoreItemDefinition(
            id: .leafCap,
            name: "Leaf Cap",
            kind: .wearable,
            price: 75,
            requiredLevel: 3,
            equipmentSlot: .headwear
        ),
        StoreItemDefinition(
            id: .fernWallpaper,
            name: "Fern Wallpaper",
            kind: .decor,
            price: 90,
            requiredLevel: 4,
            equipmentSlot: .wallpaper
        ),
    ])
}

public struct InventoryStack: Codable, Equatable, Sendable {
    public let itemID: ItemID
    public private(set) var quantity: Int

    public init(itemID: ItemID, quantity: Int) {
        self.itemID = itemID
        self.quantity = max(0, quantity)
    }

    mutating func add(_ amount: Int) {
        quantity = max(0, quantity + amount)
    }
}

public struct EquippedItem: Codable, Equatable, Sendable {
    public let slot: EquipmentSlot
    public let itemID: ItemID

    public init(slot: EquipmentSlot, itemID: ItemID) {
        self.slot = slot
        self.itemID = itemID
    }
}

public struct ItemInventory: Codable, Equatable, Sendable {
    public private(set) var stacks: [InventoryStack]
    public private(set) var ownedItems: [ItemID]
    public private(set) var equippedItems: [EquippedItem]

    public init(
        stacks: [InventoryStack] = [],
        ownedItems: [ItemID] = [],
        equippedItems: [EquippedItem] = []
    ) {
        self.stacks = []
        self.ownedItems = []
        self.equippedItems = []
        for stack in stacks where stack.quantity > 0 {
            add(stack.itemID, quantity: stack.quantity)
        }
        var seenItems = Set<ItemID>()
        self.ownedItems = ownedItems.filter { seenItems.insert($0).inserted }
        var seenSlots = Set<EquipmentSlot>()
        self.equippedItems = equippedItems.filter {
            seenSlots.insert($0.slot).inserted
        }
    }

    public func quantity(of itemID: ItemID) -> Int {
        stacks.first { $0.itemID == itemID }?.quantity ?? 0
    }

    public func owns(_ itemID: ItemID) -> Bool {
        ownedItems.contains(itemID)
    }

    public func equippedItem(in slot: EquipmentSlot) -> ItemID? {
        equippedItems.first { $0.slot == slot }?.itemID
    }

    mutating func add(_ itemID: ItemID, quantity: Int) {
        guard quantity > 0 else { return }
        if let index = stacks.firstIndex(where: { $0.itemID == itemID }) {
            stacks[index].add(quantity)
        } else {
            stacks.append(InventoryStack(itemID: itemID, quantity: quantity))
        }
    }

    mutating func own(_ itemID: ItemID) {
        guard !ownedItems.contains(itemID) else { return }
        ownedItems.append(itemID)
    }

    mutating func equip(_ itemID: ItemID, in slot: EquipmentSlot) {
        equippedItems.removeAll { $0.slot == slot }
        equippedItems.append(EquippedItem(slot: slot, itemID: itemID))
    }
}

public enum SunSeedTransactionKind: String, Codable, Sendable {
    case earn
    case spend
}

public struct SunSeedTransaction: Codable, Equatable, Sendable {
    public let id: UUID
    public let kind: SunSeedTransactionKind
    public let amount: Int
    public let reason: String

    public init(
        id: UUID = UUID(),
        kind: SunSeedTransactionKind,
        amount: Int,
        reason: String
    ) {
        self.id = id
        self.kind = kind
        self.amount = amount
        self.reason = reason
    }
}

public enum SunSeedWalletError: Error, Equatable, Sendable {
    case invalidAmount
    case insufficientBalance
}

public struct SunSeedWallet: Codable, Equatable, Sendable {
    public private(set) var balance: Int
    public private(set) var processedTransactionIDs: [UUID]

    public init(balance: Int = 0, processedTransactionIDs: [UUID] = []) {
        self.balance = max(0, balance)
        var seen = Set<UUID>()
        self.processedTransactionIDs = processedTransactionIDs.filter {
            seen.insert($0).inserted
        }
    }

    public func hasProcessed(_ transactionID: UUID) -> Bool {
        processedTransactionIDs.contains(transactionID)
    }

    @discardableResult
    public mutating func apply(_ transaction: SunSeedTransaction) throws -> Bool {
        guard transaction.amount > 0 else {
            throw SunSeedWalletError.invalidAmount
        }
        guard !hasProcessed(transaction.id) else { return false }

        switch transaction.kind {
        case .earn:
            balance += transaction.amount
        case .spend:
            guard balance >= transaction.amount else {
                throw SunSeedWalletError.insufficientBalance
            }
            balance -= transaction.amount
        }
        processedTransactionIDs.append(transaction.id)
        if processedTransactionIDs.count > 128 {
            processedTransactionIDs.removeFirst(
                processedTransactionIDs.count - 128
            )
        }
        return true
    }
}

public struct LevelAdvance: Equatable, Sendable {
    public let previousLevel: Int
    public let currentLevel: Int
    public let sunSeedReward: Int

    public var levelsGained: Int {
        currentLevel - previousLevel
    }
}

public struct BondProgression: Codable, Equatable, Sendable {
    public private(set) var totalXP: Int
    public private(set) var level: Int

    public init(totalXP: Int = 0) {
        self.totalXP = max(0, totalXP)
        self.level = Self.level(forTotalXP: self.totalXP)
    }

    @discardableResult
    public mutating func grantXP(_ amount: Int) -> LevelAdvance {
        let previousLevel = level
        totalXP += max(0, amount)
        level = Self.level(forTotalXP: totalXP)
        return LevelAdvance(
            previousLevel: previousLevel,
            currentLevel: level,
            sunSeedReward: max(0, level - previousLevel) * 25
        )
    }

    public static func totalXPRequired(forLevel level: Int) -> Int {
        let normalizedLevel = max(1, level)
        return 50 * (normalizedLevel - 1) * normalizedLevel
    }

    private static func level(forTotalXP totalXP: Int) -> Int {
        var candidate = 1
        while totalXP >= totalXPRequired(forLevel: candidate + 1) {
            candidate += 1
        }
        return candidate
    }
}

public struct CompanionVitals: Codable, Equatable, Sendable {
    public private(set) var health: Double
    public private(set) var fullness: Double
    public private(set) var bodyComfort: Double

    public init(health: Double, fullness: Double, bodyComfort: Double) {
        self.health = Self.clamp(health)
        self.fullness = Self.clamp(fullness)
        self.bodyComfort = Self.clamp(bodyComfort)
    }

    private static func clamp(_ value: Double) -> Double {
        min(100, max(0, value))
    }
}

public enum PetSpaceID: String, Codable, CaseIterable, Sendable {
    case sunnyPatio
    case pantryNook
    case washNook
    case greenhouseLab
    case playLoft
    case nestRoom
    case gardenPath
    case rollingShed
}

public struct PocketPetGameState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public var pet: PetState
    public var progression: BondProgression
    public var wallet: SunSeedWallet
    public var inventory: ItemInventory
    public var vitals: CompanionVitals
    public var location: PetSpaceID
    public var highScores: [String: Int]

    public init(
        pet: PetState,
        progression: BondProgression,
        wallet: SunSeedWallet,
        inventory: ItemInventory,
        vitals: CompanionVitals,
        location: PetSpaceID = .sunnyPatio,
        highScores: [String: Int] = [:],
        schemaVersion: Int = PocketPetGameState.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.pet = pet
        self.progression = progression
        self.wallet = wallet
        self.inventory = inventory
        self.vitals = vitals
        self.location = location
        self.highScores = highScores.mapValues { max(0, $0) }
    }

    public init(migrating pet: PetState) {
        let stageXP: Int
        switch pet.stage {
        case .egg: stageXP = 0
        case .child: stageXP = 50
        case .adult: stageXP = 250
        }
        let progression = BondProgression(
            totalXP: stageXP
                + pet.completedCareActions * 12
                + pet.careMarks.count * 25
        )
        self.init(
            pet: pet,
            progression: progression,
            wallet: SunSeedWallet(balance: 100 + progression.level * 20),
            inventory: ItemInventory(
                stacks: [InventoryStack(itemID: .dewberry, quantity: 3)],
                ownedItems: [.pollenBall, .basicBrush, .sunnyPatio],
                equippedItems: [
                    EquippedItem(slot: .toy, itemID: .pollenBall),
                    EquippedItem(slot: .washTool, itemID: .basicBrush),
                    EquippedItem(slot: .wallpaper, itemID: .sunnyPatio),
                ]
            ),
            vitals: CompanionVitals(
                health: 100,
                fullness: 100 - pet.needs.hunger,
                bodyComfort: 50
            )
        )
    }
}

public enum PocketPetMarketError: Error, Equatable, Sendable {
    case unknownItem
    case levelLocked(required: Int)
    case alreadyOwned
    case insufficientSunSeeds
}

public struct PocketPetMarket: Sendable {
    public let catalog: PocketPetCatalog

    public init(catalog: PocketPetCatalog = .productBaseline) {
        self.catalog = catalog
    }

    public func purchase(
        itemID: ItemID,
        transactionID: UUID,
        in state: PocketPetGameState
    ) throws -> PocketPetGameState {
        guard let item = catalog.item(withID: itemID) else {
            throw PocketPetMarketError.unknownItem
        }
        guard state.progression.level >= item.requiredLevel else {
            throw PocketPetMarketError.levelLocked(required: item.requiredLevel)
        }
        guard !state.wallet.hasProcessed(transactionID) else { return state }
        if !item.kind.isConsumable && state.inventory.owns(itemID) {
            throw PocketPetMarketError.alreadyOwned
        }

        var candidate = state
        do {
            try candidate.wallet.apply(
                SunSeedTransaction(
                    id: transactionID,
                    kind: .spend,
                    amount: item.price,
                    reason: "market.purchase.\(itemID.rawValue)"
                )
            )
        } catch SunSeedWalletError.insufficientBalance {
            throw PocketPetMarketError.insufficientSunSeeds
        }

        if item.kind.isConsumable {
            candidate.inventory.add(itemID, quantity: 1)
        } else {
            candidate.inventory.own(itemID)
        }
        return candidate
    }
}
