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
    /// Gentle warnings that last, such as Experiences below zero. A dark gold, readable as text and behind white.
    var caution: Color
    /// The display face used for headings and trait names.
    var displayFontName: String
    /// Draws letters the display face doesn't have (e.g. accented ones) instead of the system font, whose
    /// letters can look out of place. `nil` when the display face has every letter the app needs.
    var displayFallbackFontName: String?
    /// Draws the display face's digits instead, e.g. for level numerals beside a face whose old-style numerals
    /// rise and fall. `nil` to keep the display face's own.
    var numeralFontName: String?
    /// The small-caps face used for subheadings such as Mental, Physical and Social.
    var subheadingFontName: String
    var borderImageName: String
    var logoImageName: String

    /// Each style scales with the user's preferred text size, relative to the given system style.
    func font(_ style: ThemeTextStyle, dynamicTypeSize: DynamicTypeSize) -> Font {
        switch style {
        case .sectionHeader:
            return displayFont(size: 24, relativeTo: .title2, dynamicTypeSize: dynamicTypeSize)
        case .subsectionHeader:
            return .custom(subheadingFontName, size: 20, relativeTo: .headline)
        case .label:
            return displayFont(size: 22, relativeTo: .title3, dynamicTypeSize: dynamicTypeSize)
        case .traitName:
            return displayFont(size: 20, relativeTo: .title3, dynamicTypeSize: dynamicTypeSize)
        case .note:
            return displayFont(size: 16, relativeTo: .subheadline, dynamicTypeSize: dynamicTypeSize)
        case .body:
            return .callout
        case .detail:
            return .subheadline
        }
    }

    /// The display face, with its digits from `numeralFontName` and any missing letters from
    /// `displayFallbackFontName`. `Font.custom` can't take fallbacks, so this scales the font for the text size itself.
    private func displayFont(size: CGFloat, relativeTo textStyle: UIFont.TextStyle, dynamicTypeSize: DynamicTypeSize) -> Font {
        var descriptor = UIFontDescriptor(name: displayFontName, size: size)
        var cascade: [UIFontDescriptor] = []
        if let numeralFontName {
            // Leaving the digits out of the display face's characters makes them come from the next font in line
            var characters = CTFontCopyCharacterSet(CTFontCreateWithName(displayFontName as CFString, size, nil)) as CharacterSet
            characters.subtract(CharacterSet(charactersIn: "0123456789"))
            descriptor = descriptor.addingAttributes([.characterSet: characters])
            cascade.append(UIFontDescriptor(name: numeralFontName, size: size))
        }
        if let displayFallbackFontName {
            cascade.append(UIFontDescriptor(name: displayFallbackFontName, size: size))
        }
        if !cascade.isEmpty {
            descriptor = descriptor.addingAttributes([.cascadeList: cascade])
        }
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        let scaled = UIFontMetrics(forTextStyle: textStyle).scaledFont(for: UIFont(descriptor: descriptor, size: size), compatibleWith: traits)
        return Font(scaled as CTFont)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                .font(theme.font(style, dynamicTypeSize: dynamicTypeSize))
                .foregroundStyle(color)
        } else {
            content
                .font(theme.font(style, dynamicTypeSize: dynamicTypeSize))
        }
    }
}

extension View {
    /// Applies the current theme's font and colour for a text style.
    func themedText(_ style: ThemeTextStyle) -> some View {
        modifier(ThemedTextModifier(style: style))
    }
}
