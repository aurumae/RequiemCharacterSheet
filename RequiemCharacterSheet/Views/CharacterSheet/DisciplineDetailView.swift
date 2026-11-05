//
//  DisciplineDetailView.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// A catalog Discipline's powers, with what each costs and how many dice this character rolls.
struct DisciplineDetailView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let entry: DisciplineEntry
    let rating: Int
    let character: Character

    private var knownPowers: [DisciplinePower] {
        entry.powers.filter { $0.dots.lowerBound <= rating }
    }

    private var higherPowers: [DisciplinePower] {
        entry.powers.filter { $0.dots.lowerBound > rating }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.summary)
                            .themedText(.body)
                        Text(entry.source.citation())
                            .themedText(.detail)
                            .foregroundStyle(theme.muted)
                        if character.inClanDisciplines.contains(entry.id) {
                            Text("In-clan for the \(character.inClanGroupName)")
                                .themedText(.detail)
                                .foregroundStyle(theme.accent)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }

                if let rules = entry.ritualRules {
                    ritualSection(rules)
                }

                if !knownPowers.isEmpty {
                    Section(header: Text(rating == 1 ? "Your power" : "Your powers").themedText(.subsectionHeader)) {
                        ForEach(knownPowers) { power in
                            PowerRow(power: power, discipline: entry, rating: rating, character: character)
                        }
                    }
                }

                if !higherPowers.isEmpty {
                    Section(header: Text("Higher dots").themedText(.subsectionHeader)) {
                        ForEach(higherPowers) { power in
                            PowerRow(power: power, discipline: entry, rating: rating, character: character)
                                // Dimmed but still readable
                                .opacity(0.7)
                        }
                    }
                }
            }
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(theme.accent)
    }
}

extension DisciplineDetailView {
    /// How a Ritual Discipline is learned and cast, and the rituals the character knows.
    @ViewBuilder
    private func ritualSection(_ rules: RitualRules) -> some View {
        let covenant = Catalog.bundled.covenants.entry(rules.covenant)?.name ?? rules.covenant
        let known = character.rituals(of: .catalog(entry.id))
        Section(header: Text("Rituals").themedText(.subsectionHeader)) {
            VStack(alignment: .leading, spacing: 4) {
                fact("Learned with", "\(covenant) Status \(rules.covenantStatusMinimum)")
                fact("Casting cost", rules.castingCost.displayText == "Varies"
                     ? (rules.castingCost.note ?? "Varies")
                     : rules.castingCost.displayText + (rules.castingCost.note.map { " (\($0))" } ?? ""))
                if let formula = rules.castingPool.formula(disciplineName: entry.name) {
                    fact("Dice pool", formula)
                }
                fact("Humanity", rules.humanity.description)
                fact("Rituals", "Each dot comes with one ritual; others cost 2 Experiences each. A ritual can't be rated above your dots.")
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)

            ForEach(known) { ritual in
                HStack {
                    Text(ritual.name)
                        .themedText(.traitName)
                    Spacer()
                    DotsText(ritual.dots)
                }
                .opacity(ritual.dots <= rating ? 1 : 0.7)
            }
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        (Text("\(label): ").bold() + Text(value))
            .themedText(.detail)
            .accessibilityLabel("\(label): \(value.spokenForVoiceOver)")
    }
}

/// One power: its dots and name, then cost, action, requirement, dice pool and summary.
private struct PowerRow: View {
    @Environment(\.theme) private var theme
    let power: DisciplinePower
    let discipline: DisciplineEntry
    let rating: Int
    let character: Character

    private var isKnown: Bool {
        power.dots.lowerBound <= rating
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(power.name)
                    .themedText(.traitName)
                Spacer()
                Text(dotsText)
                    .font(.caption2)
                    .foregroundStyle(theme.accent)
                    .accessibilityLabel(dotsAccessibilityLabel)
            }

            Text(power.summary)
                .themedText(.body)

            detail("Cost", power.cost.displayText + (power.cost.note.map { " (\($0))" } ?? ""))
            if let action = power.actionText {
                detail("Action", action)
            }
            if let condition = power.targetCondition {
                detail("Target must be", condition)
            }
            if let pool = power.dicePool, let formula = pool.formula(disciplineName: discipline.name) {
                detail("Dice pool", formula)
                if let resistedBy = pool.resistedBy {
                    detail("Resisted by", resistedBy)
                }
                if let dice = yourDice(for: pool) {
                    detail("Your dice", dice)
                }
            }
            if let page = power.page {
                Text("p. \(page)")
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// "●", "●●●", or "●–●●●●●" for a scaling Discipline.
    private var dotsText: String {
        let lowest = String(repeating: "●", count: power.dots.lowerBound)
        guard power.dots.count > 1 else { return lowest }
        return "\(lowest)–\(String(repeating: "●", count: power.dots.upperBound))"
    }

    private var dotsAccessibilityLabel: String {
        power.dots.count > 1
            ? "\(power.dots.lowerBound) to \(power.dots.upperBound) dots"
            : "\(power.dots.lowerBound) \(power.dots.lowerBound == 1 ? "dot" : "dots")"
    }

    /// The character's dice for a power they have, e.g. "6", or "Chance die" if the pool is empty.
    private func yourDice(for pool: DicePool) -> String? {
        guard isKnown, let dice = character.dice(for: pool, disciplineRating: rating) else { return nil }
        return dice > 0 ? "\(dice)" : "Chance die"
    }

    private func detail(_ label: String, _ value: String) -> some View {
        (Text("\(label): ").bold() + Text(value))
            .themedText(.detail)
            .accessibilityLabel("\(label): \(value.spokenForVoiceOver)")
    }
}
