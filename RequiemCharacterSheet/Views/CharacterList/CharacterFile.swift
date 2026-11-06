//
//  CharacterFile.swift
//  RequiemCharacterSheet
//

import CoreTransferable
import UniformTypeIdentifiers

extension UTType {
    /// A shared character: the app's saved character JSON, under its own extension so the system offers
    /// to open it in the app. Declared in Info.plist; the Android app reads and writes the same files.
    static let requiemCharacter = UTType(exportedAs: "com.omccolgan.RequiemCharacterSheet.character")
}

/// A saved character shared as "<Name>.vtrcharacter". The file is read only when it's actually shared.
struct CharacterFile: Transferable {
    let url: URL
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .requiemCharacter) { file in
            try Data(contentsOf: file.url)
        }
        .suggestedFileName { $0.fileName }
    }

    var fileName: String {
        // Characters that can't appear in file names on either platform
        let unsafe = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)
        let cleaned = name.components(separatedBy: unsafe).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return (cleaned.isEmpty ? "Unnamed Character" : cleaned) + ".vtrcharacter"
    }
}
