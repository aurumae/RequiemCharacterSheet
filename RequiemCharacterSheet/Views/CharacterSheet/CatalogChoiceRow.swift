//
//  CatalogChoiceRow.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// A character detail chosen from the catalog, e.g. "Clan: Ventrue". Tapping the value opens a list of the
/// book's options with a short description, then a custom option, and "none" where that makes sense.
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
    /// Called with the chosen catalog entry, or `nil` for none.
    let choose: (CatalogEntryID?) -> Void

    @State private var showingPicker = false
    /// The custom option was chosen; its text field opens once the picker has closed.
    @State private var editsCustomOnDismiss = false
    @State private var editsCustom = false

    private var trimmedLabel: String {
        label.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
    }

    var body: some View {
        HStack {
            Text(label)
                .themedText(.label)
                .frame(minWidth: 100, alignment: .leading)

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
        .sheet(isPresented: $showingPicker, onDismiss: {
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
    /// Clans for the picker, each with its favoured Attributes and in-clan Disciplines.
    func clanPickerSections() -> [CatalogPickerSection] {
        let items = Catalog.bundled.clans.all.sorted { $0.name < $1.name }.map { clan in
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
        return [CatalogPickerSection(title: "Clans", items: items)]
    }

    func covenantPickerSections() -> [CatalogPickerSection] {
        let items = Catalog.bundled.covenants.all.sorted { $0.name < $1.name }.map { covenant in
            CatalogPickerItem(
                id: covenant.id,
                name: covenant.name,
                summary: covenant.summary,
                citation: covenant.source.citation(),
                isOwned: covenantSource == .catalog(covenant.id)
            )
        }
        return [CatalogPickerSection(title: "Covenants", items: items)]
    }

    /// Bloodlines of the character's clan first. Others are listed with their parent clan as a reminder.
    func bloodlinePickerSections() -> [CatalogPickerSection] {
        let all = Catalog.bundled.bloodlines.all.sorted { $0.name < $1.name }
        func item(_ bloodline: BloodlineEntry) -> CatalogPickerItem {
            let parents = bloodline.parentClans.compactMap { Catalog.bundled.clans.entry($0)?.name }.joined(separator: " or ")
            let disciplines = bloodline.disciplines.compactMap { Catalog.bundled.disciplines.entry($0)?.name }.joined(separator: ", ")
            let fits = clanEntry.map { bloodline.parentClans.contains($0.id) } ?? true
            return CatalogPickerItem(
                id: bloodline.id,
                name: bloodline.name,
                summary: bloodline.summary,
                details: ["Parent clan: \(parents)", "Disciplines: \(disciplines)", "Bane: \(bloodline.bane.name)"],
                warning: fits ? nil : "A bloodline of the \(parents)",
                citation: bloodline.source.citation(),
                isOwned: bloodlineSource == .catalog(bloodline.id)
            )
        }
        guard let clan = clanEntry else {
            return [CatalogPickerSection(title: "Bloodlines", items: all.map(item))]
        }
        let own = all.filter { $0.parentClans.contains(clan.id) }
        let others = all.filter { !$0.parentClans.contains(clan.id) }
        return [
            CatalogPickerSection(title: "\(clan.name) Bloodlines", items: own.map(item)),
            CatalogPickerSection(title: own.isEmpty ? "Bloodlines" : "Other Bloodlines", items: others.map(item)),
        ]
    }
}
