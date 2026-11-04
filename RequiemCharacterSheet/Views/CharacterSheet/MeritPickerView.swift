//
//  MeritPickerView.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// Chooses a Merit to add, grouped by category, asking for a qualifier when the Merit needs one.
/// Unmet prerequisites are shown as warnings; they don't stop the Merit being taken.
struct MeritPickerView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let character: Character
    /// Called with the chosen catalog entry and qualifier, or `nil` for a custom Merit.
    let onChoose: (MeritEntry?, String?) -> Void

    @State private var searchText = ""
    @State private var pendingEntry: MeritEntry?
    @State private var qualifierDraft = ""

    /// Alphabetical; when searching, Merits whose name matches come before those whose summary does.
    private var matchingEntries: [MeritEntry] {
        let entries = Catalog.bundled.merits.all.sorted { $0.name < $1.name }
        guard !searchText.isEmpty else { return entries }
        let nameMatches = entries.filter { $0.name.localizedStandardContains(searchText) }
        let summaryMatches = entries.filter {
            !$0.name.localizedStandardContains(searchText) && $0.summary.localizedStandardContains(searchText)
        }
        return nameMatches + summaryMatches
    }

    private static let categoryOrder: [MeritEntry.Category] = [.mental, .physical, .social, .fighting, .vampire, .covenant, .other, .supernatural]

    var body: some View {
        NavigationStack {
            List {
                let entries = matchingEntries
                // While searching, one list in relevance order; otherwise grouped by category
                if searchText.isEmpty {
                    ForEach(Self.categoryOrder, id: \.self) { category in
                        let inCategory = entries.filter { $0.category == category }
                        if !inCategory.isEmpty {
                            Section(header: Text(category.title).themedText(.subsectionHeader)) {
                                ForEach(inCategory) { row(for: $0) }
                            }
                        }
                    }
                } else {
                    Section {
                        ForEach(entries) { row(for: $0) }
                    }
                }

                Section {
                    let customFits = character.creationAllows(.merit(nil, rating: 1))
                    Button {
                        onChoose(nil, nil)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Custom Merit")
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
            .searchable(text: $searchText, prompt: "Search Merits")
            .navigationTitle("Add Merit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // Qualifiers with a fixed set of choices, e.g. Defensive Combat (Brawl or Weaponry)
            .confirmationDialog(
                pendingEntry.map { "\($0.name): choose \($0.qualifier?.prompt.lowercased() ?? "one")" } ?? "",
                isPresented: Binding(
                    get: { pendingEntry?.qualifier?.options != nil },
                    set: { if !$0 { pendingEntry = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingEntry
            ) { entry in
                ForEach(entry.qualifier?.options ?? [], id: \.self) { option in
                    Button(option) { choose(entry, qualifier: option) }
                }
            }
            // Free-text qualifiers, e.g. the language for Language
            .alert(
                pendingEntry.map { "\($0.name)" } ?? "",
                isPresented: Binding(
                    get: { pendingEntry != nil && pendingEntry?.qualifier?.options == nil },
                    set: { if !$0 { pendingEntry = nil } }
                ),
                presenting: pendingEntry
            ) { entry in
                TextField(entry.qualifier?.prompt ?? "Qualifier", text: $qualifierDraft)
                Button("Add") {
                    let trimmed = qualifierDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    choose(entry, qualifier: trimmed.isEmpty ? nil : trimmed)
                }
                Button("Cancel", role: .cancel) {}
            } message: { entry in
                Text("Enter the \(entry.qualifier?.prompt.lowercased() ?? "qualifier") this Merit is for.")
            }
        }
        .tint(theme.accent)
    }

    @ViewBuilder
    private func row(for entry: MeritEntry) -> some View {
        let isOwned = !entry.repeatable && character.merits.contains { $0.source == .catalog(entry.id) }
        let unmet = character.unmetPrerequisites(for: entry)
        // During guided creation, only Merits that fit the ten starting dots, and none Kindred can't take
        let fits = character.creationAllows(.merit(entry, rating: entry.ratings.min() ?? 1))
        Button {
            if entry.qualifier != nil {
                qualifierDraft = ""
                pendingEntry = entry
            } else {
                choose(entry, qualifier: nil)
            }
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.name)
                            .themedText(.traitName)
                        Text(entry.ratingsText)
                            .font(.system(size: 12))
                            .foregroundStyle(theme.accent)
                            .accessibilityLabel(ratingsAccessibilityLabel(entry))
                    }
                    Text(entry.summary)
                        .themedText(.detail)
                        .foregroundStyle(.primary)
                    if !fits {
                        Label(entry.unavailableToKindred ? PrerequisiteCheck.notForKindred : "Doesn't fit the starting Merit dots",
                              systemImage: "nosign")
                            .themedText(.detail)
                            .foregroundStyle(theme.muted)
                    } else if !unmet.isEmpty {
                        Label(unmet.warningText, systemImage: "exclamationmark.triangle")
                            .themedText(.detail)
                            .foregroundStyle(theme.accent)
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

    private func ratingsAccessibilityLabel(_ entry: MeritEntry) -> String {
        let ratings = entry.ratings.sorted()
        if ratings == [1] { return "1 dot" }
        return "\(ratings.map(String.init).joined(separator: ", ")) dots"
    }

    private func choose(_ entry: MeritEntry, qualifier: String?) {
        pendingEntry = nil
        onChoose(entry, qualifier)
        dismiss()
    }
}

extension MeritEntry.Category {
    var title: String {
        switch self {
        case .mental: return "Mental"
        case .physical: return "Physical"
        case .social: return "Social"
        case .fighting: return "Fighting"
        case .vampire: return "Vampire"
        case .covenant: return "Covenant"
        case .supernatural: return "Supernatural (not for Kindred)"
        case .other: return "Other"
        }
    }
}
