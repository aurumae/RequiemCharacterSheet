//
//  CharacterCondition.swift
//  ChroniclesCore
//

import Foundation
import Observation

/// A Condition on a character: a catalog entry or the player's own, with its note and counter.
@Observable
package final class CharacterCondition: Identifiable, Codable {
    package let id: UUID
    package var source: TraitSource
    /// Who or what it's about, e.g. "Marcus Vale" for Swooning.
    package var note: String
    /// The growing penalty of Conditions like Tempted, shown as "−3". 0 for others.
    package var counter: Int
    package let addedAt: Date
    /// For a custom Condition: the player's own description of what it does, how it's resolved and its Beat.
    package var customEffect: String
    package var customResolution: String
    package var customBeat: String
    package var customPersistent: Bool

    package enum CodingKeys: CodingKey {
        case id, source, note, counter, addedAt, customEffect, customResolution, customBeat, customPersistent
    }

    package init(id: UUID = UUID(), source: TraitSource, note: String = "", counter: Int = 0, addedAt: Date = .now) {
        self.id = id
        self.source = source
        self.note = note
        self.counter = counter
        self.addedAt = addedAt
        customEffect = ""
        customResolution = ""
        customBeat = ""
        customPersistent = false
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(source, forKey: .source)
        try container.encode(note, forKey: .note)
        try container.encode(counter, forKey: .counter)
        try container.encode(addedAt, forKey: .addedAt)
        // Only a custom Condition has its own text
        if source.catalogID == nil {
            try container.encode(customEffect, forKey: .customEffect)
            try container.encode(customResolution, forKey: .customResolution)
            try container.encode(customBeat, forKey: .customBeat)
            try container.encode(customPersistent, forKey: .customPersistent)
        }
    }

    package required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: UUID())
        // A custom name that matches the game's catalog is linked to it by `relink(in:)`
        source = try container.decodeTraitSource(.source, in: CatalogIndex<ConditionEntry>([]))
        note = try container.decode(.note, default: "")
        counter = try container.decode(.counter, default: 0)
        addedAt = try container.decode(.addedAt, default: .now)
        customEffect = try container.decode(.customEffect, default: "")
        customResolution = try container.decode(.customResolution, default: "")
        customBeat = try container.decode(.customBeat, default: "")
        customPersistent = try container.decode(.customPersistent, default: false)
    }

    /// Links a custom name that matches a catalog entry (e.g. one added since the save) to it.
    package func relink(in conditions: CatalogIndex<ConditionEntry>) {
        if case .custom(let name) = source {
            source = conditions.source(named: name)
        }
    }
}
