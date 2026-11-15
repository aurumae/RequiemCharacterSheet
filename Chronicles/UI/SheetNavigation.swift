//
//  SheetNavigation.swift
//  Chronicles
//

import SwiftUI

/// A section of the character sheet, for the section pill in the navigation bar. Each game lists its own;
/// the ones every game has are below.
struct SheetSection: Hashable, Identifiable {
    let id: String
    /// The name in the pill and its list.
    let title: String
    /// The section's heading on the sheet, in mixed case, e.g. "Coils of the Dragon". Each game's header style
    /// sets it in capitals or small capitals.
    let heading: String

    init(_ id: String, title: String, heading: String? = nil) {
        self.id = id
        self.title = title
        self.heading = heading ?? title
    }

    static let character = SheetSection("character", title: "Character")
    static let attributes = SheetSection("attributes", title: "Attributes")
    static let skills = SheetSection("skills", title: "Skills")
    static let merits = SheetSection("merits", title: "Merits")
    static let aspirations = SheetSection("aspirations", title: "Aspirations")
    static let health = SheetSection("health", title: "Health")
    static let willpower = SheetSection("willpower", title: "Willpower")
    static let advantages = SheetSection("advantages", title: "Advantages")
    static let experience = SheetSection("experience", title: "Experience")
    static let conditions = SheetSection("conditions", title: "Conditions")
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
    @Environment(\.theme) private var theme
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
                .listRowBackground(theme.sectionHeaderStyle == .row ? Color(uiColor: .systemGroupedBackground) : nil)
                .listRowSeparator(.hidden, edges: .top)
                .id(section)
            content
        }
    }
}

/// A section's heading, which reports where it is on screen.
struct SheetSectionHeader: View {
    @Environment(\.reportSectionHeading) private var reportSectionHeading
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let section: SheetSection

    init(_ section: SheetSection) {
        self.section = section
    }

    var body: some View {
        heading
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

extension SheetSectionHeader {
    @ViewBuilder
    private var heading: some View {
        switch theme.sectionHeaderStyle {
        case .row:
            Text(section.heading.uppercased())
                .themedText(.sectionHeader)
                // The colour list headers have
                .foregroundStyle(.secondary)
        case .brushLine:
            HStack(spacing: 8) {
                BrushLine(seed: section.id + "-leading", solidEnd: .trailing)
                    .frame(minWidth: 16)
                smallCapitals(section.heading)
                    .foregroundStyle(theme.accent)
                    .multilineTextAlignment(.center)
                    .layoutPriority(1)
                BrushLine(seed: section.id + "-trailing", solidEnd: .leading)
                    .frame(minWidth: 16)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(section.heading)
        }
    }

    /// Capitals stay full size and lower-case letters become small capitals, as the Werewolf sheet sets its
    /// headings. Drawn with two sizes of the face, as the heading faces have no small capitals of their own.
    private func smallCapitals(_ text: String) -> Text {
        var result = AttributedString()
        for character in text {
            var run = AttributedString(String(character).uppercased())
            run.font = character.isLowercase ? theme.smallCapitalHeadingFont : theme.font(.sectionHeader, dynamicTypeSize: dynamicTypeSize)
            result += run
        }
        return Text(result)
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
                    .font(theme.controlFont(size: 15, relativeTo: .subheadline))
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
                            .font(theme.controlFont(size: 15, relativeTo: .subheadline))
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
