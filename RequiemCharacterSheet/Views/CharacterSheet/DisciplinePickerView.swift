//
//  DisciplinePickerView.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// Chooses a Discipline to add: in-clan ones first, then the rest of the catalog, or a custom one.
struct DisciplinePickerView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let character: Character
    /// Called with the chosen catalog entry, or `nil` for a custom Discipline.
    let onChoose: (DisciplineEntry?) -> Void

    @State private var searchText = ""

    /// Alphabetical; when searching, Disciplines whose name matches come before those whose summary does.
    private var matchingEntries: [DisciplineEntry] {
        let entries = Catalog.bundled.disciplines.all.sorted { $0.name < $1.name }
        guard !searchText.isEmpty else { return entries }
        let nameMatches = entries.filter { $0.name.localizedStandardContains(searchText) }
        let summaryMatches = entries.filter {
            !$0.name.localizedStandardContains(searchText) && $0.summary.localizedStandardContains(searchText)
        }
        return nameMatches + summaryMatches
    }

    private var owned: Set<CatalogEntryID> {
        Set(character.disciplines.compactMap { $0.source.catalogID })
    }

    var body: some View {
        NavigationStack {
            List {
                let inClan = matchingEntries.filter { character.inClanDisciplines.contains($0.id) }
                let others = matchingEntries.filter { !character.inClanDisciplines.contains($0.id) }

                if !inClan.isEmpty {
                    Section(header: Text("In-clan for the \(character.clan)").themedText(.subsectionHeader)) {
                        ForEach(inClan) { entry in
                            row(for: entry)
                        }
                    }
                }

                Section(header: Text(inClan.isEmpty ? "Disciplines" : "Other Disciplines").themedText(.subsectionHeader)) {
                    ForEach(others) { entry in
                        row(for: entry)
                    }
                }

                Section {
                    let customFits = character.creationAllows(.discipline(nil))
                    Button {
                        choose(nil)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Custom Discipline")
                                .themedText(.traitName)
                            Text("For homebrew, or one that isn't listed.")
                                .themedText(.detail)
                                .foregroundStyle(theme.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!customFits)
                    .opacity(customFits ? 1 : 0.5)
                }
            }
            .searchable(text: $searchText, prompt: "Search Disciplines")
            .navigationTitle("Add Discipline")
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
    private func row(for entry: DisciplineEntry) -> some View {
        let isOwned = owned.contains(entry.id)
        // During guided creation, only Disciplines that fit the three starting dots
        let fits = character.creationAllows(.discipline(entry))
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
                    if !fits {
                        Label(creationReason(for: entry), systemImage: "nosign")
                            .themedText(.detail)
                            .foregroundStyle(theme.muted)
                    }
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
        .disabled(isOwned || !fits)
        .opacity(fits ? 1 : 0.5)
    }

    /// Why a Discipline can't start on the sheet, e.g. Crúac without Circle of the Crone Status.
    private func creationReason(for entry: DisciplineEntry) -> String {
        let added = character.creationReport(levels: character.traitSnapshot.levels, adding: .discipline(entry)).problems
        let existing = character.creationReport.problems
        return added.subtracting(existing).first?.description ?? "Doesn't fit the starting Discipline dots"
    }

    private func choose(_ entry: DisciplineEntry?) {
        onChoose(entry)
        dismiss()
    }
}
