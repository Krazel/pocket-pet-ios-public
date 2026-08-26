import PocketPetCore
import SpriteKit
import UIKit

final class PantryScene: SKScene {
    private let environment = SKSpriteNode()
    private let petNode = SKSpriteNode()
    private let handNode = SKSpriteNode()
    private let foodNode = SKSpriteNode()
    private let reactionRoot = SKNode()
    private var lastOfferSequence = 0

    override init(size: CGSize = CGSize(width: 853, height: 760)) {
        super.init(size: size)
        scaleMode = .aspectFill
        backgroundColor = .clear
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        environment.zPosition = -1000
        petNode.zPosition = 0
        handNode.zPosition = 70
        foodNode.zPosition = 80
        reactionRoot.zPosition = 110
        addChild(environment)
        addChild(petNode)
        addChild(handNode)
        addChild(foodNode)
        addChild(reactionRoot)
    }

    required init?(coder _: NSCoder) {
        return nil
    }

    func configure(
        pet: PetState,
        selectedFoodID: ItemID?,
        offerSequence: Int,
        reduceMotion: Bool
    ) {
        environment.texture = texture(named: "pantry_wall_window_base")
        environment.size = size
        environment.position = .zero

        petNode.texture = texture(named: petArtworkName(for: pet))
        petNode.size = pet.stage == .adult
            ? CGSize(width: 390, height: 525)
            : CGSize(width: 347, height: 494)
        petNode.position = CGPoint(x: 0, y: -55)

        let foodName = selectedFoodID.flatMap(foodArtworkName)
        handNode.texture = foodName == nil ? nil : texture(named: "pantry_offer_hand")
        handNode.size = CGSize(width: 337, height: 223)
        handNode.position = CGPoint(x: 285, y: -86)
        handNode.alpha = foodName == nil ? 0 : 0.72

        foodNode.texture = foodName.flatMap { texture(named: $0) }
        foodNode.size = CGSize(width: 104, height: 104)
        foodNode.position = CGPoint(x: 168, y: -38)
        foodNode.alpha = foodName == nil ? 0 : 1

        guard offerSequence != lastOfferSequence else { return }
        lastOfferSequence = offerSequence
        playSavedOffer(reduceMotion: reduceMotion)
    }

    private func playSavedOffer(reduceMotion: Bool) {
        handNode.removeAllActions()
        foodNode.removeAllActions()
        petNode.removeAllActions()
        reactionRoot.removeAllChildren()
        if reduceMotion {
            foodNode.run(.sequence([.fadeAlpha(to: 0.35, duration: 0.12), .fadeIn(withDuration: 0.12)]))
            return
        }
        foodNode.run(
            .sequence([
                .moveBy(x: -64, y: 42, duration: 0.24),
                .wait(forDuration: 0.12),
                .moveBy(x: 64, y: -42, duration: 0.24),
            ])
        )
        petNode.run(
            .sequence([
                .scale(to: 1.035, duration: 0.16),
                .scale(to: 1, duration: 0.20),
            ])
        )
        for index in 0..<6 {
            let sparkle = SKShapeNode(circleOfRadius: CGFloat(5 + index % 2))
            sparkle.fillColor = UIColor(red: 0.98, green: 0.71, blue: 0.08, alpha: 0.9)
            sparkle.strokeColor = .clear
            sparkle.position = CGPoint(
                x: CGFloat(-75 + index * 30),
                y: CGFloat(72 + (index % 3) * 17)
            )
            reactionRoot.addChild(sparkle)
            sparkle.run(.sequence([.fadeOut(withDuration: 0.65), .removeFromParent()]))
        }
    }

    private func petArtworkName(for pet: PetState) -> String {
        if pet.stage == .adult {
            switch pet.condition {
            case .comfortable: return "spriglet_adult_neutral"
            case .needsCare: return "spriglet_adult_needs_care"
            case .sleeping: return "spriglet_adult_sleeping"
            }
        }
        switch pet.condition {
        case .comfortable: return "spriglet_child"
        case .needsCare: return "spriglet_child_needs_care"
        case .sleeping: return "spriglet_child_sleeping"
        }
    }

    private func foodArtworkName(for id: ItemID) -> String? {
        switch id.rawValue {
        case "food.dewberry": return "food_dewberry"
        case "food.seed-biscuit": return "food_seed_biscuit"
        case "food.moss-melon": return "food_moss_melon"
        default: return nil
        }
    }

    private func texture(named name: String) -> SKTexture? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        return SKTexture(image: image)
    }
}
