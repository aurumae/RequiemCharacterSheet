//
//  Bane.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import Foundation
import Observation

/// One of a character's Banes: a catalog entry or the player's own description.
@Observable
final class Bane: Identifiable, Codable {
    let id: UUID
    var source: TraitSource

    /// The catalog entry, if this isn't a custom Bane.
    var entry: BaneEntry? {
        source.catalogID.flatMap { Catalog.bundled.banes.entry($0) }
    }

    /// The text shown on the sheet. Setting it makes the Bane custom text; a custom Bane whose text is
    /// exactly a catalog Bane's name is linked to it when the character is next loaded.
    var text: String {
        get { Catalog.bundled.banes.name(of: source) }
        set { source = .custom(newValue) }
    }

    enum CodingKeys: CodingKey {
        case id, source
        // Saves before version 5 stored only text
        case text
    }

    init(id: UUID = UUID(), source: TraitSource) {
        self.id = id
        self.source = source
    }

    convenience init(id: UUID = UUID(), text: String = "") {
        self.init(id: id, source: Catalog.bundled.banes.source(named: text))
    }

    // Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(source, forKey: .source)
    }

    // Decoding
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: UUID())
        source = try container.decodeTraitSource(.source, legacyNameKey: .text, in: Catalog.bundled.banes)
    }
}
