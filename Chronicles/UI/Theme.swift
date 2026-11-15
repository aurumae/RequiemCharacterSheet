//
//  Theme.swift
//  Chronicles
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
    /// The page border drawn round the screen. `nil` for none, as on the Werewolf sheet.
    var borderImageName: String?
    var logoImageName: String
    /// The skull drawn faintly behind the sheet, as on the official sheet: a template image tinted with `accent`.
    /// `nil` for none.
    var watermarkImageName: String? = nil
    /// How section headings are drawn, following the game's official sheet.
    var sectionHeaderStyle: SectionHeaderStyle = .row
    /// Faces for particular text styles, in place of the display and subheading faces, e.g. Forsaken's labels in
    /// Comforter. Styles not listed use the usual faces.
    var fonts: [ThemeTextStyle: ThemeFont] = [:]
    /// Whether trait names are drawn in the accent colour, as on the Vampire sheet, or in ink, as on the Werewolf one.
    var traitNamesInAccent = true
    /// The face for controls such as the section pill, which must be easy to read. `nil` to use the subheading face.
    var controlFontName: String? = nil

    /// Each style scales with the user's preferred text size, relative to the given system style.
    func font(_ style: ThemeTextStyle, dynamicTypeSize: DynamicTypeSize) -> Font {
        if let custom = fonts[style] {
            return custom.font
        }
        switch style {
        case .sectionHeader:
            return displayFont(size: 24, relativeTo: .title2, dynamicTypeSize: dynamicTypeSize)
        case .subsectionHeader:
            return .custom(subheadingFontName, size: 20, relativeTo: .headline)
        case .label, .ratedTrait:
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

    /// The face for controls such as the section pill, at the given size.
    func controlFont(size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
        .custom(controlFontName ?? subheadingFontName, size: size, relativeTo: textStyle)
    }

    /// The small capitals for a heading set with `.smallCapitals`: the heading face, a little smaller.
    var smallCapitalHeadingFont: Font {
        let heading = fonts[.sectionHeader]
        return .custom(heading?.name ?? displayFontName, size: (heading?.size ?? 24) * 0.78, relativeTo: heading?.relativeTo ?? .title2)
    }

    /// The colour a text style is drawn in, or `nil` to keep the surrounding colour.
    func color(_ style: ThemeTextStyle) -> Color? {
        switch style {
        case .subsectionHeader, .label:
            return accent
        case .ratedTrait, .traitName:
            return traitNamesInAccent ? accent : nil
        case .note:
            return muted
        case .sectionHeader, .body, .detail:
            return nil
        }
    }
}

/// A face and size for one text style, in place of the theme's usual face for it.
struct ThemeFont {
    /// `nil` for the system font.
    let name: String?
    let size: CGFloat
    /// The system style it scales with, as the user's text size changes.
    let relativeTo: Font.TextStyle

    var font: Font {
        if let name {
            .custom(name, size: size, relativeTo: relativeTo)
        } else {
            .system(relativeTo)
        }
    }
}

/// How a game's sheet draws its section headings.
enum SectionHeaderStyle {
    /// A grey row with the heading in capitals, adapted from the Vampire sheet's dark bars.
    case row
    /// The heading in small capitals between two brush strokes, as on the Werewolf sheet.
    case brushLine
}

enum ThemeTextStyle {
    /// Top-level sheet sections: CHARACTER, ATTRIBUTES, SKILLS…
    case sectionHeader
    /// Groups within a section: Mental, Physical, Social. Written in mixed case so the
    /// small capitals show, rather than uppercased like section headers.
    case subsectionHeader
    /// Row labels such as "Name:" and "Speed:".
    case label
    /// Names of rated traits with dots beside them, such as Attributes and Skills.
    case ratedTrait
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
    @Entry var theme: Theme = AppIdentity.current.theme
}

struct ThemedTextModifier: ViewModifier {
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let style: ThemeTextStyle

    func body(content: Content) -> some View {
        if style == .subsectionHeader && theme.fonts[.subsectionHeader] == nil {
            // List headers are uppercased by default, which would hide the small capitals
            styled(content)
                .tracking(1.5)
                .textCase(nil)
        } else if style == .subsectionHeader {
            styled(content)
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
