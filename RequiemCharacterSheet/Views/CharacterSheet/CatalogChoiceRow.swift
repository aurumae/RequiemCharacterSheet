//
//  CatalogChoiceRow.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// The details shown when a choice's label is tapped, e.g. the chosen clan's favoured Attributes and bane.
struct CatalogChoiceDetail {
    let title: String
    let summary: String
    let citation: String
    var facts: [DetailFact] = []
}

/// A character detail chosen from the catalog, e.g. "Clan: Ventrue". Tapping the value opens a list of the
/// book's options with a short description, then a custom option, and "none" where that makes sense.
/// Tapping the label shows the chosen entry's details, or the list if nothing from the book is chosen.
struct CatalogChoiceRow: View {
    @Environment(\.theme) private var theme
    let label: String
    /// The current choice, e.g. "Ventrue", or empty.
    let value: String
    /// Whether the current choice is the player's own text rather than a catalog entry.
    let isCustom: Bool
    /// Sets the player's own text. Text that names a catalog entry links to it.
    let setCustomText: (String) -> Void
    let pickerTitle: String
    let searchPrompt: String
    let sections: () -> [CatalogPickerSection]
    /// e.g. "Custom Clan".
    let customTitle: String
    /// e.g. "Unaligned" for covenants; `nil` if there's no "none" option.
    var noneTitle: String?
    /// The chosen catalog entry's details; `nil` when it's custom or nothing is chosen.
    let detail: () -> CatalogChoiceDetail?
    /// Called with the chosen catalog entry, or `nil` for none.
    let choose: (CatalogEntryID?) -> Void

    @State private var showingPicker = false
    @State private var shownDetail: CatalogChoiceDetail?
    /// The custom option was chosen; its text field opens once the picker has closed.
    @State private var editsCustomOnDismiss = false
    @State private var editsCustom = false

    private var trimmedLabel: String {
        label.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
    }

