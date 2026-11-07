//
//  RitualsView.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// Crúac rites and Theban miracles, grouped by the Discipline that casts them.
struct RitualsView: View {
    @Environment(\.theme) private var theme
    let character: Character
    @State private var showingPicker = false
    @State private var newCustomRitualID: UUID?
    /// The Discipline chosen for a custom ritual; the row is added once the picker has closed,
    /// so its name field can take keyboard focus.
    @State private var customRitualDiscipline: CatalogEntryID?

    var body: some View {
        Section(header: Text("RITUALS").themedText(.sectionHeader)) {
            ForEach(groups, id: \.discipline) { group in
                Section(header: Text(group.title).themedText(.subsectionHeader)) {
                    if let id = group.discipline.catalogID, character.disciplineRating(id) > 0 {
                        // Each dot comes with one ritual; the rest cost Experiences
                        Text("Known: \(group.rituals.count) · Free with \(group.title) dots: \(character.freeRitualCount(for: id))")
                            .themedText(.detail)
                            .foregroundStyle(theme.muted)
                    }
                    ForEach(group.rituals) { ritual in
                        RitualRowView(ritual: ritual, character: character, beginsEditing: ritual.id == newCustomRitualID)
                            .editingRow(ritual.id)
                    }
                    .onDelete { offsets in
                        let removed = offsets.map { group.rituals[$0].id }
                        character.rituals.removeAll { removed.contains($0.id) }
                    }
                }
            }

            AddRowButton("Add Ritual") {
                showingPicker = true
            }
            .hostedSheet(isPresented: $showingPicker, onDismiss: addCustomRitualIfChosen) {
                CatalogPickerView(
                    title: "Add Ritual",
                    searchPrompt: "Search Rituals",
                    sections: pickerSections,
                    customOptions: pickerDisciplines.map {
                        CatalogPickerCustomOption(
                            id: $0.id,
                            title: "Custom \($0.name) Ritual",
                            isAvailable: character.creationAllows(.ritual(discipline: .catalog($0.id), dots: 1))
                        )
                    }
                ) { choice in
                    switch choice {
                    case .entry(let id):
                        character.rituals.append(Ritual(source: .catalog(id)))
                    case .custom(let disciplineID):
                        customRitualDiscipline = disciplineID
                    }
                }
            }
        }
    }

    private struct Group {
        let discipline: TraitSource
        let title: String
        let rituals: [Ritual]
    }

    /// One group per Ritual Discipline on the sheet, even with no rituals yet, then any others with rituals.
    private var groups: [Group] {
        var disciplines = character.ritualDisciplines.map { TraitSource.catalog($0.id) }
        for ritual in character.rituals where !disciplines.contains(ritual.discipline) {
            disciplines.append(ritual.discipline)
        }
        return disciplines.map { discipline in
            let name = Catalog.bundled.disciplines.name(of: discipline)
            return Group(discipline: discipline, title: name.isEmpty ? "Other Rituals" : name, rituals: character.rituals(of: discipline))
        }
    }

    /// The character's Ritual Disciplines, or every one in the catalog if they have none yet.
    private var pickerDisciplines: [DisciplineEntry] {
        let owned = character.ritualDisciplines
        return owned.isEmpty ? Catalog.bundled.disciplines.all.filter { $0.kind == .ritual } : owned
    }

    private var pickerSections: [CatalogPickerSection] {
        let owned = Set(character.rituals.compactMap(\.source.catalogID))
        let others = Catalog.bundled.disciplines.all.filter { $0.kind == .ritual && !pickerDisciplines.map(\.id).contains($0.id) }
        return (pickerDisciplines + others).map { discipline in
            let rating = character.disciplineRating(discipline.id)
            let items = Catalog.bundled.rituals.all
                .filter { $0.discipline == discipline.id }
                .sorted { ($0.dots, $0.name) < ($1.dots, $1.name) }
                .map { entry in
                    CatalogPickerItem(
                        id: entry.id,
                        name: entry.name,
                        dots: entry.dots,
                        summary: entry.summary,
                        details: ["Target successes: \(entry.targetSuccesses)"],
                        warning: rating < entry.dots ? "Requires \(discipline.name) \(entry.dots)" : nil,
                        citation: entry.source.citation(),
                        isOwned: owned.contains(entry.id),
                        // During guided creation, only the ritual that comes with each dot
                        unavailableReason: character.creationAllows(.ritual(discipline: .catalog(discipline.id), dots: entry.dots))
                            ? nil : "Doesn't fit: one ritual per \(discipline.name) dot at creation"
                    )
                }
            return CatalogPickerSection(title: discipline.name, items: items)
        }
    }

