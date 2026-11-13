//
//  RequiemIdentity.swift
//  RequiemCharacterSheet
//
//  Requiem Character Sheet's look and character files.
//

import SwiftUI
import UniformTypeIdentifiers

extension AppIdentity {
    static let current = AppIdentity(
        theme: .requiem,
        characterFileType: .requiemCharacter,
        characterFileExtension: "vtrcharacter"
    )
}

extension UTType {
    /// A shared character: the app's saved character JSON, under its own extension so the system offers
    /// to open it in the app. Declared in Info.plist; the Android app reads and writes the same files.
    static let requiemCharacter = UTType(exportedAs: "com.omccolgan.RequiemCharacterSheet.character")
}

extension Theme {
    /// Vampire: The Requiem's sheet.
    static let requiem = Theme(
        accent: Color(red: 88/255, green: 26/255, blue: 18/255),
        ink: .black,
        // Dark enough for small text on the white rows (WCAG 4.5:1): 5.2:1 and 5.3:1
        muted: Color(red: 108/255, green: 108/255, blue: 112/255),
        caution: Color(red: 140/255, green: 100/255, blue: 8/255),
        // Both under the SIL Open Font License; the licences are bundled beside them in Fonts/.
        // IM Fell English has every accented letter, so no fallback face is needed.
        displayFontName: "IM_FELL_English_Roman",
        displayFallbackFontName: nil,
        // IM Fell's numerals are old-style, which makes a column of ratings look uneven; Cinzel's sit level
        numeralFontName: "Cinzel-Medium",
        subheadingFontName: "Cinzel-Medium",
        borderImageName: "VtRBorder_NewStyle",
        logoImageName: "VtR 2nd ED Logo"
    )
}
