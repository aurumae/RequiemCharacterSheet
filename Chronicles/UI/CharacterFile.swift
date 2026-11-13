//
//  CharacterFile.swift
//  Chronicles
//

import CoreTransferable
import UniformTypeIdentifiers

/// A saved character shared as "<Name>.<the app's extension>", e.g. "Lucius.vtrcharacter". The file is read only
/// when it's actually shared.
struct CharacterFile: Transferable {
    let url: URL
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .characterFile) { file in
            try Data(contentsOf: file.url)
        }
        .suggestedFileName { $0.fileName }
    }

    var fileName: String {
        // Characters that can't appear in file names on either platform
        let unsafe = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)
        let cleaned = name.components(separatedBy: unsafe).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return (cleaned.isEmpty ? "Unnamed Character" : cleaned) + "." + AppIdentity.current.characterFileExtension
    }
}
