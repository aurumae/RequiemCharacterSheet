//
//  BanePickerView.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// Chooses a Bane to add from the catalog, or a custom one described in the player's own words.
struct BanePickerView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let character: Character
    /// Called with the chosen catalog entry, or `nil` for a custom Bane.
    let onChoose: (BaneEntry?) -> Void

    @State private var searchText = ""

    /// Alphabetical; when searching, Banes whose name matches come before those whose summary does.
    private var matchingEntries: [BaneEntry] {
        let entries = Catalog.bundled.banes.all.sorted { $0.name < $1.name }
        guard !searchText.isEmpty else { return entries }
        let nameMatches = entries.filter { $0.name.localizedStandardContains(searchText) }
        let summaryMatches = entries.filter {
            !$0.name.localizedStandardContains(searchText) && $0.summary.localizedStandardContains(searchText)
        }
        return nameMatches + summaryMatches
    }

    private var owned: Set<CatalogEntryID> {
        Set(character.banes.compactMap { $0.source.catalogID })
    }

    var body: some View {
        NavigationStack {
            List {
                Section(footer: Text("A vampire can have at most \(Character.maxBanes) Banes.").themedText(.detail)) {
                    ForEach(matchingEntries) { entry in
                        row(for: entry)
                    }
                }

                Section {
                    Button {
                        choose(nil)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Custom Bane")
                                .themedText(.traitName)
                            Text("Describe a Bane in your own words.")
                                .themedText(.detail)
                                .foregroundStyle(theme.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "Search Banes")
            .navigationTitle("Add Bane")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(theme.accent)
    }

    @ViewBuilder
    private func row(for entry: BaneEntry) -> some View {
        let isOwned = owned.contains(entry.id)
        Button {
            choose(entry)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .themedText(.traitName)
                    Text(entry.summary)
                        .themedText(.detail)
                        .foregroundStyle(.primary)
                    Text(entry.source.citation())
                        .themedText(.detail)
                        .foregroundStyle(theme.muted)
                }
                Spacer()
                if isOwned {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.accent)
                        .accessibilityLabel("Already on the sheet")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isOwned)
    }

    private func choose(_ entry: BaneEntry?) {
        onChoose(entry)
        dismiss()
    }
}
