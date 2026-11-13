//
//  TraitSource.swift
//  ChroniclesCore
//

import Foundation

/// Where one of a character's Disciplines, Merits, Banes, clan or covenant comes from:
/// a catalog entry, or the player's own text for homebrew and anything not yet catalogued.
package enum TraitSource: Hashable, Codable {
    case catalog(CatalogEntryID)
    case custom(String)

    package var catalogID: CatalogEntryID? {
        if case .catalog(let id) = self { return id }
        return nil
    }

    private enum CodingKeys: CodingKey {
        case catalog, custom
    }

    /// Saved as {"catalog": "vigor"} or {"custom": "Blood Sorcery"}.
    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .catalog(let id):
            try container.encode(id, forKey: .catalog)
        case .custom(let name):
            try container.encode(name, forKey: .custom)
        }
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let id = try container.decodeIfPresent(String.self, forKey: .catalog) {
            self = .catalog(id)
        } else {
            self = .custom(try container.decode(String.self, forKey: .custom))
        }
    }
}

extension KeyedDecodingContainer {
    /// Decodes a `TraitSource`, or, for saves before version 5, a plain name matched against `entries`.
    /// Custom names that now match a catalog entry (e.g. one added since the save) are linked to it.
    package func decodeTraitSource<Entry: CatalogEntry>(_ key: Key, legacyNameKey: Key? = nil, in entries: CatalogIndex<Entry>) throws -> TraitSource {
        if let source = try? decodeIfPresent(TraitSource.self, forKey: key) {
            if case .custom(let name) = source {
                return entries.source(named: name)
            }
            return source
        }
        let name = try decodeIfPresent(String.self, forKey: legacyNameKey ?? key) ?? ""
        return entries.source(named: name.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
