//
//  SheetNavigation.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// A section of the character sheet, for the section pill in the navigation bar.
enum SheetSection: String, CaseIterable, Identifiable {
    case creation, character, attributes, skills, disciplines, devotions, rituals, coils, merits, aspirations,
         banes, health, willpower, bloodPotency, vitae, humanity, advantages, experience, conditions

    var id: Self { self }

    /// The name in the pill and its list.
    var title: String {
        switch self {
        case .creation: "Creation"
        case .character: "Character"
        case .attributes: "Attributes"
        case .skills: "Skills"
        case .disciplines: "Disciplines"
        case .devotions: "Devotions"
        case .rituals: "Rituals"
        case .coils: "Coils"
        case .merits: "Merits"
        case .aspirations: "Aspirations"
        case .banes: "Banes"
        case .health: "Health"
        case .willpower: "Willpower"
        case .bloodPotency: "Blood Potency"
        case .vitae: "Vitae"
        case .humanity: "Humanity"
        case .advantages: "Advantages"
        case .experience: "Experience"
        case .conditions: "Conditions"
        }
    }

    /// The section's heading on the sheet.
    var header: String {
        switch self {
        case .creation: "CHARACTER CREATION"
        case .coils: "COILS OF THE DRAGON"
        default: title.uppercased()
        }
    }
}

extension Character {
    /// The sections this character's sheet shows, in order.
    var sheetSections: [SheetSection] {
        SheetSection.allCases.filter { section in
            switch section {
            case .creation: isInCreation
            case .rituals: showsRituals
            case .coils: showsCoils
            default: true
            }
        }
    }
}

/// Where each section heading is, so the pill can name the section being read. A plain class rather than
/// observed state: headings move on every frame of a scroll, and only a change of section should redraw the sheet.
final class SheetSectionTracker {
    /// The top of each heading on screen, in screen coordinates. Headings scrolled out of the list are removed.
    private var headingTops: [SheetSection: CGFloat] = [:]
    /// The list's visible frame on screen.
    var listFrame: CGRect = .zero

    func update(_ section: SheetSection, top: CGFloat?) {
        headingTops[section] = top
    }

    /// How far below the list's top a heading counts as reached: about a heading's height, so a section
    /// jumped to (heading at the top) is named even when the next one starts soon after.
    static let readingLineOffset: CGFloat = 80

    /// The section being read: the last one whose heading is above the reading line near the list's top, or
    /// the one before the first heading on screen. `nil` when no heading is on screen, e.g. in the middle of a
    /// long section, so the pill keeps the name it had.
    func currentSection(in order: [SheetSection]) -> SheetSection? {
        let readingLine = listFrame.minY + Self.readingLineOffset
        let visible = order.filter { headingTops[$0] != nil }
        if let passed = visible.last(where: { headingTops[$0]! <= readingLine }) {
            return passed
        }
        guard let first = visible.first, let index = order.firstIndex(of: first) else { return nil }
        return index > 0 ? order[index - 1] : first
    }
}

/// Reports a section heading's position to the sheet; see `SheetSectionTracker`.
/// Always compares equal, as closures can't be compared.
struct ReportSectionHeadingAction: Equatable {
    private let report: (SheetSection, CGFloat?) -> Void

    init(_ report: @escaping (SheetSection, CGFloat?) -> Void) {
        self.report = report
    }

    func callAsFunction(_ section: SheetSection, top: CGFloat?) {
        report(section, top)
    }

    static func == (lhs: Self, rhs: Self) -> Bool { true }
}

extension EnvironmentValues {
    @Entry var reportSectionHeading = ReportSectionHeadingAction { _, _ in }
}

/// A section of the sheet that the section pill can jump to and follows while scrolling.
struct SheetSectionBlock<Content: View>: View {
    let section: SheetSection
    @ViewBuilder let content: Content

    init(_ section: SheetSection, @ViewBuilder content: () -> Content) {
        self.section = section
        self.content = content()
    }

    var body: some View {
        Section {
            // The heading is the section's first row rather than its header: lists scroll to rows, not headers
            SheetSectionHeader(section)
                .padding(.top, 13)
                .padding(.bottom, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                // Without a row's usual top and bottom insets, so it's the height the header was
                .listRowInsets(.vertical, 0)
                .listRowBackground(Color(uiColor: .systemGroupedBackground))
                .listRowSeparator(.hidden, edges: .top)
                .id(section)
            content
        }
    }
}

/// A section's heading, which reports where it is on screen.
struct SheetSectionHeader: View {
    @Environment(\.reportSectionHeading) private var reportSectionHeading
    let section: SheetSection

    init(_ section: SheetSection) {
        self.section = section
    }

    var body: some View {
        Text(section.header)
            .themedText(.sectionHeader)
            // The colour list headers have
            .foregroundStyle(.secondary)
            // A row now, so it needs telling VoiceOver it's a heading, as list headers do by themselves
            .accessibilityAddTraits(.isHeader)
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.frame(in: .global).minY
            } action: { top in
                reportSectionHeading(section, top: top)
            }
            .onDisappear {
                reportSectionHeading(section, top: nil)
            }
    }
}

/// The pill in the navigation bar: the section being read, and a chevron. Tapping it opens `SectionMenu`.
struct SectionPill: View {
    @Environment(\.theme) private var theme
    let current: SheetSection?
    @Binding var isOpen: Bool

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { isOpen.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(current?.title ?? "Sections")
                    .font(.custom(theme.subheadingFontName, size: 15, relativeTo: .subheadline))
                    .lineLimit(1)
                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(theme.accent))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel("Section")
        .accessibilityValue(current?.title ?? "")
        .accessibilityHint(isOpen ? "Double-tap to close the list of sections" : "Double-tap to jump to another section")
    }
}

/// The list of sections under the pill, with the current one highlighted. Tapping outside closes it.
struct SectionMenu: View {
    @Environment(\.theme) private var theme
    let sections: [SheetSection]
    let current: SheetSection?
    let choose: (SheetSection) -> Void
    let close: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Taps outside the list close it
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture(perform: close)
                .accessibilityHidden(true)

            // All of it if it fits, which it does at most text sizes; otherwise it scrolls
            ViewThatFits(in: .vertical) {
                rows
                ScrollView { rows }
            }
            .frame(width: 230)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.accent.opacity(0.5)))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            .padding(.leading, 60)
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
        .transition(.opacity)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(sections) { section in
                let isCurrent = section == current
                Button {
                    choose(section)
                } label: {
                    HStack {
                        Text(section.title)
                            .font(.custom(theme.subheadingFontName, size: 15, relativeTo: .subheadline))
                            .foregroundStyle(isCurrent ? Color.white : theme.accent)
                        Spacer()
                        if isCurrent {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isCurrent ? theme.accent : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
            }
        }
    }
}
