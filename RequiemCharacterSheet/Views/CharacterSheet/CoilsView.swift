//
//  CoilsView.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// The Ordo Dracul Mystery the character follows, their Coils, and their Scales.
struct CoilsView: View {
    @Environment(\.theme) private var theme
    let character: Character
    /// "Custom Mystery" was chosen and its name hasn't been typed yet.
    @State private var editsCustomMystery = false
    @State private var newCustomCoilID: UUID?
    @State private var showingScalePicker = false
    @State private var newCustomScaleID: UUID?
    @State private var addsCustomScaleOnDismiss = false

    var body: some View {
        Section(header: Text("COILS OF THE DRAGON").themedText(.sectionHeader)) {
            mysteryRow

            ForEach(character.coils) { coil in
                CoilRowView(coil: coil, character: character, beginsEditing: coil.id == newCustomCoilID)
                    .editingRow(coil.id)
            }
            .onDelete { character.coils.remove(atOffsets: $0) }

            addCoilMenu

            Section(header: Text("Scales").themedText(.subsectionHeader)) {
                ForEach(character.scales) { scale in
                    ScaleRowView(scale: scale, character: character, beginsEditing: scale.id == newCustomScaleID)
                        .editingRow(scale.id)
                }
                .onDelete { character.scales.remove(atOffsets: $0) }

                if !character.canLearnDevotionsAndScales {
                    CreationNote("Scales are learned with Experiences after creation.")
                }

                AddRowButton("Add Scale") {
                    showingScalePicker = true
                }
                .disabled(!character.canLearnDevotionsAndScales)
                .sheet(isPresented: $showingScalePicker, onDismiss: addCustomScaleIfChosen) {
                    CatalogPickerView(
                        title: "Add Scale",
                        searchPrompt: "Search Scales",
                        sections: scalePickerSections,
                        customOptions: [CatalogPickerCustomOption(id: "scale", title: "Custom Scale")]
                    ) { choice in
                        switch choice {
                        case .entry(let id):
                            character.scales.append(Scale(source: .catalog(id)))
                        case .custom:
                            addsCustomScaleOnDismiss = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Mystery

    private var isCustomMystery: Bool {
        editsCustomMystery || (character.mysterySource.catalogID == nil && character.mysterySource != .custom(""))
    }

    private var mysteryRow: some View {
        HStack {
            Text("Mystery")
                .themedText(.label)
            Spacer()
            if isCustomMystery {
                TapToEditText(
                    placeholder: "Mystery Name",
                    accessibilityName: "Mystery",
                    text: Binding(get: { character.mystery }, set: { name in
                        character.renameMystery(to: name)
                        editsCustomMystery = false
                    }),
                    beginsEditing: editsCustomMystery
                ) { name in
                    Text(name)
                        .themedText(.traitName)
                }
            }
            Menu {
                ForEach(Catalog.bundled.mysteries.all) { entry in
                    Button(entry.name) {
                        editsCustomMystery = false
                        character.chooseMystery(.catalog(entry.id))
                    }
                }
                Button("Custom Mystery") {
                    character.chooseMystery(.custom(""))
                    editsCustomMystery = true
                }
                Button("None") {
                    editsCustomMystery = false
                    character.chooseMystery(.custom(""))
                }
            } label: {
                if isCustomMystery {
                    Image(systemName: "chevron.up.chevron.down")
                        .accessibilityLabel("Change Mystery")
                } else {
                    HStack(spacing: 4) {
                        Text(character.mysteryEntry?.name ?? "Choose")
                            .themedText(.traitName)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Mystery")
                    .accessibilityValue(character.mysteryEntry?.name ?? "Not chosen")
                }
            }
            .foregroundStyle(theme.accent)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Coils

    private var addCoilMenu: some View {
        Menu {
            let present = Set(character.coils.map(\.mystery))
            // At creation, only the character's own Mystery's Coil, which choosing the Mystery adds
            ForEach(Catalog.bundled.mysteries.all.filter { !present.contains(.catalog($0.id)) }) { entry in
                Button(entry.coil.name) {
                    character.coils.append(Coil(mystery: .catalog(entry.id)))
                }
                .disabled(character.isInCreation)
            }
            Button("Custom Coil") {
                let coil = Coil(mystery: .custom(""))
                newCustomCoilID = coil.id
                character.coils.append(coil)
            }
            .disabled(character.isInCreation)
        } label: {
            Label("Add Coil", systemImage: "plus.circle")
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
    }

    // MARK: - Scales

    /// One section per Mystery, the character's own first.
    private var scalePickerSections: [CatalogPickerSection] {
        let owned = Set(character.scales.compactMap(\.source.catalogID))
        let all = Catalog.bundled.mysteries.all
        let isOwn = { (entry: MysteryEntry) in entry.id == character.mysterySource.catalogID }
        let mysteries = all.filter(isOwn) + all.filter { !isOwn($0) }
        return mysteries.map { mystery in
            let items = Catalog.bundled.scales.all.filter { $0.mystery == mystery.id }.map { entry in
                CatalogPickerItem(
                    id: entry.id,
                    name: entry.name,
                    summary: entry.summary,
                    details: [
                        "Prerequisite: \(entry.prerequisiteText)",
                        "Costs \(experiencesText(character.experienceCost(of: entry)))",
                    ],
                    citation: entry.source.citation(),
                    isOwned: owned.contains(entry.id)
                )
            }
            return CatalogPickerSection(title: mystery.name, items: items)
        }
    }

    private func addCustomScaleIfChosen() {
        guard addsCustomScaleOnDismiss else { return }
        addsCustomScaleOnDismiss = false
        let scale = Scale(source: .custom(""))
        newCustomScaleID = scale.id
        character.scales.append(scale)
    }
}

struct CoilRowView: View {
    @Environment(\.theme) private var theme
    @Bindable var coil: Coil
    let character: Character
    var beginsEditing = false
    @State private var showingDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    if let entry = coil.entry {
                        Button {
                            showingDetail = true
                        } label: {
                            Text(entry.coil.name)
                                .themedText(.traitName)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Shows its tiers")
                        .sheet(isPresented: $showingDetail) {
                            MysteryDetailView(entry: entry, rating: coil.rating, character: character)
                        }
                    } else if character.isMysteryCoil(coil) {
                        // Renamed with the Mystery above
                        Text(coil.name)
                            .themedText(.traitName)
                    } else {
                        TapToEditText(placeholder: "Coil Name", text: $coil.name, beginsEditing: beginsEditing) { name in
                            Text(name)
                                .themedText(.traitName)
                        }
                    }
                    if character.isMysteryCoil(coil) {
                        Text("Your Mystery")
                            .themedText(.detail)
                            .foregroundStyle(theme.muted)
                    }
                }

                Spacer()

                DotsRatingView(
                    coil.entry?.coil.name ?? (coil.name.isEmpty ? "Coil" : coil.name),
                    rating: $coil.rating,
                    maxRating: Coil.maxRating,
                    maxEditableRating: character.editableMaximum(for: TraitKey(.coil, coil.id.uuidString), upTo: Coil.maxRating),
                    allowsResetToZero: true
                )
            }

            if !coil.learnedTiers.isEmpty {
                Text(coil.learnedTiers.map(\.name).joined(separator: " · "))
                    .themedText(.detail)
            }
            if let warning = character.warning(for: coil) {
                RowWarning(warning)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ScaleRowView: View {
    @Environment(\.theme) private var theme
    @Bindable var scale: Scale
    let character: Character
    var beginsEditing = false
    @State private var showingDetail = false

    var body: some View {
        HStack {
            if let entry = scale.entry {
                Button {
                    showingDetail = true
                } label: {
                    Text(entry.name)
                        .themedText(.traitName)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows its details")
                .sheet(isPresented: $showingDetail) {
                    ScaleDetailView(entry: entry, character: character)
                }

                Spacer()

                Text(experiencesText(character.experienceCost(of: entry)))
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            } else {
                TapToEditText(placeholder: "Scale Name", text: $scale.name, beginsEditing: beginsEditing) { name in
                    Text(name)
                        .themedText(.traitName)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// A Mystery's Coil: the tiers the character has, then the ones above.
struct MysteryDetailView: View {
    @Environment(\.theme) private var theme
    let entry: MysteryEntry
    let rating: Int
    let character: Character

    var body: some View {
        CatalogDetailView(
            title: entry.coil.name,
            summary: entry.summary,
            citation: entry.source.citation(),
            facts: [
                DetailFact(label: "Mystery", value: entry.name),
                DetailFact(label: "Coil", value: entry.coil.summary),
            ]
        ) {
            Section(header: Text("Tiers").themedText(.subsectionHeader)) {
                ForEach(entry.tiers) { tier in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(tier.name)
                                .themedText(.traitName)
                            Spacer()
                            DotsText(tier.dots)
                        }
                        Text(tier.summary)
                            .themedText(.body)
                        if let page = tier.page {
                            Text("p. \(page)")
                                .themedText(.detail)
                                .foregroundStyle(theme.muted)
                        }
                    }
                    .padding(.vertical, 4)
                    .opacity(tier.dots <= rating ? 1 : 0.7)
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(tier.dots <= rating ? "Learned" : "Not learned")
                }
            }
        }
    }
}

/// A catalog Scale's prerequisite Coil, cost and pool.
struct ScaleDetailView: View {
    let entry: ScaleEntry
    let character: Character

    var body: some View {
        CatalogDetailView(title: entry.name, summary: entry.summary, citation: entry.source.citation(), facts: facts)
    }

    private var facts: [DetailFact] {
        var facts = [
            DetailFact(label: "Prerequisite Coil", value: entry.prerequisiteText),
            DetailFact(
                label: "Learning cost",
                value: experiencesText(character.experienceCost(of: entry))
                    + (character.meetsPrerequisite(of: entry) ? " (prerequisite met)" : " (2 without the prerequisite, 1 with it)")
            ),
            DetailFact(label: "Cost", value: entry.cost.displayText + (entry.cost.note.map { " (\($0))" } ?? "")),
        ]
        if let pool = entry.dicePool, let formula = pool.formula(disciplineName: "") {
            facts.append(DetailFact(label: "Dice pool", value: formula))
        }
        if let action = entry.action {
            facts.append(DetailFact(label: "Action", value: action.prefix(1).uppercased() + action.dropFirst()))
        }
        if let duration = entry.duration {
            facts.append(DetailFact(label: "Duration", value: duration))
        }
        return facts
    }
}
