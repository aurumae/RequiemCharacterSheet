//
//  CharacterStore.swift
//  RequiemCharacterSheet
//
//  Requiem's characters in the shared character store.
//

import Foundation
#if SWIFT_PACKAGE
import ChroniclesCore
#endif

/// The store of Requiem characters. The saving itself is shared with every game; see `CharacterFileStore`.
typealias CharacterStore = CharacterFileStore<Character>
/// A received Requiem character file, waiting to be added to the store.
typealias CharacterImport = PendingImport<Character>

/// A saved character as shown in the character list.
struct CharacterSummary: StoredCharacterSummary {
    let id: UUID
    let name: String
    let clan: String
    /// Empty if the character has none.
    var bloodline = ""
    let covenant: String
    /// `nil` when the file couldn't be read.
    let modifiedAt: Date?
    /// False when the file couldn't be read. The file is left untouched so nothing is lost.
    let isReadable: Bool
}

extension CharacterSummary {
    /// The clan with any bloodline after it, e.g. "Ventrue (Bron)".
    var lineage: String {
        let bloodline = bloodline.trimmingCharacters(in: .whitespaces)
        guard !bloodline.isEmpty else { return clan }
        return clan.isEmpty ? bloodline : "\(clan) (\(bloodline))"
    }
    var listDetails: [String] {
        [lineage, covenant]
    }
}

extension Character: StoredCharacter {
    /// Requiem files have never had a `game` key; files without one are Requiem's.
    static var game: String { "requiem" }

    func summary() -> CharacterSummary {
        CharacterSummary(
            id: id,
            name: name,
            clan: clan,
            bloodline: bloodline,
            covenant: covenant,
            modifiedAt: modifiedAt,
            isReadable: true
        )
    }

    static func unreadableSummary(id: UUID) -> CharacterSummary {
        CharacterSummary(id: id, name: "", clan: "", covenant: "", modifiedAt: nil, isReadable: false)
    }
}
