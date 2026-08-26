import Foundation

public enum PetStage: String, Codable, CaseIterable, Sendable {
    case egg
    case child
    case adult
}

public enum CareAction: String, Codable, CaseIterable, Hashable, Sendable {
    case feed
    case play
    case rest
    case clean
}

public enum PetCondition: String, Codable, CaseIterable, Sendable {
    case comfortable
    case needsCare
    case sleeping
}

public enum PetNeed: String, Codable, CaseIterable, Sendable {
    case hunger
    case happiness
    case energy
    case cleanliness
}

public enum NeedStatus: String, Codable, CaseIterable, Sendable {
    case comfortable
    case attention
    case urgent
}

public enum PetMilestone: String, Codable, CaseIterable, Hashable, Sendable {
    case hatching
    case adultEvolution
}

public enum PetNameError: Error, Equatable, Sendable {
    case empty
    case tooLong(maximum: Int)
    case containsControlCharacter
}

public struct PetName: Equatable, Sendable {
    public static let maximumLength = 12
    public let value: String

    public init(_ rawValue: String) throws {
        guard !rawValue.unicodeScalars.contains(where: { scalar in
            CharacterSet.controlCharacters.contains(scalar)
                || scalar.value == 0x2028
                || scalar.value == 0x2029
        }) else {
            throw PetNameError.containsControlCharacter
        }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw PetNameError.empty }
        guard value.count <= Self.maximumLength else {
            throw PetNameError.tooLong(maximum: Self.maximumLength)
        }
        self.value = value
    }
}

/// Hunger is a deficit (zero is best). The other three values are wellbeing
/// scores (100 is best). Stored values are always clamped to 0...100.
public struct PetNeeds: Codable, Equatable, Sendable {
    public private(set) var hunger: Double
    public private(set) var happiness: Double
    public private(set) var energy: Double
    public private(set) var cleanliness: Double

    public init(
        hunger: Double,
        happiness: Double,
        energy: Double,
        cleanliness: Double
    ) {
        self.hunger = Self.clamp(hunger)
        self.happiness = Self.clamp(happiness)
        self.energy = Self.clamp(energy)
        self.cleanliness = Self.clamp(cleanliness)
    }

    public var careQuality: Double {
        ((100 - hunger) + happiness + energy + cleanliness) / 400
    }

    public var hasUrgentNeed: Bool {
        PetNeed.allCases.contains { status(for: $0) == .urgent }
    }

    /// Returns the urgent need furthest from its comfortable direction.
    /// Ties preserve the stable PetNeed order for deterministic UI copy.
    public var mostUrgentNeed: PetNeed? {
        PetNeed.allCases.reduce(nil) { current, candidate in
            guard status(for: candidate) == .urgent else { return current }
            guard let current else { return candidate }
            return urgencyScore(for: candidate) > urgencyScore(for: current)
                ? candidate
                : current
        }
    }

    public func urgencyScore(for need: PetNeed) -> Double {
        switch need {
        case .hunger:
            return hunger / 100
        case .happiness:
            return (100 - happiness) / 100
        case .energy:
            return (100 - energy) / 100
        case .cleanliness:
            return (100 - cleanliness) / 100
        }
    }

    public func status(for need: PetNeed) -> NeedStatus {
        switch need {
        case .hunger:
            if hunger < 40 { return .comfortable }
            if hunger < 70 { return .attention }
            return .urgent
        case .happiness:
            return Self.wellbeingStatus(happiness)
        case .energy:
            return Self.wellbeingStatus(energy)
        case .cleanliness:
            return Self.wellbeingStatus(cleanliness)
        }
    }

    public func condition(isResting: Bool) -> PetCondition {
        if isResting { return .sleeping }
        return hasUrgentNeed ? .needsCare : .comfortable
    }

    mutating func apply(_ change: NeedChange) {
        hunger = Self.clamp(hunger + change.hunger)
        happiness = Self.clamp(happiness + change.happiness)
        energy = Self.clamp(energy + change.energy)
        cleanliness = Self.clamp(cleanliness + change.cleanliness)
    }

