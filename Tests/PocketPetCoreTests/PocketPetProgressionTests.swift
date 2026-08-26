import Foundation
import XCTest
@testable import PocketPetCore

final class PocketPetProgressionTests: XCTestCase {
    func testLegacyMigrationPreservesPetAndAddsRecoverableStarterState() {
        let pet = makeAdult(completedCareActions: 24, careMarkCount: 3)

        let game = PocketPetGameState(migrating: pet)

        XCTAssertEqual(game.pet, pet)
        XCTAssertGreaterThan(game.progression.level, 1)
        XCTAssertGreaterThan(game.wallet.balance, 100)
        XCTAssertEqual(game.inventory.quantity(of: .dewberry), 3)
        XCTAssertTrue(game.inventory.owns(.pollenBall))
        XCTAssertEqual(game.inventory.equippedItem(in: .toy), .pollenBall)
        XCTAssertEqual(game.vitals.health, 100)
        XCTAssertEqual(game.vitals.fullness, 80)
        XCTAssertEqual(game.location, .sunnyPatio)
    }

    func testBondProgressionCrossesMultipleLevelsDeterministically() {
        var progression = BondProgression()

        let advance = progression.grantXP(650)

        XCTAssertEqual(advance.previousLevel, 1)
        XCTAssertEqual(advance.currentLevel, 4)
        XCTAssertEqual(advance.levelsGained, 3)
        XCTAssertEqual(advance.sunSeedReward, 75)
        XCTAssertEqual(progression.totalXP, 650)
    }

    func testWalletAppliesATransactionOnlyOnce() throws {
        let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let transaction = SunSeedTransaction(
            id: id,
            kind: .earn,
            amount: 40,
            reason: "test"
        )
        var wallet = SunSeedWallet(balance: 10)

        XCTAssertTrue(try wallet.apply(transaction))
        XCTAssertFalse(try wallet.apply(transaction))
        XCTAssertEqual(wallet.balance, 50)
    }

    func testWalletRejectsSpendWithoutChangingBalance() {
        var wallet = SunSeedWallet(balance: 5)
        let original = wallet

        XCTAssertThrowsError(
            try wallet.apply(
                SunSeedTransaction(kind: .spend, amount: 6, reason: "test")
            )
        ) { error in
            XCTAssertEqual(error as? SunSeedWalletError, .insufficientBalance)
        }
        XCTAssertEqual(wallet, original)
    }

    func testMarketRejectsLevelLockedItemWithoutMutation() {
        let state = PocketPetGameState(migrating: makeChild())
        let market = PocketPetMarket()

        XCTAssertThrowsError(
            try market.purchase(
                itemID: .fernWallpaper,
                transactionID: UUID(),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? PocketPetMarketError, .levelLocked(required: 4))
        }
    }

    func testConsumablePurchaseIsAtomicAndIdempotent() throws {
        let state = PocketPetGameState(migrating: makeChild())
        let market = PocketPetMarket()
        let transactionID = UUID(
            uuidString: "22222222-2222-2222-2222-222222222222"
        )!

        let purchased = try market.purchase(
            itemID: .dewberry,
            transactionID: transactionID,
            in: state
        )
        let replayed = try market.purchase(
            itemID: .dewberry,
            transactionID: transactionID,
            in: purchased
        )

        XCTAssertEqual(purchased.inventory.quantity(of: .dewberry), 4)
        XCTAssertEqual(purchased.wallet.balance, state.wallet.balance - 4)
        XCTAssertEqual(replayed, purchased)
    }

    func testDurablePurchaseBecomesOwnedAndCannotBeBoughtTwice() throws {
        var progression = BondProgression()
        progression.grantXP(300)
        let base = PocketPetGameState(
            pet: makeChild(),
            progression: progression,
            wallet: SunSeedWallet(balance: 200),
            inventory: ItemInventory(),
            vitals: CompanionVitals(health: 100, fullness: 80, bodyComfort: 50)
        )
        let market = PocketPetMarket()
        let purchased = try market.purchase(
            itemID: .leafCap,
            transactionID: UUID(),
            in: base
        )

        XCTAssertTrue(purchased.inventory.owns(.leafCap))
        XCTAssertEqual(purchased.wallet.balance, 125)
        XCTAssertThrowsError(
            try market.purchase(
                itemID: .leafCap,
                transactionID: UUID(),
                in: purchased
            )
        ) { error in
            XCTAssertEqual(error as? PocketPetMarketError, .alreadyOwned)
        }
    }

