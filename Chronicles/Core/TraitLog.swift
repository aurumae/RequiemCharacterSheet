//
//  TraitLog.swift
//  ChroniclesCore
//

import Foundation

/// A kind of trait a character's change log can record, saved by its name, e.g. "attribute" or "discipline".
/// Each game adds its own kinds; these are the ones every Chronicles of Darkness game shares.
package struct TraitKind: RawRepresentable, Hashable, Codable, Sendable {
    package let rawValue: String

    package init?(rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }

    /// For kinds a game declares, e.g. `TraitKind("discipline")`.
    package init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    package static let attribute = TraitKind("attribute")
    package static let skill = TraitKind("skill")
    package static let specialty = TraitKind("specialty")
    package static let merit = TraitKind("merit")
    /// Logged when added, ended or resolved, but never bought.
    package static let condition = TraitKind("condition")
}

/// One trait on a character, e.g. Strength, Brawl's specialties, or a particular Merit row.
package struct TraitKey: Hashable, Codable, CodingKeyRepresentable {
    package let kind: TraitKind
    /// The attribute or skill id, or the row's UUID for Merits and the like.
    package let id: String

    package init(_ kind: TraitKind, _ id: String) {
        self.kind = kind
        self.id = id
    }

    /// Saved as "attribute:strength".
    package var storageKey: String {
        "\(kind.rawValue):\(id)"
    }

    package init?(storageKey: String) {
        let parts = storageKey.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let kind = TraitKind(rawValue: parts[0]) else { return nil }
        self.init(kind, parts[1])
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storageKey)
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let key = TraitKey(storageKey: try container.decode(String.self)) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown trait")
        }
        self = key
    }

    // So dictionaries keyed by trait are saved as JSON objects
    package var codingKey: CodingKey {
        AnyCodingKey(stringValue: storageKey)
    }

    package init?<T: CodingKey>(codingKey: T) {
        self.init(storageKey: codingKey.stringValue)
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

/// What happened to a Condition, for the change log.
package enum ConditionEvent: String, Codable {
    case added, ended, resolved, beat
}

/// One entry in a character's change log: a trait going from one rating to another.
package struct TraitChange: Identifiable, Codable, Equatable {
    package let id: UUID
    package let date: Date
    package let trait: TraitKey
    /// The trait's name when it changed, e.g. "Strength" or "Vigor".
    package let name: String
    package let from: Int
    package let to: Int
    /// Experiences spent (positive) or refunded (negative). 0 when free.
    package let experiences: Int
    /// Whether XP Mode was on, so the change was paid for.
    package let xpMode: Bool
    /// Made during guided creation, with the starting dots. Not saved before version 9.
    package var duringCreation: Bool? = nil
    /// For a Condition: what happened to it. Not saved before version 11.
    package var event: ConditionEvent? = nil
    /// Beats gained, e.g. 1 for resolving a Condition. Not saved before version 11.
    package var beats: Int? = nil

    package init(
        id: UUID, date: Date, trait: TraitKey, name: String, from: Int, to: Int, experiences: Int, xpMode: Bool,
        duringCreation: Bool? = nil, event: ConditionEvent? = nil, beats: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.trait = trait
        self.name = name
        self.from = from
        self.to = to
        self.experiences = experiences
        self.xpMode = xpMode
        self.duringCreation = duringCreation
        self.event = event
        self.beats = beats
    }
}

/// Every trait's rating at one moment, and its name, so a deleted trait can still be named in the log.
package struct TraitSnapshot: Equatable {
    package var levels: [TraitKey: Int] = [:]
    package var names: [TraitKey: String] = [:]

    package init(levels: [TraitKey: Int] = [:], names: [TraitKey: String] = [:]) {
        self.levels = levels
        self.names = names
    }
}
