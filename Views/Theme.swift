//
//  Theme.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// Everything game-specific about how the sheet looks, drawn from its official character sheet.
/// Views read the theme from the environment and use `themedText(_:)` and the theme's colours
/// rather than naming fonts or colours, so another game can supply its own look.
struct Theme {
    /// Highlights: filled dots, trait names, buttons.
    var accent: Color
    /// Outlines of dots and boxes, marks in boxes, and bonus dots.
    var ink: Color
    /// Placeholders and secondary text.
    var muted: Color
    /// The display face used for headings and trait names.
    var displayFontName: String
    /// The small-caps face used for subheadings such as Mental, Physical and Social.
    var subheadingFontName: String
    var borderImageName: String
    var logoImageName: String

    /// Each style scales with the user's preferred text size, relative to the given system style.
    func font(_ style: ThemeTextStyle) -> Font {
        switch style {
        case .sectionHeader:
            return .custom(displayFontName, size: 24, relativeTo: .title2)
        case .subsectionHeader:
            return .custom(subheadingFontName, size: 20, relativeTo: .headline)
        case .label:
            return .custom(displayFontName, size: 22, relativeTo: .title3)
        case .traitName:
            return .custom(displayFontName, size: 20, relativeTo: .title3)
        case .note:
            return .custom(displayFontName, size: 16, relativeTo: .subheadline)
        case .body:
            return .callout
        case .detail:
            return .subheadline
        }
    }

    /// The colour a text style is drawn in, or `nil` to keep the surrounding colour.
    func color(_ style: ThemeTextStyle) -> Color? {
        switch style {
        case .subsectionHeader, .label, .traitName:
            return accent
        case .note:
            return muted
        case .sectionHeader, .body, .detail:
            return nil
        }
    }

    static let requiem = Theme(
        accent: Color(red: 88/255, green: 26/255, blue: 18/255),
        ink: .black,
        muted: .gray,
        displayFontName: "CaslonAntique",
        subheadingFontName: "MrsEavesSmallCaps",
        borderImageName: "VtRBorder_NewStyle",
        logoImageName: "VtR 2nd ED Logo"
    )
}

enum ThemeTextStyle {
    /// Top-level sheet sections: CHARACTER, ATTRIBUTES, SKILLS…
    case sectionHeader
    /// Groups within a section: Mental, Physical, Social. Written in mixed case so the
    /// small capitals show, rather than uppercased like section headers.
    case subsectionHeader
    /// Row labels such as attribute names and "Speed:".
    case label
    /// Names of Disciplines and Merits.
    case traitName
    /// Small annotations such as "(-3 unskilled)".
    case note
    /// Entered text such as character details.
    case body
    /// Smaller entered text such as specialties and touchstones.
    case detail
}

extension EnvironmentValues {
    @Entry var theme: Theme = .requiem
}

struct ThemedTextModifier: ViewModifier {
    @Environment(\.theme) private var theme
    let style: ThemeTextStyle

    func body(content: Content) -> some View {
        if style == .subsectionHeader {
            // List headers are uppercased by default, which would hide the small capitals
            styled(content)
                .tracking(1.5)
                .textCase(nil)
        } else {
            styled(content)
        }
    }

    @ViewBuilder
    private func styled(_ content: Content) -> some View {
        if let color = theme.color(style) {
            content
                .font(theme.font(style))
                .foregroundStyle(color)
        } else {
            content
                .font(theme.font(style))
        }
    }
}

extension View {
    /// Applies the current theme's font and colour for a text style.
    func themedText(_ style: ThemeTextStyle) -> some View {
        modifier(ThemedTextModifier(style: style))
    }
}