    static func clamp(_ value: Double) -> Double {
        min(100, max(0, value))
    }

    private static func wellbeingStatus(_ value: Double) -> NeedStatus {
        if value >= 60 { return .comfortable }
        if value >= 30 { return .attention }
        return .urgent
    }

    private enum CodingKeys: String, CodingKey {
        case hunger
        case happiness
        case energy
        case cleanliness
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            hunger: try container.decode(Double.self, forKey: .hunger),
            happiness: try container.decode(Double.self, forKey: .happiness),
            energy: try container.decode(Double.self, forKey: .energy),
            cleanliness: try container.decode(Double.self, forKey: .cleanliness)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hunger, forKey: .hunger)
        try container.encode(happiness, forKey: .happiness)
        try container.encode(energy, forKey: .energy)
        try container.encode(cleanliness, forKey: .cleanliness)
    }
}

public struct PetState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let id: UUID
    public let name: String
    public let createdAt: Date
    public private(set) var lastReconciledAt: Date
    public private(set) var stage: PetStage
    public private(set) var hatchedAt: Date?
    public private(set) var childAgeSeconds: TimeInterval
    public private(set) var needs: PetNeeds
    public private(set) var isResting: Bool
    public private(set) var restStartedAt: Date?
    public private(set) var restElapsedSeconds: TimeInterval
    public private(set) var careMarks: [Date]
    public private(set) var completedCareActions: Int
    public private(set) var unseenMilestones: [PetMilestone]

    public var condition: PetCondition {
        needs.condition(isResting: isResting)
    }

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date,
        lastReconciledAt: Date? = nil,
        stage: PetStage = .egg,
        hatchedAt: Date? = nil,
        childAgeSeconds: TimeInterval = 0,
        needs: PetNeeds,
        isResting: Bool = false,
        restStartedAt: Date? = nil,
        restElapsedSeconds: TimeInterval = 0,
        careMarks: [Date] = [],
        completedCareActions: Int = 0,
        unseenMilestones: [PetMilestone] = [],
        schemaVersion: Int = PetState.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.createdAt = createdAt
        let checkpoint = max(createdAt, lastReconciledAt ?? createdAt)
        self.lastReconciledAt = checkpoint
        self.stage = stage
        let normalizedHatch = stage == .egg ? nil : hatchedAt.map {
            min(checkpoint, max(createdAt, $0))
        }
        self.hatchedAt = normalizedHatch
        let possibleChildAge = checkpoint.timeIntervalSince(
            normalizedHatch ?? checkpoint
        )
        self.childAgeSeconds = stage == .egg
            ? 0
            : min(max(0, childAgeSeconds), possibleChildAge)
        self.needs = needs
        let normalizedRestStart = restStartedAt.map {
            min(checkpoint, max(normalizedHatch ?? createdAt, $0))
        }
        let canRest = isResting && stage != .egg && normalizedRestStart != nil
        self.isResting = canRest
        self.restStartedAt = canRest ? normalizedRestStart : nil
        self.restElapsedSeconds = canRest ? max(0, restElapsedSeconds) : 0
        let markFloor = normalizedHatch ?? checkpoint
        let normalizedMarks = careMarks.map {
            min(checkpoint, max(markFloor, $0))
        }
        self.careMarks = stage == .egg
            ? []
            : Self.uniqueDates(normalizedMarks.sorted())
        self.completedCareActions = stage == .egg ? 0 : max(0, completedCareActions)
        self.unseenMilestones = Self.uniqueMilestones(unseenMilestones)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case name
        case createdAt
        case lastReconciledAt
        case stage
        case hatchedAt
        case childAgeSeconds
        case needs
        case isResting
        case restStartedAt
        case restElapsedSeconds
        case careMarks
        case completedCareActions
        case unseenMilestones
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawName = try container.decode(String.self, forKey: .name)
        let name = try PetName(rawName).value
        let stage = try container.decode(PetStage.self, forKey: .stage)
        let hatchedAt = try container.decodeIfPresent(Date.self, forKey: .hatchedAt)
        if stage != .egg && hatchedAt == nil {
            throw DecodingError.dataCorruptedError(
                forKey: .hatchedAt,
                in: container,
                debugDescription: "A child or adult requires a hatch timestamp."
            )
        }

        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: name,
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            lastReconciledAt: try container.decode(
                Date.self,
                forKey: .lastReconciledAt
            ),
            stage: stage,
            hatchedAt: hatchedAt,
            childAgeSeconds: try container.decode(
                TimeInterval.self,
                forKey: .childAgeSeconds
            ),
            needs: try container.decode(PetNeeds.self, forKey: .needs),
            isResting: try container.decode(Bool.self, forKey: .isResting),
            restStartedAt: try container.decodeIfPresent(
                Date.self,
                forKey: .restStartedAt
            ),
            restElapsedSeconds: try container.decode(
                TimeInterval.self,
                forKey: .restElapsedSeconds
            ),
            careMarks: try container.decode([Date].self, forKey: .careMarks),
            completedCareActions: try container.decode(
                Int.self,
                forKey: .completedCareActions
            ),
            unseenMilestones: try container.decode(
                [PetMilestone].self,
                forKey: .unseenMilestones
            ),
            schemaVersion: try container.decode(Int.self, forKey: .schemaVersion)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastReconciledAt, forKey: .lastReconciledAt)
        try container.encode(stage, forKey: .stage)
        try container.encodeIfPresent(hatchedAt, forKey: .hatchedAt)
        try container.encode(childAgeSeconds, forKey: .childAgeSeconds)
        try container.encode(needs, forKey: .needs)
        try container.encode(isResting, forKey: .isResting)
        try container.encodeIfPresent(restStartedAt, forKey: .restStartedAt)
        try container.encode(restElapsedSeconds, forKey: .restElapsedSeconds)
        try container.encode(careMarks, forKey: .careMarks)
        try container.encode(completedCareActions, forKey: .completedCareActions)
        try container.encode(unseenMilestones, forKey: .unseenMilestones)
    }

    mutating func setCheckpoint(_ date: Date) {
        lastReconciledAt = max(lastReconciledAt, date)
    }

    mutating func addChildAge(_ duration: TimeInterval) {
        guard stage == .child else { return }
        childAgeSeconds += max(0, duration)
    }

    mutating func setNeeds(_ needs: PetNeeds) {
        self.needs = needs
    }

    mutating func hatch(at date: Date, initialNeeds: PetNeeds) {
        guard stage == .egg else { return }
        stage = .child
        hatchedAt = date
        childAgeSeconds = 0
        needs = initialNeeds
        stopRest()
        addMilestone(.hatching)
    }

    mutating func evolveToAdult() {
        guard stage == .child else { return }
        stage = .adult
        addMilestone(.adultEvolution)
    }

    mutating func startRest(at date: Date) {
        isResting = true
        restStartedAt = date
        restElapsedSeconds = 0
    }

    mutating func addRestElapsed(_ duration: TimeInterval) {
        restElapsedSeconds += max(0, duration)
    }

    mutating func stopRest() {
        isResting = false
        restStartedAt = nil
        restElapsedSeconds = 0
    }

    mutating func recordCareAction(at date: Date, markWindow: TimeInterval) {
        completedCareActions += 1
        guard needs.careQuality >= 0.60 else { return }
        if let latest = careMarks.last,
           date.timeIntervalSince(latest) < markWindow {
            return
        }
        careMarks.append(date)
    }

    mutating func markMilestoneSeen(_ milestone: PetMilestone) {
        unseenMilestones.removeAll { $0 == milestone }
    }

    private mutating func addMilestone(_ milestone: PetMilestone) {
        guard !unseenMilestones.contains(milestone) else { return }
        unseenMilestones.append(milestone)
    }

    private static func uniqueMilestones(
        _ milestones: [PetMilestone]
    ) -> [PetMilestone] {
        var seen = Set<PetMilestone>()
        return milestones.filter { seen.insert($0).inserted }
    }

    private static func uniqueDates(_ dates: [Date]) -> [Date] {
        var previous: Date?
        return dates.filter { date in
            defer { previous = date }
            return previous != date
        }
    }
}
