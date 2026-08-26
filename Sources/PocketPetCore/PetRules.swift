import Foundation

public struct NeedChange: Codable, Equatable, Sendable {
    public var hunger: Double
    public var happiness: Double
    public var energy: Double
    public var cleanliness: Double

    public init(
        hunger: Double = 0,
        happiness: Double = 0,
        energy: Double = 0,
        cleanliness: Double = 0
    ) {
        self.hunger = hunger
        self.happiness = happiness
        self.energy = energy
        self.cleanliness = cleanliness
    }

    func scaled(by factor: Double) -> NeedChange {
        NeedChange(
            hunger: hunger * factor,
            happiness: happiness * factor,
            energy: energy * factor,
            cleanliness: cleanliness * factor
        )
    }
}

public struct PetRules: Codable, Equatable, Sendable {
    public var initialChildNeeds: PetNeeds
    public var awakeHourlyChange: NeedChange
    public var sleepingHourlyChange: NeedChange
    public var actionChanges: [CareAction: NeedChange]
    public var maximumDecayInterval: TimeInterval
    public var maximumRestInterval: TimeInterval
    public var careMarkWindow: TimeInterval
    public var adultChildAge: TimeInterval
    public var adultCareMarkCount: Int

    public init(
        initialChildNeeds: PetNeeds,
        awakeHourlyChange: NeedChange,
        sleepingHourlyChange: NeedChange,
        actionChanges: [CareAction: NeedChange],
        maximumDecayInterval: TimeInterval,
        maximumRestInterval: TimeInterval,
        careMarkWindow: TimeInterval,
        adultChildAge: TimeInterval,
        adultCareMarkCount: Int
    ) {
        self.initialChildNeeds = initialChildNeeds
        self.awakeHourlyChange = awakeHourlyChange
        self.sleepingHourlyChange = sleepingHourlyChange
        self.actionChanges = actionChanges
        self.maximumDecayInterval = max(0, maximumDecayInterval)
        self.maximumRestInterval = max(0, maximumRestInterval)
        self.careMarkWindow = max(0, careMarkWindow)
        self.adultChildAge = max(0, adultChildAge)
        self.adultCareMarkCount = max(0, adultCareMarkCount)
    }

    public static let productBaseline = PetRules(
        initialChildNeeds: PetNeeds(
            hunger: 20,
            happiness: 80,
            energy: 80,
            cleanliness: 80
        ),
        awakeHourlyChange: NeedChange(
            hunger: 1.25,
            happiness: -0.75,
            energy: -1,
            cleanliness: -0.625
        ),
        sleepingHourlyChange: NeedChange(
            hunger: 0.625,
            happiness: -0.375,
            energy: 25,
            cleanliness: -0.3125
        ),
        actionChanges: [
            .feed: NeedChange(hunger: -35),
            .play: NeedChange(happiness: 30),
            .clean: NeedChange(cleanliness: 40),
        ],
        maximumDecayInterval: 72 * 60 * 60,
        maximumRestInterval: 2 * 60 * 60,
        careMarkWindow: 18 * 60 * 60,
        adultChildAge: 72 * 60 * 60,
        adultCareMarkCount: 3
    )
}
