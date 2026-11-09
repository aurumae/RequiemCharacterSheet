//
//  Experience.swift
//  RequiemCharacterSheet
//

import Foundation

/// The kinds of trait that cost Experiences to raise, and Conditions, which are logged but cost nothing.
enum TraitKind: String, Codable, CaseIterable {
    case attribute, skill, specialty, discipline, merit, coil, ritual, devotion, scale, humanity, bloodPotency
    case condition

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
    /// Made during guided creation, with the starting dots. Not saved before version 9.
    var duringCreation: Bool? = nil
    /// For a Condition: what happened to it. Not saved before version 11.
    var event: ConditionEvent? = nil
    /// Beats gained, e.g. 1 for resolving a Condition. Not saved before version 11.
    var beats: Int? = nil
}

/// Every trait's rating at one moment, and its name, so a deleted trait can still be named in the log.
struct TraitSnapshot: Equatable {
    var levels: [TraitKey: Int] = [:]
    var names: [TraitKey: String] = [:]
}

extension TraitChange {
    /// What changed, e.g. "1 → 3", "Learned", or "Cost 1 → 3" for a custom Devotion.
    var changeText: String {
        if let event {
            switch event {
            case .added: return "Added"
            case .ended: return "Ended"
            case .resolved: return "Resolved"
            case .beat: return "Beat"
            }
        }
        switch trait.kind {
        case .ritual, .scale:
            return to > from ? "Learned" : "Removed"
        case .devotion:
            if from == 0 { return "Learned" }
            if to == 0 { return "Removed" }
            return "Cost \(from) → \(to)"
        default:
            return "\(from) → \(to)"
        }
    }

    /// What it cost, e.g. "Spent 8", "Refunded 4", "Creation", "Free" (XP Mode off) or "No cost".
    var costText: String {
        if trait.kind == .condition {
            return beats.map { $0 == 1 ? "+1 Beat" : "+\($0) Beats" } ?? ""
        }
        if duringCreation == true { return "Creation" }
        if experiences > 0 { return "Spent \(experiences)" }
        if experiences < 0 { return "Refunded \(-experiences)" }
        return xpMode ? "No cost" : "Free"
    }
}

extension Character {
    /// The name to show for a log entry: the trait's current name if it's still on the sheet (a custom
    /// trait may have been named after it was added), otherwise its name when it changed.
    func displayName(for change: TraitChange) -> String {
        // A Condition is named as it is now, or as it was when it ended, e.g. with the note typed after adding it
        let current = condition(for: change).map(logName)
            ?? (change.trait.kind == .condition ? changeLog.last { $0.trait == change.trait }?.name : nil)
            ?? traitSnapshot.names[change.trait] ?? ""
        let name = current.isEmpty ? change.name : current
        return name.isEmpty ? "Unnamed \(change.trait.kind.displayName)" : name
    }
}

extension TraitKind {
    var displayName: String {
        switch self {
        case .attribute: return "Attribute"
        case .skill: return "Skill"
        case .specialty: return "Specialty"
        case .discipline: return "Discipline"
        case .merit: return "Merit"
        case .coil: return "Coil"
        case .ritual: return "Ritual"
        case .devotion: return "Devotion"
        case .scale: return "Scale"
        case .humanity: return "Humanity"
        case .bloodPotency: return "Blood Potency"
        case .condition: return "Condition"
        }
    }
}
