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

    @discardableResult
    mutating func remove(_ itemID: ItemID, quantity: Int) -> Bool {
        guard quantity > 0,
              let index = stacks.firstIndex(where: { $0.itemID == itemID }),
              stacks[index].quantity >= quantity else {
            return false
        }
        stacks[index].add(-quantity)
        if stacks[index].quantity == 0 {
            stacks.remove(at: index)
        }
        return true
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

    mutating func apply(_ effect: ItemEffect) {
        health = Self.clamp(health + effect.health)
        fullness = Self.clamp(fullness + effect.fullness)
        bodyComfort = Self.clamp(bodyComfort + effect.bodyComfort)
    }

    mutating func reconcile(
        elapsedHours: Double,
        wasResting: Bool,
        needs: PetNeeds,
        rules: PocketPetWellbeingRules
    ) {
        guard elapsedHours > 0 else { return }
        let fullnessRate = wasResting
            ? rules.restingFullnessLossPerHour
            : rules.awakeFullnessLossPerHour
        fullness = Self.clamp(fullness - fullnessRate * elapsedHours)

        let urgentCount = PetNeed.allCases.filter {
            needs.status(for: $0) == .urgent
        }.count
        if urgentCount > 0 {
            health = max(
                rules.recoverableHealthFloor,
                health
                    - Double(urgentCount)
                    * rules.healthLossPerUrgentNeedHour
                    * elapsedHours
            )
        } else if PetNeed.allCases.allSatisfy({
            needs.status(for: $0) == .comfortable
        }) {
            health = Self.clamp(
                health + rules.comfortableHealthRecoveryPerHour * elapsedHours
            )
        }

        if fullness > rules.overfullThreshold {
            bodyComfort = Self.clamp(
                bodyComfort - rules.overfullComfortLossPerHour * elapsedHours
            )
        } else {
            bodyComfort = Self.clamp(
                bodyComfort + rules.comfortRecoveryPerHour * elapsedHours
            )
        }
    }

    private static func clamp(_ value: Double) -> Double {
        min(100, max(0, value))
    }
}

public struct PocketPetWellbeingRules: Codable, Equatable, Sendable {
    public var maximumReconcileInterval: TimeInterval
    public var awakeFullnessLossPerHour: Double
    public var restingFullnessLossPerHour: Double
    public var recoverableHealthFloor: Double
    public var healthLossPerUrgentNeedHour: Double
    public var comfortableHealthRecoveryPerHour: Double
    public var overfullThreshold: Double
    public var overfullComfortLossPerHour: Double
    public var comfortRecoveryPerHour: Double

    public init(
        maximumReconcileInterval: TimeInterval,
        awakeFullnessLossPerHour: Double,
        restingFullnessLossPerHour: Double,
        recoverableHealthFloor: Double,
        healthLossPerUrgentNeedHour: Double,
        comfortableHealthRecoveryPerHour: Double,
        overfullThreshold: Double,
        overfullComfortLossPerHour: Double,
        comfortRecoveryPerHour: Double
    ) {
        self.maximumReconcileInterval = max(0, maximumReconcileInterval)
        self.awakeFullnessLossPerHour = max(0, awakeFullnessLossPerHour)
        self.restingFullnessLossPerHour = max(0, restingFullnessLossPerHour)
        self.recoverableHealthFloor = min(100, max(0, recoverableHealthFloor))
        self.healthLossPerUrgentNeedHour = max(0, healthLossPerUrgentNeedHour)
        self.comfortableHealthRecoveryPerHour = max(
            0,
            comfortableHealthRecoveryPerHour
        )
        self.overfullThreshold = min(100, max(0, overfullThreshold))
        self.overfullComfortLossPerHour = max(0, overfullComfortLossPerHour)
        self.comfortRecoveryPerHour = max(0, comfortRecoveryPerHour)
    }

    public static let productBaseline = PocketPetWellbeingRules(
        maximumReconcileInterval: 72 * 60 * 60,
        awakeFullnessLossPerHour: 4,
        restingFullnessLossPerHour: 2,
        recoverableHealthFloor: 10,
        healthLossPerUrgentNeedHour: 0.75,
        comfortableHealthRecoveryPerHour: 0.5,
        overfullThreshold: 90,
        overfullComfortLossPerHour: 1,
        comfortRecoveryPerHour: 0.5
    )
}

public enum PetSpaceID: String, Codable, CaseIterable, Hashable, Sendable {
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
    public static let currentSchemaVersion = 2

