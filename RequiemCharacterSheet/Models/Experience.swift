//
//  Experience.swift
//  RequiemCharacterSheet
//

import Foundation

/// The kinds of trait that cost Experiences to raise.
enum TraitKind: String, Codable, CaseIterable {
    case attribute, skill, specialty, discipline, merit, coil, ritual, devotion, scale, humanity, bloodPotency

    /// Lowering a paid trait with XP Mode on refunds its Experiences, as for a mistake. Humanity and
    /// Blood Potency fall in play (breaking points, torpor), so losing them never refunds.
    var isRefundable: Bool {
        self != .humanity && self != .bloodPotency
    }
}

/// One trait on a character, e.g. Strength, Brawl's specialties, or a particular Discipline row.
struct TraitKey: Hashable, Comparable, Codable, CodingKeyRepresentable {
    let kind: TraitKind
    /// The attribute or skill id, or the row's UUID for Disciplines, Merits and the like.
    let id: String

    init(_ kind: TraitKind, _ id: String) {
        self.kind = kind
        self.id = id
    }

    /// Saved as "attribute:strength".
    var storageKey: String {
        "\(kind.rawValue):\(id)"
    }

    init?(storageKey: String) {
        let parts = storageKey.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let kind = TraitKind(rawValue: parts[0]) else { return nil }
        self.init(kind, parts[1])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storageKey)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let key = TraitKey(storageKey: try container.decode(String.self)) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown trait")
        }
        self = key
    }

    // So dictionaries keyed by trait are saved as JSON objects
    var codingKey: CodingKey {
        AnyCodingKey(stringValue: storageKey)
    }

    init?<T: CodingKey>(codingKey: T) {
        self.init(storageKey: codingKey.stringValue)
    }

    /// In sheet order: Attributes, Skills, Specialties, Disciplines…
    static func < (lhs: TraitKey, rhs: TraitKey) -> Bool {
        let order = TraitKind.allCases
        let left = order.firstIndex(of: lhs.kind) ?? 0
        let right = order.firstIndex(of: rhs.kind) ?? 0
        return left != right ? left < right : lhs.id < rhs.id
    }
}

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        nil
    }
}

/// One entry in a character's change log: a trait going from one rating to another.
struct TraitChange: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let trait: TraitKey
    /// The trait's name when it changed, e.g. "Strength" or "Vigor".
    let name: String
    let from: Int
    let to: Int
    /// Experiences spent (positive) or refunded (negative). 0 when free.
    let experiences: Int
    /// Whether XP Mode was on, so the change was paid for.
    let xpMode: Bool
}

/// Every trait's rating at one moment, and its name, so a deleted trait can still be named in the log.
struct TraitSnapshot: Equatable {
    var levels: [TraitKey: Int] = [:]
    var names: [TraitKey: String] = [:]
}
