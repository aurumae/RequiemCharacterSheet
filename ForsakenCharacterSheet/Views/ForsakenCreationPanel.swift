//
//  ForsakenCreationPanel.swift
//  ForsakenCharacterSheet
//

import SwiftUI

/// The guided creation checklist at the top of the sheet: the seven steps with their budgets, anything that breaks
/// the rules, and the buttons to finish or leave. It follows Requiem's.
struct CreationPanelView: View {
    @Environment(\.theme) private var theme
    let character: ForsakenCharacter
    @State private var showingUnfinishedReminder = false
    @State private var showingFinish = false
    @State private var showingLeaveConfirmation = false

    var body: some View {
        let steps = character.creationSteps
        let doneCount = steps.filter { $0.status == .done }.count

        SheetSectionBlock(.creation) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(doneCount) of \(steps.count) steps done")
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
                ProgressView(value: Double(doneCount), total: Double(steps.count))
                    .tint(theme.accent)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 4)

            ForEach(steps) { step in
                CreationStepRow(step: step)
            }

            if let giver = character.freeSkillGiver, !character.freeSkillChoices.isEmpty {
                // The auspice's (or Pure tribe's) free Skill dot, chosen by the player and changeable
                HStack {
                    Text("\(giver) Skill dot")
                        .themedText(.traitName)
                    Spacer()
                    Menu {
                        ForEach(character.freeSkillChoices, id: \.self) { id in
                            Button(SkillDefinition.withID(id)?.name ?? id.rawValue) { character.chooseFreeSkill(id) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(character.needsFreeSkill ? "Choose" : (character.creation?.freeSkill.flatMap { SkillDefinition.withID($0)?.name } ?? "Choose"))
                                .themedText(.detail)
                                .foregroundStyle(character.needsFreeSkill ? theme.caution : theme.muted)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(theme.accent)
                        }
                    }
                    .accessibilityLabel("\(giver) Skill dot")
                    .accessibilityHint("Chooses which Skill takes the free dot")
                }
            }

            ForEach(character.creationReport.problems.map(\.description).sorted(), id: \.self) { problem in
                RowWarning(problem)
            }

            Button {
                if character.unfinishedCreationSteps.isEmpty {
                    showingFinish = true
                } else {
                    showingUnfinishedReminder = true
                }
            } label: {
                // White goes inside the theme style, whose own colour would otherwise win
                Text("Finish Creation")
                    .foregroundStyle(.white)
                    .themedText(.traitName)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(theme.accent))
            }
            .buttonStyle(.plain)
            .listRowSeparator(.hidden)
            // Breaking a rule (e.g. after changing clan) has to be fixed first
            .disabled(!character.creationReport.isWithinLimits)
            .opacity(character.creationReport.isWithinLimits ? 1 : 0.4)
            .alert("Some steps aren't done", isPresented: $showingUnfinishedReminder) {
                Button("Keep Going", role: .cancel) {}
                Button("Finish Anyway") { showingFinish = true }
            } message: {
                Text(character.unfinishedCreationSteps.map { "\($0.title): \($0.detail)" }.joined(separator: "\n"))
            }
            .hostedSheet(isPresented: $showingFinish) {
                FinishCreationView(character: character)
            }

            Button("Leave Guided Creation") {
                showingLeaveConfirmation = true
            }
            .themedText(.detail)
            .foregroundStyle(theme.muted)
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)
            .listRowSeparator(.hidden)
            .confirmationDialog("Leave guided creation?", isPresented: $showingLeaveConfirmation, titleVisibility: .visible) {
                Button("Leave Guided Creation", role: .destructive) {
                    character.leaveCreation()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The character keeps everything so far, without the starting-dot limits, as if made with a blank sheet.")
            }
        }
    }
}

private struct CreationStepRow: View {
    @Environment(\.theme) private var theme
    let step: CreationStep

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            icon
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(step.number). \(step.title)")
                    .themedText(.traitName)
                Text(step.detail)
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityValue(statusText)
    }

    @ViewBuilder
    private var icon: some View {
        switch step.status {
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.accent)
        case .inProgress:
            Image(systemName: "circle")
                .foregroundStyle(theme.muted)
        case .problem:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.caution)
        }
    }

    private var statusText: String {
        switch step.status {
        case .done: return "Done"
        case .inProgress: return "Not done"
        case .problem: return "Breaks a rule"
        }
    }
}

/// Finishing creation: the Storyteller may allow bonus Experiences to spend.
private struct FinishCreationView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let character: ForsakenCharacter
    @State private var bonusExperiences = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("If your Storyteller allows a more experienced werewolf, add the bonus Experiences here. They're spent in XP Mode, which turns on now.")
                        .themedText(.body)
                }
                Section {
                    CounterRow("Bonus Experiences:", value: $bonusExperiences, in: 0...200)
                }
            }
            .navigationTitle("Finish Creation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        character.finishCreation(bonusExperiences: bonusExperiences)
                        dismiss()
                    }
                }
            }
        }
        .tint(theme.accent)
    }
}

/// Chooses a category's priority, showing the dots left to spend in it.
struct CreationPriorityMenu: View {
    @Environment(\.theme) private var theme
    let character: ForsakenCharacter
    let category: TraitCategory
    let skills: Bool

    private var allotments: [Int] {
        skills ? CreationRules.skillDots : CreationRules.attributeDots
    }

    var body: some View {
        let report = character.creationReport
        let budget = (skills ? report.skills : report.attributes)[category]
        let kind = skills ? "Skill" : "Attribute"
        Menu {
            ForEach(CreationPriority.allCases, id: \.self) { priority in
                Button {
                    character.setPriority(priority, for: category, skills: skills)
                } label: {
                    if budget?.priority == priority {
                        Label("\(priority.name): \(allotments[priority.rawValue]) dots", systemImage: "checkmark")
                    } else {
                        Text("\(priority.name): \(allotments[priority.rawValue]) dots")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                if let budget, let priority = budget.priority {
                    Text(budget.remaining < 0 ? "\(priority.name) · \(-budget.remaining) over" : "\(priority.name) · \(budget.remaining) left")
                        .foregroundStyle(budget.remaining < 0 ? theme.caution : theme.accent)
                } else {
                    Text("Choose priority")
                        .foregroundStyle(theme.accent)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(theme.accent)
            }
            .font(.subheadline)
            .textCase(nil)
        }
        .accessibilityLabel("\(category.name) \(kind) priority")
        .accessibilityValue(budget?.priority.map { "\($0.name), \(budget?.remaining ?? 0) dots left" } ?? "Not chosen")
    }
}