    public let gameSchemaVersion: Int
    public var pet: PetState
    public var progression: BondProgression
    public var wallet: SunSeedWallet
    public var inventory: ItemInventory
    public var vitals: CompanionVitals
    public var location: PetSpaceID
    public var highScores: [String: Int]
    public var keepsakes: KeepsakeCollection
    public private(set) var processedCommandIDs: [UUID]

    public init(
        pet: PetState,
        progression: BondProgression,
        wallet: SunSeedWallet,
        inventory: ItemInventory,
        vitals: CompanionVitals,
        location: PetSpaceID = .sunnyPatio,
        highScores: [String: Int] = [:],
        keepsakes: KeepsakeCollection = KeepsakeCollection(),
        processedCommandIDs: [UUID] = [],
        gameSchemaVersion: Int = PocketPetGameState.currentSchemaVersion
    ) {
        self.gameSchemaVersion = gameSchemaVersion
        self.pet = pet
        self.progression = progression
        self.wallet = wallet
        self.inventory = inventory
        self.vitals = vitals
        self.location = location
        self.highScores = highScores.mapValues { max(0, $0) }
        self.keepsakes = keepsakes
        var seenCommands = Set<UUID>()
        self.processedCommandIDs = processedCommandIDs.filter {
            seenCommands.insert($0).inserted
        }
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
                bodyComfort: 100
            ),
            keepsakes: KeepsakeCollection(migrating: pet)
        )
    }

    public func hasProcessed(_ commandID: UUID) -> Bool {
        processedCommandIDs.contains(commandID)
    }

    mutating func recordProcessed(_ commandID: UUID) {
        guard !hasProcessed(commandID) else { return }
        processedCommandIDs.append(commandID)
        if processedCommandIDs.count > 128 {
            processedCommandIDs.removeFirst(processedCommandIDs.count - 128)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case gameSchemaVersion
        case pet
        case progression
        case wallet
        case inventory
        case vitals
        case location
        case highScores
        case keepsakes
        case processedCommandIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedVersion = try container.decode(
            Int.self,
            forKey: .gameSchemaVersion
        )
        guard decodedVersion <= Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .gameSchemaVersion,
                in: container,
                debugDescription: "Unsupported future game-state schema."
            )
        }
        self.init(
            pet: try container.decode(PetState.self, forKey: .pet),
            progression: try container.decode(
                BondProgression.self,
                forKey: .progression
            ),
            wallet: try container.decode(SunSeedWallet.self, forKey: .wallet),
            inventory: try container.decode(ItemInventory.self, forKey: .inventory),
            vitals: try container.decode(CompanionVitals.self, forKey: .vitals),
            location: try container.decode(PetSpaceID.self, forKey: .location),
            highScores: try container.decodeIfPresent(
                [String: Int].self,
                forKey: .highScores
            ) ?? [:],
            keepsakes: try container.decodeIfPresent(
                KeepsakeCollection.self,
                forKey: .keepsakes
            ) ?? KeepsakeCollection(),
            processedCommandIDs: try container.decodeIfPresent(
                [UUID].self,
                forKey: .processedCommandIDs
            ) ?? [],
            gameSchemaVersion: Self.currentSchemaVersion
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(gameSchemaVersion, forKey: .gameSchemaVersion)
        try container.encode(pet, forKey: .pet)
        try container.encode(progression, forKey: .progression)
        try container.encode(wallet, forKey: .wallet)
        try container.encode(inventory, forKey: .inventory)
        try container.encode(vitals, forKey: .vitals)
        try container.encode(location, forKey: .location)
        try container.encode(highScores, forKey: .highScores)
        try container.encode(keepsakes, forKey: .keepsakes)
        try container.encode(processedCommandIDs, forKey: .processedCommandIDs)
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

public enum ArcadeGameID: String, Codable, CaseIterable, Sendable {
    case berryCatch = "berry-catch"
    case canopyClimb = "canopy-climb"
    case leafMemory = "leaf-memory"
}

public enum PocketPetInteractionError: Error, Equatable, Sendable {
    case unknownItem
    case notConsumable
    case outOfStock
    case tooFull
    case unavailableUntilHatched
    case notEquippable
    case notOwned
    case invalidScore
    case foodRequiresInventory
    case restRequiresNest
    case notEnoughEnergy
    case needsRecovery
}

/// Pure, deterministic transitions for the expanded care loop. Command IDs are
/// also recorded by the wallet, so replaying an interrupted command cannot
/// consume a second item or award its currency twice.
public struct PocketPetGameEngine: Sendable {
    public let catalog: PocketPetCatalog
    public let wellbeingRules: PocketPetWellbeingRules

    public init(
        catalog: PocketPetCatalog = .productBaseline,
        wellbeingRules: PocketPetWellbeingRules = .productBaseline
    ) {
        self.catalog = catalog
        self.wellbeingRules = wellbeingRules
    }

    public func reconcile(
        _ state: PocketPetGameState,
        using petEngine: PetEngine
    ) -> PocketPetGameState {
        let previousCheckpoint = state.pet.lastReconciledAt
        let wasResting = state.pet.isResting
        var candidate = state
        candidate.pet = petEngine.reconcile(candidate.pet)
        let elapsed = min(
            wellbeingRules.maximumReconcileInterval,
            max(
                0,
                candidate.pet.lastReconciledAt.timeIntervalSince(
                    previousCheckpoint
                )
            )
        )
        candidate.vitals.reconcile(
            elapsedHours: elapsed / 3_600,
            wasResting: wasResting,
            needs: candidate.pet.needs,
            rules: wellbeingRules
        )
        return candidate
    }

    public func consume(
        itemID: ItemID,
        commandID: UUID,
        in state: PocketPetGameState
    ) throws -> PocketPetGameState {
        guard let item = catalog.item(withID: itemID) else {
            throw PocketPetInteractionError.unknownItem
        }
        guard item.kind.isConsumable else {
            throw PocketPetInteractionError.notConsumable
        }
        guard state.pet.stage != .egg else {
            throw PocketPetInteractionError.unavailableUntilHatched
        }
        guard !state.hasProcessed(commandID),
              !state.wallet.hasProcessed(commandID) else {
            return state
        }
        guard state.inventory.quantity(of: itemID) > 0 else {
            throw PocketPetInteractionError.outOfStock
        }
        if item.kind == .food && state.vitals.fullness >= 95 {
            throw PocketPetInteractionError.tooFull
        }

        var candidate = state
        guard candidate.inventory.remove(itemID, quantity: 1) else {
            throw PocketPetInteractionError.outOfStock
        }

        var needs = candidate.pet.needs
        needs.apply(
            NeedChange(
                hunger: item.effect.hunger,
                happiness: item.effect.joy,
                energy: item.effect.energy,
                cleanliness: item.effect.cleanliness
            )
        )
        candidate.pet.setNeeds(needs)
        candidate.vitals.apply(item.effect)
        candidate.pet.recordCareAction(
            at: candidate.pet.lastReconciledAt,
            markWindow: PetRules.productBaseline.careMarkWindow
        )

        let xp = item.kind == .food ? 8 : 5
        let advance = candidate.progression.grantXP(xp)
        try candidate.wallet.apply(
            SunSeedTransaction(
                id: commandID,
                kind: .earn,
                amount: 2 + advance.sunSeedReward,
                reason: "care.consume.\(itemID.rawValue)"
            )
        )
        candidate.keepsakes.advance(.steadyCare)
        if item.kind == .food {
            candidate.keepsakes.advance(.firstSnack)
        }
        candidate.recordProcessed(commandID)
        return candidate
    }

    public func equip(
        itemID: ItemID,
        in state: PocketPetGameState
    ) throws -> PocketPetGameState {
        guard let item = catalog.item(withID: itemID) else {
            throw PocketPetInteractionError.unknownItem
        }
        guard let slot = item.equipmentSlot else {
            throw PocketPetInteractionError.notEquippable
        }
        guard state.inventory.owns(itemID) else {
            throw PocketPetInteractionError.notOwned
        }

        var candidate = state
        candidate.inventory.equip(itemID, in: slot)
        return candidate
    }

    public func performCare(
        _ action: CareAction,
        commandID: UUID,
        using petEngine: PetEngine,
        in state: PocketPetGameState
    ) throws -> PocketPetGameState {
        guard action != .feed else {
            throw PocketPetInteractionError.foodRequiresInventory
        }
        guard action != .rest else {
            throw PocketPetInteractionError.restRequiresNest
        }
        guard !state.hasProcessed(commandID),
              !state.wallet.hasProcessed(commandID) else {
            return state
        }

        var candidate = reconcile(state, using: petEngine)
        if action == .play {
            guard candidate.pet.needs.energy >= 15 else {
                throw PocketPetInteractionError.notEnoughEnergy
            }
            guard candidate.vitals.health >= 20 else {
                throw PocketPetInteractionError.needsRecovery
            }
        }
        candidate.pet = petEngine.perform(action, on: candidate.pet)
        if action == .play {
            candidate.vitals.apply(
                ItemEffect(fullness: -4, bodyComfort: 6)
            )
        } else if action == .clean {
            candidate.vitals.apply(ItemEffect(health: 1))
        }

        let advance = candidate.progression.grantXP(6)
        try candidate.wallet.apply(
            SunSeedTransaction(
                id: commandID,
                kind: .earn,
                amount: 2 + advance.sunSeedReward,
                reason: "care.action.\(action.rawValue)"
            )
        )
        candidate.keepsakes.advance(.steadyCare)
        if action == .play {
            candidate.keepsakes.advance(.playfulPal)
        } else if action == .clean {
            candidate.keepsakes.advance(.freshFriend)
        }
        candidate.recordProcessed(commandID)
        return candidate
    }

    public func performNestRest(
        commandID: UUID,
        using petEngine: PetEngine,
        in state: PocketPetGameState
    ) throws -> PocketPetGameState {
        guard !state.hasProcessed(commandID) else { return state }

        var candidate = reconcile(state, using: petEngine)
        let wasResting = candidate.pet.isResting
        candidate.pet = petEngine.perform(.rest, on: candidate.pet)
        if !wasResting && candidate.pet.isResting {
            let advance = candidate.progression.grantXP(2)
            try candidate.wallet.apply(
                SunSeedTransaction(
                    id: commandID,
                    kind: .earn,
                    amount: 1 + advance.sunSeedReward,
                    reason: "care.nest.start"
                )
            )
            candidate.keepsakes.advance(.steadyCare)
        }
        candidate.recordProcessed(commandID)
        return candidate
    }

    public func claimKeepsake(
        _ id: KeepsakeID,
        commandID: UUID,
        in state: PocketPetGameState
    ) throws -> PocketPetGameState {
        guard !state.hasProcessed(commandID),
              !state.wallet.hasProcessed(commandID) else {
            return state
        }
        let record = state.keepsakes.record(for: id)
        guard record.isUnlocked else { throw KeepsakeClaimError.locked }
        guard !record.isClaimed else { throw KeepsakeClaimError.alreadyClaimed }

        var candidate = state
        candidate.keepsakes.claim(id)
        try candidate.wallet.apply(
            SunSeedTransaction(
                id: commandID,
                kind: .earn,
                amount: id.sunSeedReward,
                reason: "keepsake.claim.\(id.rawValue)"
            )
        )
        candidate.recordProcessed(commandID)
        return candidate
    }

    public func recordArcadeResult(
        gameID: ArcadeGameID,
        score: Int,
        commandID: UUID,
        in state: PocketPetGameState
    ) throws -> PocketPetGameState {
        guard score >= 0 else {
            throw PocketPetInteractionError.invalidScore
        }
        guard state.pet.needs.energy >= 15 else {
            throw PocketPetInteractionError.notEnoughEnergy
        }
        guard state.vitals.health >= 20 else {
            throw PocketPetInteractionError.needsRecovery
        }
        guard !state.hasProcessed(commandID),
              !state.wallet.hasProcessed(commandID) else {
            return state
        }

        var candidate = state
        let previousHighScore = candidate.highScores[gameID.rawValue] ?? 0
        candidate.highScores[gameID.rawValue] = max(previousHighScore, score)
        var needs = candidate.pet.needs
        needs.apply(NeedChange(happiness: 4, energy: -6))
        candidate.pet.setNeeds(needs)
        candidate.vitals.apply(ItemEffect(fullness: -5, bodyComfort: 6))

        let xp = min(30, max(1, score / 250))
        let advance = candidate.progression.grantXP(xp)
        let playReward = min(50, max(1, score / 100))
        try candidate.wallet.apply(
            SunSeedTransaction(
                id: commandID,
                kind: .earn,
                amount: playReward + advance.sunSeedReward,
                reason: "arcade.result.\(gameID.rawValue)"
            )
        )
        candidate.keepsakes.advance(.arcadeHello)
        if gameID == .berryCatch {
            candidate.keepsakes.setProgress(.berryAce, to: score)
        }
        candidate.recordProcessed(commandID)
        return candidate
    }
}
