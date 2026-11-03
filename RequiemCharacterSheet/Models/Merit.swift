//
//  Merit.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import Foundation
import Observation

/// One of a character's Merits: a catalog entry (with its qualifier, if any) or a custom one, with its dots.
@Observable
final class Merit: Identifiable, Codable {
    let id: UUID
    var source: TraitSource
    /// What the Merit is taken for, e.g. "French" in Language (French).
    var qualifier: String?
    var rating: Int

    /// The catalog entry, if this isn't a custom Merit.
    var entry: MeritEntry? {
        source.catalogID.flatMap { Catalog.bundled.merits.entry($0) }
    }

    /// The name shown on the sheet, e.g. "Language (French)". Setting it links to the catalog entry
    /// with that name, reading a trailing "(…)" as the qualifier.
    var name: String {
        get {
            let base = Catalog.bundled.merits.name(of: source)
            return qualifier.map { "\(base) (\($0))" } ?? base
        }
        set {
            (source, qualifier) = Self.parse(newValue)
        }
    }

    enum CodingKeys: CodingKey {
        case id, source, qualifier, rating
        // Saves before version 5 stored only a name
        case name
    }

    init(id: UUID = UUID(), source: TraitSource, qualifier: String? = nil, rating: Int = 0) {
        self.id = id
        self.source = source
        self.qualifier = qualifier
        self.rating = rating
    }

    convenience init(id: UUID = UUID(), name: String = "", rating: Int = 0) {
        let (source, qualifier) = Self.parse(name)
        self.init(id: id, source: source, qualifier: qualifier, rating: rating)
    }

    // Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(qualifier, forKey: .qualifier)
        try container.encode(rating, forKey: .rating)
    }

    // Decoding
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: UUID())
        if let source = try container.decodeIfPresent(TraitSource.self, forKey: .source) {
            self.source = source
            qualifier = try container.decodeIfPresent(String.self, forKey: .qualifier)
        } else {
            let name: String = try container.decode(.name, default: "")
            (source, qualifier) = Self.parse(name.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        rating = try container.decode(.rating, default: 0)
    }

    /// Matches a name such as "Language (French)" to a catalog entry and qualifier.
    /// Names that don't match a catalog entry are kept whole as custom text.
    private static func parse(_ name: String) -> (TraitSource, String?) {
        let merits = Catalog.bundled.merits
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
