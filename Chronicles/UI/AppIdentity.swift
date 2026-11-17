//
//  AppIdentity.swift
//  Chronicles
//
//  What makes each game's app its own: its look and its character files. Each app defines `AppIdentity.current`.
//

import UniformTypeIdentifiers

struct AppIdentity {
    let theme: Theme
    /// The type of the app's shared character files, declared in its Info.plist.
    let characterFileType: UTType
    /// The extension shared character files are saved with, e.g. "vtrcharacter".
    let characterFileExtension: String
    /// Every font the app bundles, credited in About. Each is under the SIL Open Font License, which asks that its
    /// licence ship with it.
    let bundledFonts: [BundledFont]
    /// Faces used only in the app's pictures, not bundled, credited in About, e.g. "Section headings: Flat Earth
    /// Scribe by Blambot".
    var fontCredits: [String] = []
}

extension UTType {
    /// This app's shared character files.
    static var characterFile: UTType { AppIdentity.current.characterFileType }
}