    func testExpandedGameStateRoundTripsThroughCodable() throws {
        let original = PocketPetGameState(migrating: makeAdult())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let decoded = try decoder.decode(PocketPetGameState.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testFoodConsumptionIsAtomicAndReplaySafe() throws {
        let state = PocketPetGameState(migrating: makeChild())
        let engine = PocketPetGameEngine()
        let commandID = UUID(
            uuidString: "33333333-3333-3333-3333-333333333333"
        )!

        let fed = try engine.consume(
            itemID: .dewberry,
            commandID: commandID,
            in: state
        )
        let replayed = try engine.consume(
            itemID: .dewberry,
            commandID: commandID,
            in: fed
        )

        XCTAssertEqual(fed.inventory.quantity(of: .dewberry), 2)
        XCTAssertEqual(fed.pet.needs.hunger, 5)
        XCTAssertEqual(fed.vitals.fullness, 95)
        XCTAssertEqual(fed.vitals.health, 100)
        XCTAssertEqual(fed.progression.totalXP, state.progression.totalXP + 8)
        XCTAssertEqual(fed.wallet.balance, state.wallet.balance + 2)
        XCTAssertEqual(replayed, fed)
    }

    func testFullPetRefusesFoodWithoutMutation() {
        let base = PocketPetGameState(migrating: makeChild())
        let state = PocketPetGameState(
            pet: base.pet,
            progression: base.progression,
            wallet: base.wallet,
            inventory: base.inventory,
            vitals: CompanionVitals(
                health: base.vitals.health,
                fullness: 95,
                bodyComfort: base.vitals.bodyComfort
            )
        )

        XCTAssertThrowsError(
            try PocketPetGameEngine().consume(
                itemID: .dewberry,
                commandID: UUID(),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? PocketPetInteractionError, .tooFull)
        }
    }

    func testTonicImprovesVitalsAndNeedWithoutExceedingBounds() throws {
        let base = PocketPetGameState(migrating: makeChild())
        var inventory = base.inventory
        inventory.add(.brightSap, quantity: 1)
        var progression = BondProgression()
        progression.grantXP(300)
        let state = PocketPetGameState(
            pet: base.pet,
            progression: progression,
            wallet: base.wallet,
            inventory: inventory,
            vitals: CompanionVitals(health: 94, fullness: 40, bodyComfort: 50)
        )

        let treated = try PocketPetGameEngine().consume(
            itemID: .brightSap,
            commandID: UUID(),
            in: state
        )

        XCTAssertEqual(treated.inventory.quantity(of: .brightSap), 0)
        XCTAssertEqual(treated.vitals.health, 100)
        XCTAssertEqual(treated.pet.needs.happiness, 100)
    }

    func testOwnedEquipmentCanBeEquipped() throws {
        let state = PocketPetGameState(migrating: makeChild())

        let equipped = try PocketPetGameEngine().equip(
            itemID: .pollenBall,
            in: state
        )

        XCTAssertEqual(equipped.inventory.equippedItem(in: .toy), .pollenBall)
    }

    func testUnownedEquipmentIsRejectedWithoutMutation() {
        let state = PocketPetGameState(migrating: makeChild())

        XCTAssertThrowsError(
            try PocketPetGameEngine().equip(itemID: .leafCap, in: state)
        ) { error in
            XCTAssertEqual(error as? PocketPetInteractionError, .notOwned)
        }
    }

    func testArcadeResultUpdatesHighScoreAndRewardsOnlyOnce() throws {
        let state = PocketPetGameState(migrating: makeChild())
        let engine = PocketPetGameEngine()
        let commandID = UUID(
            uuidString: "44444444-4444-4444-4444-444444444444"
        )!

        let result = try engine.recordArcadeResult(
            gameID: .berryCatch,
            score: 1_250,
            commandID: commandID,
            in: state
        )
        let replayed = try engine.recordArcadeResult(
            gameID: .berryCatch,
            score: 1_250,
            commandID: commandID,
            in: result
        )

        XCTAssertEqual(result.highScores[ArcadeGameID.berryCatch.rawValue], 1_250)
        XCTAssertEqual(result.progression.totalXP, state.progression.totalXP + 5)
        XCTAssertEqual(result.wallet.balance, state.wallet.balance + 12)
        XCTAssertEqual(replayed, result)
    }

    func testLowerArcadeScoreKeepsRecordButStillAwardsTheRound() throws {
        let engine = PocketPetGameEngine()
        let first = try engine.recordArcadeResult(
            gameID: .leafMemory,
            score: 900,
            commandID: UUID(),
            in: PocketPetGameState(migrating: makeChild())
        )

        let second = try engine.recordArcadeResult(
            gameID: .leafMemory,
            score: 100,
            commandID: UUID(),
            in: first
        )

        XCTAssertEqual(second.highScores[ArcadeGameID.leafMemory.rawValue], 900)
        XCTAssertGreaterThan(second.wallet.balance, first.wallet.balance)
    }

    func testNegativeArcadeScoreIsRejectedWithoutMutation() {
        let state = PocketPetGameState(migrating: makeChild())

        XCTAssertThrowsError(
            try PocketPetGameEngine().recordArcadeResult(
                gameID: .canopyClimb,
                score: -1,
                commandID: UUID(),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? PocketPetInteractionError, .invalidScore)
        }
    }

    private func makeChild() -> PetState {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        return PetState(
            name: "Pip",
            createdAt: createdAt,
            lastReconciledAt: createdAt,
            stage: .child,
            hatchedAt: createdAt,
            needs: PetNeeds(
                hunger: 20,
                happiness: 80,
                energy: 80,
                cleanliness: 80
            )
        )
    }

    private func makeAdult(
        completedCareActions: Int = 12,
        careMarkCount: Int = 3
    ) -> PetState {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let marks = (0..<careMarkCount).map {
            createdAt.addingTimeInterval(TimeInterval($0 * 3_600))
        }
        return PetState(
            name: "Pip",
            createdAt: createdAt,
            lastReconciledAt: createdAt.addingTimeInterval(12 * 3_600),
            stage: .adult,
            hatchedAt: createdAt,
            childAgeSeconds: 12 * 3_600,
            needs: PetNeeds(
                hunger: 20,
                happiness: 80,
                energy: 80,
                cleanliness: 80
            ),
            careMarks: marks,
            completedCareActions: completedCareActions
        )
    }
}
