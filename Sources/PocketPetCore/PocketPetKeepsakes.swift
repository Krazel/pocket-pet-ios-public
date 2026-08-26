import Foundation

public enum KeepsakeID: String, Codable, CaseIterable, Hashable, Sendable {
    case firstSnack = "first-snack"
    case steadyCare = "steady-care"
    case playfulPal = "playful-pal"
    case freshFriend = "fresh-friend"
    case arcadeHello = "arcade-hello"
    case berryAce = "berry-ace"

    public var target: Int {
        switch self {
        case .firstSnack, .arcadeHello: return 1
        case .playfulPal, .freshFriend: return 3
        case .steadyCare: return 10
        case .berryAce: return 5_000
        }
    }

    public var sunSeedReward: Int {
        switch self {
        case .firstSnack, .arcadeHello: return 10
        case .playfulPal, .freshFriend: return 15
        case .steadyCare: return 25
        case .berryAce: return 50
        }
    }
}

public struct KeepsakeRecord: Codable, Equatable, Sendable {
    public let id: KeepsakeID
    public private(set) var progress: Int
    public private(set) var isClaimed: Bool

    public var isUnlocked: Bool {
        progress >= id.target
    }

    public init(id: KeepsakeID, progress: Int = 0, isClaimed: Bool = false) {
        self.id = id
        self.progress = min(id.target, max(0, progress))
        self.isClaimed = isClaimed && self.progress >= id.target
    }

    mutating func advance(by amount: Int) {
        progress = min(id.target, max(0, progress + max(0, amount)))
    }

    mutating func setProgress(_ value: Int) {
        progress = min(id.target, max(progress, value))
    }

    mutating func claim() {
        guard isUnlocked else { return }
        isClaimed = true
    }
}

public struct KeepsakeCollection: Codable, Equatable, Sendable {
    public private(set) var records: [KeepsakeRecord]

    public init(records: [KeepsakeRecord] = []) {
        var byID: [KeepsakeID: KeepsakeRecord] = [:]
        for record in records {
            if let existing = byID[record.id] {
                byID[record.id] = KeepsakeRecord(
                    id: record.id,
                    progress: max(existing.progress, record.progress),
                    isClaimed: existing.isClaimed || record.isClaimed
                )
            } else {
                byID[record.id] = record
            }
        }
        self.records = KeepsakeID.allCases.compactMap { byID[$0] }
    }

    public init(migrating pet: PetState) {
        self.init(records: [
            KeepsakeRecord(
                id: .steadyCare,
                progress: pet.completedCareActions
            ),
        ])
    }

    public func record(for id: KeepsakeID) -> KeepsakeRecord {
        records.first { $0.id == id } ?? KeepsakeRecord(id: id)
    }

    mutating func advance(_ id: KeepsakeID, by amount: Int = 1) {
        var value = record(for: id)
        value.advance(by: amount)
        replace(value)
    }

    mutating func setProgress(_ id: KeepsakeID, to value: Int) {
        var record = record(for: id)
        record.setProgress(value)
        replace(record)
    }

    mutating func claim(_ id: KeepsakeID) {
        var value = record(for: id)
        value.claim()
        replace(value)
    }

    private mutating func replace(_ record: KeepsakeRecord) {
        records.removeAll { $0.id == record.id }
        records.append(record)
        records.sort {
            KeepsakeID.allCases.firstIndex(of: $0.id)!
                < KeepsakeID.allCases.firstIndex(of: $1.id)!
        }
    }
}

public enum KeepsakeClaimError: Error, Equatable, Sendable {
    case locked
    case alreadyClaimed
}