    var body: some View {
        HStack {
            let detail = detail()
            Button {
                if let detail {
                    shownDetail = detail
                } else {
                    showingPicker = true
                }
            } label: {
                Text(label)
                    .themedText(.label)
                    .frame(minWidth: 100, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(detail.map { "\($0.title) details" } ?? trimmedLabel)
            .accessibilityHint(detail == nil ? "Double-tap to choose" : "Shows its details")
            .hostedSheet(isPresented: Binding(get: { shownDetail != nil }, set: { if !$0 { shownDetail = nil } })) {
                if let shownDetail {
                    CatalogDetailView(
                        title: shownDetail.title,
                        summary: shownDetail.summary,
                        citation: shownDetail.citation,
                        facts: shownDetail.facts
                    )
                }
            }

            Spacer()

            if editsCustom {
                TapToEditText(
                    placeholder: "\(trimmedLabel) name",
                    accessibilityName: trimmedLabel,
                    text: Binding(get: { isCustom ? value : "" }, set: { text in
                        setCustomText(text)
                        editsCustom = false
                    }),
                    beginsEditing: true
                ) { text in
                    Text(text).themedText(.body)
                }
            } else {
                Button {
                    showingPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text(value.isEmpty ? "Choose" : value)
                            .themedText(.body)
                            .foregroundStyle(value.isEmpty ? theme.muted : Color.primary)
                            .multilineTextAlignment(.trailing)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(theme.accent)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(trimmedLabel)
                .accessibilityValue(value.isEmpty ? "Not chosen" : value)
                .accessibilityHint("Double-tap to choose")
            }
        }
        .padding(.vertical, 4)
        .editingRow("info-\(label)")
        .hostedSheet(isPresented: $showingPicker, onDismiss: {
            if editsCustomOnDismiss {
                editsCustomOnDismiss = false
                editsCustom = true
            }
        }) {
            CatalogPickerView(
                title: pickerTitle,
                searchPrompt: searchPrompt,
                sections: sections(),
                customOptions: [CatalogPickerCustomOption(id: "custom", title: customTitle)]
                    + (noneTitle.map { [CatalogPickerCustomOption(id: "none", title: $0, subtitle: "Clear the \(trimmedLabel.lowercased()).")] } ?? [])
            ) { choice in
                switch choice {
                case .entry(let id):
                    choose(id)
                case .custom("none"):
                    choose(nil)
                case .custom:
                    editsCustomOnDismiss = true
                }
            }
        }
    }
}

extension Character {
    var clanDetail: CatalogChoiceDetail? {
        clanEntry.map { clan in
            CatalogChoiceDetail(title: clan.name, summary: clan.summary, citation: clan.source.citation(), facts: [
                DetailFact(label: "Favoured Attributes", value: favoredAttributesDetail(clan.favoredAttributes)),
                DetailFact(label: "Disciplines", value: disciplineNames(clan.disciplines)),
                DetailFact(label: "Bane", value: "\(clan.bane.name). \(clan.bane.summary)"),
            ])
        }
    }

    var bloodlineDetail: CatalogChoiceDetail? {
        bloodlineEntry.map { bloodline in
            CatalogChoiceDetail(title: bloodline.name, summary: bloodline.summary, citation: bloodline.source.citation(), facts: [
                DetailFact(label: "Parent clan", value: bloodline.parentClansText),
            ] + (bloodline.requiredCovenant.map { [DetailFact(label: "Covenant", value: Catalog.bundled.covenants.entry($0)?.name ?? $0)] } ?? []) + [
                DetailFact(label: "Disciplines", value: disciplineNames(bloodline.disciplines)),
                DetailFact(label: "Bane", value: "\(bloodline.bane.name). \(bloodline.bane.summary)"),
            ] + (bloodline.favoredAttributes.isEmpty ? [] : [
                DetailFact(label: "Favoured Attributes", value: favoredAttributesDetail(bloodline.favoredAttributes)),
            ]))
        }
    }

    /// One list's favoured Attributes; with a bloodline that has its own, both lists, each marked with its source.
    /// During guided creation the bloodline's replace the clan's, so only the bloodline's are shown.
    private func favoredAttributesDetail(_ own: [AttributeKind]) -> String {
        if isInCreation { return creationFavoredAttributes.map(\.name).joined(separator: " or ") }
        if bloodlineEntry?.favoredAttributes.isEmpty == false { return favoredAttributesText }
        return own.map(\.name).joined(separator: " or ")
    }

    var covenantDetail: CatalogChoiceDetail? {
        covenantEntry.map { CatalogChoiceDetail(title: $0.name, summary: $0.summary, citation: $0.source.citation()) }
    }

    /// The book's Mask or Dirge archetype with this name, if it is one, with its sample Willpower actions.
    func archetypeDetail(named name: String) -> CatalogChoiceDetail? {
        guard let archetype = Catalog.bundled.archetypes.entry(named: name) else { return nil }
        return CatalogChoiceDetail(
            title: archetype.name,
            summary: archetype.summary,
            citation: archetype.source.citation(),
            facts: archetype.willpowerFacts.map { DetailFact(label: $0.label, value: $0.value) }
        )
    }

    /// Mask and Dirge archetypes for the picker; the same list serves both.
    func archetypePickerSections(chosen: String) -> [CatalogPickerSection] {
        let archetypes = Catalog.bundled.archetypes.all.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return CatalogPickerSection.byBook([CatalogPickerGroup("", archetypes)]) { archetype in
            CatalogPickerItem(
                id: archetype.id,
                name: archetype.name,
                summary: archetype.summary,
                details: archetype.willpowerFacts.map { "\($0.label): \($0.value)" },
                citation: archetype.source.citation(),
                isOwned: archetype.name == chosen
            )
        }
    }

    private func disciplineNames(_ ids: [CatalogEntryID]) -> String {
        ids.compactMap { Catalog.bundled.disciplines.entry($0)?.name }.joined(separator: ", ")
    }

    /// Clans for the picker, each with its favoured Attributes and in-clan Disciplines.
    func clanPickerSections() -> [CatalogPickerSection] {
        let clans = Catalog.bundled.clans.all.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return CatalogPickerSection.byBook([CatalogPickerGroup("", clans)]) { clan in
            let attributes = clan.favoredAttributes.map(\.name).joined(separator: " or ")
            let disciplines = clan.disciplines.compactMap { Catalog.bundled.disciplines.entry($0)?.name }.joined(separator: ", ")
            return CatalogPickerItem(
                id: clan.id,
                name: clan.name,
                summary: clan.summary,
                details: ["Favoured: \(attributes)", "Disciplines: \(disciplines)"],
                citation: clan.source.citation(),
                isOwned: clanSource == .catalog(clan.id)
            )
        }
    }

    func covenantPickerSections() -> [CatalogPickerSection] {
        let covenants = Catalog.bundled.covenants.all.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return CatalogPickerSection.byBook([CatalogPickerGroup("", covenants)]) { covenant in
            CatalogPickerItem(
                id: covenant.id,
                name: covenant.name,
                summary: covenant.summary,
                citation: covenant.source.citation(),
                isOwned: covenantSource == .catalog(covenant.id)
            )
        }
    }

    /// By book; within each, bloodlines of the character's clan first. Others are listed with their parent clan as a
    /// reminder.
    func bloodlinePickerSections() -> [CatalogPickerSection] {
        let all = Catalog.bundled.bloodlines.all.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        func item(_ bloodline: BloodlineEntry) -> CatalogPickerItem {
            let parents = bloodline.parentClansText
            let disciplines = bloodline.disciplines.compactMap { Catalog.bundled.disciplines.entry($0)?.name }.joined(separator: ", ")
            let fits = clanEntry.map { bloodline.accepts(clan: $0.id) } ?? true
            // Some bloodlines take members from one covenant only, e.g. the Penumbrae from the Circle of the Crone
            let covenantWarning = bloodline.requiredCovenant.flatMap { required -> String? in
                guard covenantSource != .catalog(required), statusStandIn(for: required) == nil else { return nil }
                return "Members must belong to the \(Catalog.bundled.covenants.entry(required)?.name ?? required)"
            }
            return CatalogPickerItem(
                id: bloodline.id,
                name: bloodline.name,
                summary: bloodline.summary,
                details: ["Parent clan: \(parents)"]
                    + (bloodline.requiredCovenant.map { ["Covenant: \(Catalog.bundled.covenants.entry($0)?.name ?? $0)"] } ?? [])
                    + ["Disciplines: \(disciplines)", "Bane: \(bloodline.bane.name)"]
                    + (bloodline.favoredAttributes.isEmpty ? [] : ["Favoured: \(bloodline.favoredAttributes.map(\.name).joined(separator: " or "))"]),
                warning: fits ? covenantWarning : "A bloodline of the \(parents)",
                citation: bloodline.source.citation(),
                isOwned: bloodlineSource == .catalog(bloodline.id)
            )
        }
        guard let clan = clanEntry else {
            return CatalogPickerSection.byBook([CatalogPickerGroup("", all)], item: item)
        }
        let own = all.filter { $0.accepts(clan: clan.id) }
        let others = all.filter { !$0.accepts(clan: clan.id) }
        return CatalogPickerSection.byBook([
            CatalogPickerGroup("\(clan.name) Bloodlines", own),
            CatalogPickerGroup(own.isEmpty ? "" : "Other Bloodlines", others),
        ], item: item)
    }
}
