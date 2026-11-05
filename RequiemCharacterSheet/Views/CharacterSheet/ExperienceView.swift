//
//  ExperienceView.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// XP Mode, Beats, and Experiences earned, spent and available, with the change log.
struct ExperienceView: View {
    @Environment(\.theme) private var theme
    @Bindable var character: Character
    @State private var showingLog = false

    var body: some View {
        Section(header: Text("EXPERIENCE").themedText(.sectionHeader)) {
            VStack(alignment: .leading, spacing: 2) {
                Toggle(isOn: $character.xpMode) {
                    Text("XP Mode")
                        .themedText(.label)
                }
                .tint(theme.accent)
                .disabled(character.isInCreation)
                Text(character.isInCreation
                     ? "Starting dots are free. XP Mode turns on when creation is finished."
                     : character.xpMode
                     ? "Raising a trait spends Experiences; lowering it refunds what it cost."
                     : "Changes are free, e.g. Storyteller awards or entering an existing character.")
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
            .padding(.vertical, 4)

            // Five Beats make an Experience
            CounterRow(
                "Beats:",
                value: character.beats,
                canDecrement: character.beats > 0,
                decrement: character.decrementBeats,
                increment: character.incrementBeats
            )

            CounterRow(
                "Earned:",
                value: character.experiences,
                canDecrement: character.experiences > 0,
                decrement: character.decrementExperiences,
                increment: character.incrementExperiences
            )

            LabeledValueRow("Spent:", value: character.experiencesSpent)

            HStack {
                Text("Available:")
                    .themedText(.label)
                Spacer()
                // Yellow while below zero, which some Storytellers allow
                // The colour goes inside the label style, whose own colour would otherwise win
                Text("\(character.experiencesAvailable)")
                    .foregroundStyle(character.experiencesAvailable < 0 ? theme.caution : theme.accent)
                    .themedText(.label)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityValue(character.experiencesAvailable < 0 ? "Below zero" : "")

            Button {
                showingLog = true
            } label: {
                HStack {
                    Text("Change Log")
                        .themedText(.traitName)
                    Spacer()
                    Text("\(character.changeLog.count)")
                        .themedText(.detail)
                        .foregroundStyle(theme.muted)
                    Image(systemName: "chevron.right")
                        .accessibilityHidden(true)
                        .font(.caption)
                        .foregroundStyle(theme.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows every change to the character's traits")
            .sheet(isPresented: $showingLog) {
                ChangeLogView(character: character)
            }
        }
    }
}

/// Every change to the character's traits, newest first, grouped by day.
struct ChangeLogView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let character: Character

    private var days: [(day: Date, changes: [TraitChange])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: character.changeLog) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { day in
            (day, grouped[day, default: []].sorted { $0.date > $1.date })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledValueRow("Spent in total:", value: character.experiencesSpent)
                    LabeledValueRow("Available:", value: character.experiencesAvailable)
                }

                if character.changeLog.isEmpty {
                    Text("Changes to Attributes, Skills, Disciplines, Merits and other traits appear here.")
                        .themedText(.detail)
                        .foregroundStyle(theme.muted)
                }

                ForEach(days, id: \.day) { day in
                    Section(header: Text(day.day.formatted(date: .complete, time: .omitted)).themedText(.subsectionHeader)) {
                        ForEach(day.changes) { change in
                            ChangeLogRow(change: change, name: character.displayName(for: change))
                        }
                    }
                }
            }
            .navigationTitle("Change Log")
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

private struct ChangeLogRow: View {
    @Environment(\.theme) private var theme
    let change: TraitChange
    let name: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .themedText(.traitName)
                HStack(spacing: 6) {
                    Text(change.changeText)
                        .accessibilityLabel(change.changeText.spokenForVoiceOver)
                    Text(change.date.formatted(date: .omitted, time: .shortened))
                        .foregroundStyle(theme.muted)
                }
                .themedText(.detail)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(change.costText)
                    .themedText(.detail)
                    .foregroundStyle(change.experiences == 0 ? theme.muted : theme.accent)
                if !change.xpMode, change.duringCreation != true {
                    Text("XP Mode off")
                        .themedText(.detail)
                        .foregroundStyle(theme.muted)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// The toolbar badge: "XP Off", or the Experiences available while XP Mode is on. Tapping it switches XP Mode.
struct XPModeBadge: View {
    @Environment(\.theme) private var theme
    @Bindable var character: Character

    var body: some View {
        let isNegative = character.experiencesAvailable < 0
        Button {
            character.xpMode.toggle()
        } label: {
            Text(character.xpMode ? "XP \(character.experiencesAvailable)" : "XP Off")
                .font(.caption.weight(.semibold).monospacedDigit())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .foregroundStyle(character.xpMode ? Color.white : theme.accent)
                .background {
                    Capsule()
                        .fill(character.xpMode ? (isNegative ? theme.caution : theme.accent) : Color.clear)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(isNegative ? theme.caution : theme.accent, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("XP Mode")
        .accessibilityValue(character.xpMode ? "On, \(character.experiencesAvailable) Experiences available" : "Off")
        .accessibilityHint("Double-tap to turn XP Mode \(character.xpMode ? "off" : "on")")
    }
}

/// A brief notice when Experiences first fall below zero. It goes away by itself.
struct NegativeExperienceNotice: View {
    @Environment(\.theme) private var theme
    let available: Int

    var body: some View {
        Label("Experiences are now below zero (\(available))", systemImage: "exclamationmark.circle")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(theme.caution))
            .shadow(radius: 4)
            // Tapping dismisses it early
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Double-tap to dismiss")
    }
}
