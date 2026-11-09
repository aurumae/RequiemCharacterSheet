//
//  DevotionsView.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// The character's Devotions, with a picker for the book's and custom ones.
struct DevotionsView: View {
    let character: Character
    @State private var showingPicker = false
    /// A custom Devotion that was just added, whose name opens for editing.
    @State private var newCustomDevotionID: UUID?
    /// The custom row is added once the picker has closed, so its name field can take keyboard focus.
    @State private var addsCustomDevotionOnDismiss = false

    var body: some View {
        SheetSectionBlock(.devotions) {
            ForEach(character.devotions) { devotion in
                DevotionRowView(devotion: devotion, character: character, beginsEditing: devotion.id == newCustomDevotionID)
                    .editingRow(devotion.id)
            }
            .onDelete { character.devotions.remove(atOffsets: $0) }

            if !character.canLearnDevotionsAndScales {
                CreationNote("Devotions are learned with Experiences after creation.")
            }

            AddRowButton("Add Devotion") {
                showingPicker = true
            }
            .disabled(!character.canLearnDevotionsAndScales)
            .hostedSheet(isPresented: $showingPicker, onDismiss: addCustomDevotionIfChosen) {
                CatalogPickerView(
                    title: "Add Devotion",
                    searchPrompt: "Search Devotions",
                    sections: pickerSections,
                    customOptions: [CatalogPickerCustomOption(id: "devotion", title: "Custom Devotion")]
                ) { choice in
                    switch choice {
                    case .entry(let id):
                        character.devotions.append(Devotion(source: .catalog(id)))
                    case .custom:
                        addsCustomDevotionOnDismiss = true
                    }
                }
            }
        }
    }

    /// Devotions the character has the Disciplines for come first.
    private var pickerSections: [CatalogPickerSection] {
        let owned = Set(character.devotions.compactMap(\.source.catalogID))
        let items = Catalog.bundled.devotions.all.sorted { $0.name < $1.name }.map { entry in
            let unmet = character.unmetPrerequisites(for: entry)
            let requires = character.prerequisiteChecks(for: entry).map(\.description).joined(separator: ", ")
            return CatalogPickerItem(
                id: entry.id,
                name: entry.name,
                summary: entry.summary,
                details: ["\(requires) · \(experiencesText(entry.experienceCost))"],
                warning: unmet.isEmpty ? nil : "Missing \(unmet.map(\.description).joined(separator: "; "))",
                citation: entry.source.citation(),
                isOwned: owned.contains(entry.id)
            )
        }
        let available = items.filter { $0.warning == nil }
        let others = items.filter { $0.warning != nil }
        return [
            CatalogPickerSection(title: "You have the Disciplines", items: available),
            CatalogPickerSection(title: available.isEmpty ? "Devotions" : "Other Devotions", items: others),
        ]
    }

    private func addCustomDevotionIfChosen() {
        guard addsCustomDevotionOnDismiss else { return }
        addsCustomDevotionOnDismiss = false
        let devotion = Devotion(source: .custom(""))
        newCustomDevotionID = devotion.id
        character.devotions.append(devotion)
    }
}

/// "1 Experience" or "3 Experiences".
func experiencesText(_ count: Int) -> String {
    "\(count) \(count == 1 ? "Experience" : "Experiences")"
}

struct DevotionRowView: View {
    @Environment(\.theme) private var theme
    @Bindable var devotion: Devotion
    let character: Character
    var beginsEditing = false
    @State private var showingDetail = false

    var body: some View {
        if let entry = devotion.entry {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Button {
                        showingDetail = true
                    } label: {
                        Text(entry.name)
                            .themedText(.traitName)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows its details")
                    .hostedSheet(isPresented: $showingDetail) {
                        DevotionDetailView(entry: entry, character: character)
                    }

                    Spacer()

                    Text(experiencesText(entry.experienceCost))
                        .themedText(.detail)
                        .foregroundStyle(theme.muted)
                }

                let unmet = character.unmetPrerequisites(for: entry)
                if !unmet.isEmpty {
                    RowWarning("Requires \(unmet.map(\.description).joined(separator: "; "))")
                }
            }
            .padding(.vertical, 4)
        } else {
            HStack {
                TapToEditText(placeholder: "Devotion Name", text: $devotion.name, beginsEditing: beginsEditing) { name in
                    Text(name)
                        .themedText(.traitName)
                }

                Spacer()

                // What a homebrew Devotion cost, for working out spent Experiences
                Text(experiencesText(devotion.customExperienceCost))
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
                StepperButtons(
                    canDecrement: devotion.customExperienceCost > 1,
                    canIncrement: devotion.customExperienceCost < 20,
                    decrement: { devotion.customExperienceCost -= 1 },
                    increment: { devotion.customExperienceCost += 1 }
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Experience cost")
                .accessibilityValue("\(devotion.customExperienceCost)")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        devotion.customExperienceCost = min(devotion.customExperienceCost + 1, 20)
                    case .decrement:
                        devotion.customExperienceCost = max(devotion.customExperienceCost - 1, 1)
                    @unknown default:
                        break
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

/// A catalog Devotion's requirements, cost and dice pool.
struct DevotionDetailView: View {
    let entry: DevotionEntry
    let character: Character

    var body: some View {
        CatalogDetailView(
            title: entry.name,
            summary: entry.summary,
            citation: entry.source.citation(),
            facts: facts,
            warnings: character.unmetPrerequisites(for: entry).map { "Missing \($0.description)" }
        )
    }

    private var facts: [DetailFact] {
        var facts = [
            DetailFact(label: "Requires", value: character.prerequisiteChecks(for: entry).map(\.description).joined(separator: ", ")),
            DetailFact(label: "Learning cost", value: experiencesText(entry.experienceCost)),
            DetailFact(label: "Cost", value: entry.cost.displayText + (entry.cost.note.map { " (\($0))" } ?? "")),
        ]
        if let action = entry.action, action != "none" {
            facts.append(DetailFact(label: "Action", value: action.prefix(1).uppercased() + action.dropFirst()))
        }
        if let duration = entry.duration {
            facts.append(DetailFact(label: "Duration", value: duration))
        }
        if let requirement = entry.requirement {
            facts.append(DetailFact(label: "Requirement", value: requirement))
        }
        if let pool = entry.dicePool, let formula = pool.formula(disciplineName: "") {
            facts.append(DetailFact(label: "Dice pool", value: formula))
            if let resistedBy = pool.resistedBy {
                facts.append(DetailFact(label: "Resisted by", value: resistedBy))
            }
            if character.unmetPrerequisites(for: entry).isEmpty, let dice = character.dice(for: pool) {
                facts.append(DetailFact(label: "Your dice", value: dice > 0 ? "\(dice)" : "Chance die"))
            }
        }
        return facts
    }
}
