import Foundation
import XCTest
@testable import PocketPetCore

final class PocketPetPantryPresentationTests: XCTestCase {
    func testProjectionUsesFiveLiveMetricsInApprovedOrder() {
        let presentation = makePresentation()

        XCTAssertEqual(
            presentation.metrics.map(\.id),
            [.hungerSatisfaction, .health, .joy, .energy, .clean]
        )
        XCTAssertEqual(
            presentation.metrics.map(\.title),
            ["Hunger", "Health", "Joy", "Energy", "Clean"]
        )
        XCTAssertEqual(presentation.metrics.map(\.value), [78, 76, 52, 48, 78])
    }

    func testProjectionUsesLiveProgressionWalletAndCanonicalFoodCounts() {
        let presentation = makePresentation()

        XCTAssertEqual(presentation.level, 2)
        XCTAssertEqual(presentation.sunSeeds, 124)
        XCTAssertEqual(
            presentation.foods.map(\.id),
            [.dewberry, .seedBiscuit, .mossMelon]
        )
        XCTAssertEqual(
            presentation.foods.map(\.name),
            ["Dewberry", "Seed Biscuit", "Moss Melon"]
        )
        XCTAssertEqual(presentation.foods.map(\.quantity), [8, 5, 4])
    }

    func testProjectionReadsNamesFromInjectedCatalogAndExcludesOtherItems() {
        let catalog = PocketPetCatalog(items: [
            StoreItemDefinition(id: .dewberry, name: "Little Dew", kind: .food, price: 1),
            StoreItemDefinition(id: .seedBiscuit, name: "Seed Heart", kind: .food, price: 1),
            StoreItemDefinition(id: .mossMelon, name: "Green Melon", kind: .food, price: 1),
            StoreItemDefinition(id: .mendDew, name: "Mend Dew", kind: .tonic, price: 1),
        ])

        let presentation = PocketPetPantryPresentation(
            gameState: PocketPetPantryFixtures.levelTwo,
            selectedFoodID: nil,
            catalog: catalog
        )

        XCTAssertEqual(presentation.foods.count, 3)
        XCTAssertEqual(
            presentation.foods.map(\.name),
            ["Little Dew", "Seed Heart", "Green Melon"]
        )
    }

    func testSelectionDistinguishesAvailableAndOutOfStockFood() {
        let available = makePresentation(selectedFoodID: .dewberry)
        let selectedAvailable = available.foods[0]

        XCTAssertTrue(selectedAvailable.isSelected)
        XCTAssertEqual(selectedAvailable.availability, .available)
        XCTAssertTrue(selectedAvailable.canOffer)

        let reference = PocketPetPantryFixtures.levelTwo
        let depletedState = PocketPetGameState(
            pet: reference.pet,
            progression: reference.progression,
            wallet: reference.wallet,
            inventory: ItemInventory(stacks: [
                InventoryStack(itemID: .seedBiscuit, quantity: 5),
                InventoryStack(itemID: .mossMelon, quantity: 4),
            ]),
            vitals: reference.vitals,
            location: reference.location
        )
        let depleted = PocketPetPantryPresentation(
            gameState: depletedState,
            selectedFoodID: .dewberry
        ).foods[0]

        XCTAssertTrue(depleted.isSelected)
        XCTAssertEqual(depleted.quantity, 0)
        XCTAssertEqual(depleted.availability, .outOfStock)
        XCTAssertFalse(depleted.canOffer)
    }

    func testInteractionErrorsMapToRecoverableEnglishProductMessages() {
        XCTAssertEqual(
            PocketPetPantryProductMessage.forInteractionError(
                .outOfStock,
                itemName: "Dewberry"
            )?.text,
            "Dewberry is out of stock. Visit Market to get more."
        )
        XCTAssertEqual(
            PocketPetPantryProductMessage.forInteractionError(
                .tooFull,
                itemName: "Dewberry"
            )?.text,
            "Spriglet is too full for another snack right now."
        )
        XCTAssertEqual(
            PocketPetPantryProductMessage.forInteractionError(
                .unavailableUntilHatched,
                itemName: "Dewberry"
            )?.text,
            "Food will be available after Spriglet hatches."
        )
        XCTAssertNil(
            PocketPetPantryProductMessage.forInteractionError(
                .unknownItem,
                itemName: "Unknown food"
            )
        )
    }

    func testPersistenceFailureMessagePromisesNoOptimisticConsumption() {
        XCTAssertEqual(
            PocketPetPantryProductMessage.persistenceFailure.text,
            "That snack could not be saved. Nothing was used. Please try again."
        )
    }

    func testProjectionReflectsSavedEngineResultWithoutHardCodedCounts() throws {
        let consumed = try PocketPetGameEngine().consume(
            itemID: .dewberry,
            commandID: UUID(
                uuidString: "06508E85-847A-4624-A332-003E61118828"
            )!,
            in: PocketPetPantryFixtures.levelTwo
        )

        let presentation = PocketPetPantryPresentation(
            gameState: consumed,
            selectedFoodID: .dewberry
        )

        XCTAssertEqual(presentation.foods[0].quantity, 7)
        XCTAssertEqual(presentation.metrics[0].value, 93)
        XCTAssertEqual(presentation.metrics[1].value, 77)
        XCTAssertEqual(presentation.sunSeeds, 126)
    }

    func testLevelTwoFixtureIsDeterministicAndDoesNotNeedEngineMutation() {
        let first = PocketPetPantryFixtures.levelTwo
        let second = PocketPetPantryFixtures.levelTwo

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.pet.stage, .child)
        XCTAssertEqual(first.location, .pantryNook)
        XCTAssertEqual(first.progression.totalXP, 100)
        XCTAssertEqual(first.progression.level, 2)
        XCTAssertEqual(first.wallet.balance, 124)
        XCTAssertEqual(first.inventory.quantity(of: .dewberry), 8)
        XCTAssertEqual(first.inventory.quantity(of: .seedBiscuit), 5)
        XCTAssertEqual(first.inventory.quantity(of: .mossMelon), 4)
    }

    private func makePresentation(
        selectedFoodID: ItemID? = .dewberry
    ) -> PocketPetPantryPresentation {
        PocketPetPantryPresentation(
            gameState: PocketPetPantryFixtures.levelTwo,
            selectedFoodID: selectedFoodID
        )
    }
}
