//
//  CatalogChoiceRow.swift
//  Chronicles
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
