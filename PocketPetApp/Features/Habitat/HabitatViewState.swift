import PocketPetCore

struct HabitatViewState: Equatable {
    let name: String
    let stage: PetStage
    let needs: PetNeeds
    let condition: PetCondition
    let reaction: CareAction?
    let reactionSequence: Int
    let petTapSequence: Int

    init(
        pet: PetState,
        reaction: CareAction?,
        reactionSequence: Int,
        petTapSequence: Int
    ) {
        self.name = pet.name
        self.stage = pet.stage
        self.needs = pet.needs
        self.condition = pet.condition
        self.reaction = reaction
        self.reactionSequence = reactionSequence
        self.petTapSequence = petTapSequence
    }

    var stageLabel: String {
        switch stage {
        case .egg: "Egg"
        case .child: "Child"
        case .adult: "Adult"
        }
    }

    var speech: String {
        if let reaction {
            switch reaction {
            case .feed: return "Tasty, thank you!"
            case .play: return "That was fun!"
            case .rest: return condition == .sleeping ? "Cozy time." : "Good morning!"
            case .clean: return "Fresh and comfy!"
            }
        }
        switch condition {
        case .comfortable: return "Lovely morning!"
        case .needsCare: return needsCareSpeech
        case .sleeping: return "Resting peacefully."
        }
    }

    var primaryUrgentNeed: PetNeed? {
        needs.mostUrgentNeed
    }

    private var needsCareSpeech: String {
        switch primaryUrgentNeed {
        case .hunger: "A little snack?"
        case .happiness: "Could we play a little?"
        case .energy: "A little rest?"
        case .cleanliness: "Could I freshen up?"
        case nil: "A little care, please?"
        }
    }

    var accessibilitySceneSummary: String {
        let conditionSentence: String
        switch condition {
        case .comfortable: conditionSentence = "\(name) is comfortable."
        case .needsCare: conditionSentence = "\(name) could use care."
        case .sleeping: conditionSentence = "\(name) is sleeping."
        }
        let priority: String
        if condition == .needsCare, let primaryUrgentNeed {
            priority = " Priority need: \(Self.label(for: primaryUrgentNeed))."
        } else {
            priority = ""
        }
        return "\(conditionSentence)\(priority) \(speech)"
    }

    private static func label(for need: PetNeed) -> String {
        switch need {
        case .hunger: "hunger"
        case .happiness: "happiness"
        case .energy: "energy"
        case .cleanliness: "cleanliness"
        }
    }
}
