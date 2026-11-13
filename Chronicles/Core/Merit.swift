//
//  Merit.swift
//  ChroniclesCore
//
//  Created by Oisín McColgan on 20/09/2024.
//

import Foundation
import Observation

/// One of a character's Merits: a catalog entry (with its qualifier, if any) or a custom one, with its dots.
/// Each game's app looks entries up in its own catalog, e.g. `merit.entry`.
@Observable
package final class Merit: Identifiable, Codable {
    package let id: UUID
    package var source: TraitSource
    /// What the Merit is taken for, e.g. "French" in Language (French).
    package var qualifier: String?
    package var rating: Int

    package enum CodingKeys: CodingKey {
        case id, source, qualifier, rating
        // Saves before version 5 stored only a name
        case name
    }

    package init(id: UUID = UUID(), source: TraitSource, qualifier: String? = nil, rating: Int = 0) {
        self.id = id
        self.source = source
        self.qualifier = qualifier
        self.rating = rating
    }

    // Encoding
    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(qualifier, forKey: .qualifier)
        try container.encode(rating, forKey: .rating)
    }

    // Decoding. A custom name, or a name from before version 5, is kept as custom text until `relink(in:)` matches it
    // against the game's catalog.
    package required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: UUID())
        if let source = try container.decodeIfPresent(TraitSource.self, forKey: .source) {
            self.source = source
            if case .custom = source {
                qualifier = nil
            } else {
                qualifier = try container.decodeIfPresent(String.self, forKey: .qualifier)
            }
        } else {
            let name: String = try container.decode(.name, default: "")
            source = .custom(name.trimmingCharacters(in: .whitespacesAndNewlines))
            qualifier = nil
        }
        rating = try container.decode(.rating, default: 0)
    }

    /// The catalog entry, if this isn't a custom Merit.
    package func entry(in merits: CatalogIndex<MeritEntry>) -> MeritEntry? {
        source.catalogID.flatMap { merits.entry($0) }
    }

    /// The name shown on the sheet, e.g. "Language (French)".
    package func name(in merits: CatalogIndex<MeritEntry>) -> String {
        let base = merits.name(of: source)
        return qualifier.map { "\(base) (\($0))" } ?? base
    }

    /// Links a custom name that matches a catalog entry (e.g. one added since the save) to it.
    package func relink(in merits: CatalogIndex<MeritEntry>) {
        if case .custom(let name) = source {
            (source, qualifier) = Self.parse(name, in: merits)
        }
    }

    /// Matches a name such as "Language (French)" to a catalog entry and qualifier.
    /// Names that don't match a catalog entry are kept whole as custom text.
    package static func parse(_ name: String, in merits: CatalogIndex<MeritEntry>) -> (TraitSource, String?) {
        if let entry = merits.entry(named: name) {
            return (.catalog(entry.id), nil)
        }
        if name.hasSuffix(")"), let open = name.lastIndex(of: "(") {
            let base = name[..<open].trimmingCharacters(in: .whitespaces)
            let qualifier = name[name.index(after: open)..<name.index(before: name.endIndex)]
                .trimmingCharacters(in: .whitespaces)
            if let entry = merits.entry(named: base), !qualifier.isEmpty {
                return (.catalog(entry.id), qualifier)
            }
        }
        return (.custom(name), nil)
    }
}