    private func addCustomRitualIfChosen() {
        guard let disciplineID = customRitualDiscipline else { return }
        customRitualDiscipline = nil
        let ritual = Ritual(source: .custom(""), customDiscipline: .catalog(disciplineID))
        newCustomRitualID = ritual.id
        character.rituals.append(ritual)
    }
}

struct RitualRowView: View {
    @Bindable var ritual: Ritual
    let character: Character
    var beginsEditing = false
    @State private var showingDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                if let entry = ritual.entry {
                    Button {
                        showingDetail = true
                    } label: {
                        Text(entry.name)
                            .themedText(.traitName)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows its details")
                    .hostedSheet(isPresented: $showingDetail) {
                        RitualDetailView(entry: entry, character: character)
                    }

                    Spacer()

                    DotsText(entry.dots)
                } else {
                    TapToEditText(placeholder: "Ritual Name", text: $ritual.name, beginsEditing: beginsEditing) { name in
                        Text(name)
                            .themedText(.traitName)
                    }

                    Spacer()

                    DotsRatingView(
                        ritual.name.isEmpty ? "Ritual" : ritual.name,
                        rating: Binding(get: { ritual.customDots }, set: { ritual.customDots = max($0, 1) }),
                        maxRating: 5
                    )
                }
            }

            ForEach(character.warnings(for: ritual), id: \.self) { warning in
                RowWarning(warning)
            }
        }
        .padding(.vertical, 4)
    }
}

/// A catalog ritual's target, resistance, sacrament, and what casting it costs this character.
struct RitualDetailView: View {
    let entry: RitualEntry
    let character: Character

    private var discipline: DisciplineEntry? {
        Catalog.bundled.disciplines.entry(entry.discipline)
    }

    var body: some View {
        CatalogDetailView(
            title: entry.name,
            summary: entry.summary,
            citation: entry.source.citation(),
            facts: facts,
            warnings: character.warnings(for: Ritual(source: .catalog(entry.id)))
        )
    }

    private var facts: [DetailFact] {
        let disciplineName = discipline?.name ?? entry.discipline
        var facts = [
            DetailFact(label: "Rating", value: "\(disciplineName) \(String(repeating: "•", count: entry.dots))"),
            DetailFact(label: "Target successes", value: "\(entry.targetSuccesses)"),
        ]
        if let contestedBy = entry.contestedBy {
            facts.append(DetailFact(label: "Contested by", value: contestedBy))
        }
        if let resistedBy = entry.resistedBy {
            facts.append(DetailFact(label: "Resisted by", value: resistedBy))
        }
        if let sacrament = entry.sacrament {
            facts.append(DetailFact(label: "Sacrament", value: sacrament))
        }
        if let rules = discipline?.ritualRules {
            facts.append(DetailFact(label: "Casting cost", value: castingCost(rules)))
            if let formula = rules.castingPool.formula(disciplineName: disciplineName) {
                facts.append(DetailFact(label: "Dice pool", value: formula))
            }
            let rating = character.disciplineRating(entry.discipline)
            if rating >= entry.dots, let dice = character.dice(for: rules.castingPool, disciplineRating: rating) {
                facts.append(DetailFact(label: "Your dice", value: "\(dice)"))
            }
        }
        return facts
    }

    /// Crúac costs a Vitae per dot of the rite; Theban costs a Willpower and the sacrament.
    private func castingCost(_ rules: RitualRules) -> String {
        if rules.castingCost.vitae == .varies {
            return "\(entry.dots) Vitae"
        }
        return rules.castingCost.displayText + (rules.castingCost.note.map { " (\($0))" } ?? "")
    }
}
