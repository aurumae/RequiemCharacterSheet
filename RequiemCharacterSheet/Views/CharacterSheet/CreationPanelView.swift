//
//  CreationPanelView.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// The guided creation checklist at the top of the sheet: the book's seven steps with their budgets,
/// anything that breaks the rules, and the buttons to finish or leave.
struct CreationPanelView: View {
    @Environment(\.theme) private var theme
    let character: Character
    /// Asks which favoured Attribute takes the clan's dot.
    let chooseFavoredAttribute: () -> Void
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

            if let clan = character.clanEntry {
                // The clan's free dot, chosen by the player and changeable
                Button(action: chooseFavoredAttribute) {
                    HStack {
                        Text("\(clan.name) dot")
                            .themedText(.traitName)
                        Spacer()
                        Text(character.creation?.favoredAttribute?.name ?? "Choose")
                            .themedText(.detail)
                            .foregroundStyle(character.needsFavoredAttribute ? theme.caution : theme.muted)
                        Image(systemName: "chevron.right")
                            .accessibilityHidden(true)
                            .font(.caption)
                            .foregroundStyle(theme.muted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Chooses which favoured Attribute takes the clan's free dot")
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

/// Finishing creation: an experienced vampire may start with bonus Experiences to spend.
private struct FinishCreationView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let character: Character
    @State private var bonusExperiences = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("If your Storyteller allows a more experienced vampire, choose how experienced. The bonus Experiences are added to spend in XP Mode, which turns on now.")
                        .themedText(.body)
                }
                Section(header: Text("Experienced Kindred").themedText(.subsectionHeader)) {
                    ForEach(CreationRules.experiencedRanks, id: \.name) { rank in
                        Button {
                            bonusExperiences = rank.experiences
                        } label: {
                            HStack {
                                Text(rank.name)
                                    .themedText(.traitName)
                                Spacer()
                                if rank.experiences > 0 {
                                    Text("+\(rank.experiences)")
                                        .themedText(.detail)
                                        .foregroundStyle(theme.muted)
                                }
                                // The row says "selected" itself
                                Image(systemName: bonusExperiences == rank.experiences ? "checkmark.circle.fill" : "circle")
                                    .accessibilityHidden(true)
                                    .foregroundStyle(theme.accent)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(bonusExperiences == rank.experiences ? .isSelected : [])
                    }
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
