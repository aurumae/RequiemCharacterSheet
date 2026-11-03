//
//  Discipline.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import Foundation
import Observation

/// One of a character's Disciplines: a catalog entry or a custom one, with its dots.
@Observable
final class Discipline: Identifiable, Codable {
    let id: UUID
    var source: TraitSource
    var rating: Int

    /// The catalog entry, if this isn't a custom Discipline.
    var entry: DisciplineEntry? {
        source.catalogID.flatMap { Catalog.bundled.disciplines.entry($0) }
    }

    /// The name shown on the sheet. Setting it links to the catalog entry with that name, if there is one.
    var name: String {
        get { Catalog.bundled.disciplines.name(of: source) }
        set { source = Catalog.bundled.disciplines.source(named: newValue) }
    }

    enum CodingKeys: CodingKey {
        case id, source, rating
        // Saves before version 5 stored only a name
        case name
    }

    init(id: UUID = UUID(), source: TraitSource, rating: Int = 0) {
        self.id = id
        self.source = source
        self.rating = rating
    }

    convenience init(id: UUID = UUID(), name: String = "", rating: Int = 0) {
        self.init(id: id, source: Catalog.bundled.disciplines.source(named: name), rating: rating)
    }

    // Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(source, forKey: .source)
        try container.encode(rating, forKey: .rating)
    }

    // Decoding
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: UUID())
        source = try container.decodeTraitSource(.source, legacyNameKey: .name, in: Catalog.bundled.disciplines)
        rating = try container.decode(.rating, default: 0)
    }
}
