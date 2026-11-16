//
//  ForsakenIdentity.swift
//  ForsakenCharacterSheet
//
//  Forsaken Character Sheet's look and character files.
//

import SwiftUI
import UniformTypeIdentifiers

extension AppIdentity {
    static let current = AppIdentity(
        theme: .forsaken,
        characterFileType: .forsakenCharacter,
        characterFileExtension: "wtfcharacter",
        bundledFonts: [
            BundledFont(name: "Comforter", author: "The Comforter Project Authors", licenseFile: "Comforter-OFL"),
            BundledFont(name: "Grechen Fuemen", author: "The Grechen Fuemen Project Authors", licenseFile: "GrechenFuemen-OFL"),
        ],
        fontCredits: ["Section headings lettered in Flat Earth Scribe by Nate Piekos of Blambot, used under licence."]
    )
}

extension UTType {
    /// A shared Forsaken character: the app's saved character JSON, under its own extension so the system offers
    /// to open it in this app rather than Requiem's. Declared in Info.plist.
    static let forsakenCharacter = UTType(exportedAs: "com.omccolgan.ForsakenCharacterSheet.character")
}

extension Theme {
    /// Werewolf: The Forsaken's sheet: Werewolf Rust, a brush line for headings, no border and the wolf skull behind
    /// the sheet. See docs/design-decisions.md.
    static let forsaken = Theme(
        // Werewolf Rust, #855A4A: 5.9:1 on white
        accent: Color(red: 0x85 / 255, green: 0x5A / 255, blue: 0x4A / 255),
        ink: .black,
        muted: Color(red: 108 / 255, green: 108 / 255, blue: 112 / 255),
        caution: Color(red: 140 / 255, green: 100 / 255, blue: 8 / 255),
        // The bundled faces are all under the SIL Open Font License; the licences are beside them in Fonts/.
        // Trait names, in place of the sheet's Arnova ITC
        displayFontName: "GrechenFuemen-Regular",
        displayFallbackFontName: nil,
        numeralFontName: nil,
        // Labels and subheadings, in place of the sheet's Treefrog
        subheadingFontName: "Comforter-Regular",
        borderImageName: nil,
        logoImageName: "WtF 2nd ED Logo",
        watermarkImageName: "WtF Skull Watermark",
        sectionHeaderStyle: .brushLine,
        fonts: [
            // Section headings are images in the sheet's Flat Earth Scribe (see headingImagePrefix); this face is for
            // the few headings that aren't, such as the books in pickers
            .sectionHeader: ThemeFont(name: "Comforter-Regular", size: 34, relativeTo: .title2),
            // Comforter's letters are small for their size, so it's set larger than the other faces
            .subsectionHeader: ThemeFont(name: "Comforter-Regular", size: 32, relativeTo: .headline),
            .label: ThemeFont(name: "Comforter-Regular", size: 30, relativeTo: .title3),
            .ratedTrait: ThemeFont(name: "GrechenFuemen-Regular", size: 23, relativeTo: .title3),
            .traitName: ThemeFont(name: "GrechenFuemen-Regular", size: 21, relativeTo: .title3),
            // The sheet's small print is rare enough to use the system font
            .note: ThemeFont(name: nil, size: 13, relativeTo: .footnote),
        ],
        traitNamesInAccent: false,
        // The pill must be easy to read; Grechen Fuemen's letters are small for their size
        controlFont: ThemeFont(name: "GrechenFuemen-Regular", size: 21, relativeTo: .subheadline),
        // The script faces are hard to read in About's lists and licences
        systemFontInAbout: true,
        // Drawn by scripts/render-forsaken-headings.swift; the face's licence covers graphics, not apps
        headingImagePrefix: "Heading "
    )
}
