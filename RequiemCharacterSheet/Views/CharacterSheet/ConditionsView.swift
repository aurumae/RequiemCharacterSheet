//
//  ConditionsView.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// The last section of the sheet: the character's Conditions as a carousel of cards, and Add Condition.
/// It's last so swiping sideways through the cards never gets in the way of scrolling the sheet.
struct ConditionsView: View {
    @Environment(\.theme) private var theme
    let character: Character

    @State private var showingPicker = false
    /// The card open full screen: tapped in the carousel, or just added.
    @State private var openCondition: CharacterCondition?
    @State private var showingCard = false
    /// Set by the picker; the new Condition's card opens once the picker has closed.
    @State private var addedCondition: CharacterCondition?
    /// The card in view, for "2 of 4".
    @State private var visibleCardID: UUID?

    var body: some View {
        SheetSectionBlock(.conditions) {
            if character.conditions.isEmpty {
                Text("No Conditions")
                    .themedText(.body)
                    .foregroundStyle(theme.muted)
            } else {
                carousel
                    .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 6, trailing: 0))
                Text(positionText)
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }

            AddRowButton("Add Condition") {
                showingPicker = true
            }
            .hostedSheet(isPresented: $showingPicker, onDismiss: openAddedCondition) {
                ConditionPickerView(character: character) { condition in
                    character.addCondition(condition)
                    addedCondition = condition
                }
            }
            .hostedSheet(isPresented: $showingCard) {
                if let openCondition {
                    ConditionCardSheet(condition: openCondition, character: character)
                }
            }
        }
    }

    private var carousel: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(character.conditions) { condition in
                    Button {
                        open(condition)
                    } label: {
                        ConditionCard(condition: condition, character: character, isCompact: true)
                            // All cards as tall as the tallest
                            .frame(maxHeight: .infinity, alignment: .top)
                    }
                    .buttonStyle(.plain)
                    // Most of the width, so the next card peeks in from the side
                    .containerRelativeFrame(.horizontal) { width, _ in width - 56 }
                    .id(condition.id)
                    .accessibilityHint("Opens the full card")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $visibleCardID)
        // When the card in view is removed (ended or resolved), the carousel settles on a neighbour without
        // reporting it, so point at the card now in its place
        .onChange(of: character.conditions.map(\.id)) { old, new in
            guard let visible = visibleCardID, !new.contains(visible) else { return }
            let index = old.firstIndex(of: visible) ?? 0
            visibleCardID = new.isEmpty ? nil : new[min(index, new.count - 1)]
        }
    }

    private var positionText: String {
        let count = character.conditions.count
        guard count > 1 else { return "Tap for the full card" }
        let index = character.conditions.firstIndex { $0.id == visibleCardID } ?? 0
        return index == count - 1 ? "\(count) of \(count)" : "\(index + 1) of \(count) · swipe for more"
    }

    private func open(_ condition: CharacterCondition) {
        openCondition = condition
        showingCard = true
    }

    private func openAddedCondition() {
        guard let addedCondition else { return }
        self.addedCondition = nil
        visibleCardID = addedCondition.id
        open(addedCondition)
    }
}

/// A Condition as a card: its name in a red band, the note, what it does, its resolution and Beat.
/// Compact in the carousel, with its text cut short; in full, with End, Resolve and Beat.
struct ConditionCard: View {
    @Environment(\.theme) private var theme
    @Bindable var condition: CharacterCondition
    let character: Character
    var isCompact = false
    var onEnd: (() -> Void)?
    var onResolve: (() -> Void)?
    var onBeat: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            band
            VStack(alignment: .leading, spacing: 10) {
                if isCompact {
                    if !condition.note.isEmpty {
                        Text(noteLine)
                            .themedText(.label)
                    }
                } else {
                    NoteField(condition: condition)
                    if condition.hasCounter {
                        ConditionCounterRow(condition: condition)
                    }
                }

                if condition.source.catalogID == nil && !isCompact {
                    CustomConditionFields(condition: condition)
                    if condition.beatText != nil {
                        beatRow
                    }
                } else {
                    Text(condition.effectText.isEmpty ? "No description" : condition.effectText)
                        .themedText(.body)
                        .lineLimit(isCompact ? 4 : nil)
                    labelled("Resolution", condition.resolutionText.isEmpty ? "—" : condition.resolutionText)
                        .lineLimit(isCompact ? 2 : nil)
                    beatRow
                }

                if !isCompact {
                    if let sources = condition.entry?.possibleSources {
                        Text("Possible sources: \(sources)")
                            .themedText(.detail)
                            .foregroundStyle(theme.muted)
                    }
                    if let entry = condition.entry {
                        Text(entry.source.citation())
                            .themedText(.detail)
                            .foregroundStyle(theme.muted)
                    }
                    Divider()
                    buttons
                } else {
                    Text("Tap for the full card")
                        .themedText(.detail)
                        .foregroundStyle(theme.muted)
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.accent.opacity(0.4)))
        .accessibilityElement(children: isCompact ? .combine : .contain)
    }

    private var noteLine: String {
        let prompt = condition.entry?.notePrompt ?? "Note"
        return "\(prompt): \(condition.note)"
    }

    private var band: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titleText.uppercased())
                .font(.custom(theme.subheadingFontName, size: 19, relativeTo: .headline))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if condition.isPersistent {
                Text("PERSISTENT")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(Capsule().stroke(.white.opacity(0.8)))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(theme.accent)
    }

    private var titleText: String {
        let name = condition.name.isEmpty ? "Custom Condition" : condition.name
        return condition.hasCounter && condition.counter > 0 ? "\(name) −\(condition.counter)" : name
    }

    private func labelled(_ label: String, _ text: String) -> some View {
        Text("\(Text("\(label): ").bold())\(text)")
            .themedText(.detail)
    }

    private var beatRow: some View {
        HStack(alignment: .firstTextBaseline) {
            labelled("Beat", condition.beatText ?? "n/a")
                .foregroundStyle(condition.beatText == nil ? theme.muted : Color.primary)
                .lineLimit(isCompact ? 2 : nil)
            Spacer(minLength: 8)
            if !isCompact, condition.beatText != nil, let onBeat {
                Button(action: onBeat) {
                    Label("Beat", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(theme.accent)
                .accessibilityLabel("Take a Beat")
                .accessibilityHint("The Condition stays")
            }
        }
    }

    private var buttons: some View {
        HStack {
            Button {
                onEnd?()
            } label: {
                Text("End").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Removes the Condition without a Beat")
            Button {
                onResolve?()
            } label: {
                Text(condition.givesBeatOnResolve ? "Resolve · +1 Beat" : "Resolve").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint(condition.givesBeatOnResolve ? "Removes the Condition and gives a Beat" : "Removes the Condition")
        }
        .tint(theme.accent)
    }
}

/// Who or what the Condition is about, e.g. "For: Marcus Vale".
private struct NoteField: View {
    @Bindable var condition: CharacterCondition

    var body: some View {
        let prompt = condition.entry?.notePrompt ?? "Note"
        HStack(alignment: .firstTextBaseline) {
            Text("\(prompt):")
                .themedText(.label)
            TextField(condition.entry?.notePrompt == nil ? "Optional" : "Who or what", text: $condition.note)
                .themedText(.body)
                .submitLabel(.done)
                .accessibilityLabel(prompt)
        }
    }
}

/// The growing penalty of Conditions like Tempted.
private struct ConditionCounterRow: View {
    @Bindable var condition: CharacterCondition

    var body: some View {
        Stepper(value: $condition.counter, in: 1...20) {
            Text("Penalty: −\(condition.counter)")
                .themedText(.label)
        }
        .accessibilityValue("Minus \(condition.counter)")
    }
}

/// The player's own name and text for a custom Condition.
private struct CustomConditionFields: View {
    @Environment(\.theme) private var theme
    @Bindable var condition: CharacterCondition

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            field("Name", text: Binding(get: { condition.name }, set: { condition.name = $0 }))
            field("What it does", text: $condition.customEffect, multiline: true)
            field("Resolution", text: $condition.customResolution, multiline: true)
            field("Beat (leave empty if none)", text: $condition.customBeat, multiline: true)
            Toggle("Persistent", isOn: $condition.customPersistent)
                .themedText(.label)
                .tint(theme.accent)
        }
    }

    private func field(_ title: String, text: Binding<String>, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .themedText(.detail)
                .foregroundStyle(theme.muted)
            TextField(title, text: text, axis: multiline ? .vertical : .horizontal)
                .themedText(.body)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(title)
        }
    }
}

/// A Condition's full card, with End, Resolve and Beat.
struct ConditionCardSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let condition: CharacterCondition
    let character: Character
    /// Shown briefly after taking a Beat, e.g. "Beat added · 3 of 5".
    @State private var beatMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ConditionCard(
                        condition: condition,
                        character: character,
                        onEnd: {
                            character.endCondition(condition)
                            dismiss()
                        },
                        onResolve: {
                            character.resolveCondition(condition)
                            dismiss()
                        },
                        onBeat: takeBeat
                    )
                    if let beatMessage {
                        Text(beatMessage)
                            .themedText(.detail)
                            .foregroundStyle(theme.accent)
                            .transition(.opacity)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Condition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sensoryFeedback(.success, trigger: beatMessage)
        }
        .tint(theme.accent)
    }

    private func takeBeat() {
        character.takeBeat(from: condition)
        let message = character.beats == 0 ? "Beat added · a new Experience" : "Beat added · \(character.beats) of 5"
        withAnimation { beatMessage = message }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation {
                if beatMessage == message { beatMessage = nil }
            }
        }
    }
}

/// Add Condition: recently used ones first, then each book's, Requiem's first, then a custom Condition.
struct ConditionPickerView: View {
    let character: Character
    /// Called with the new Condition; the caller adds it.
    let onAdd: (CharacterCondition) -> Void

    var body: some View {
        CatalogPickerView(
            title: "Add Condition",
            searchPrompt: "Search Conditions",
            sections: sections,
            customOptions: [CatalogPickerCustomOption(id: "condition", title: "Custom Condition")]
        ) { choice in
            switch choice {
            case .entry(let id):
                onAdd(CharacterCondition(source: .catalog(id)))
            case .custom:
                onAdd(CharacterCondition(source: .custom("")))
            }
        }
    }

    private var sections: [CatalogPickerSection] {
        let all = Catalog.bundled.conditions.all
        let recent = character.recentConditionIDs().compactMap { Catalog.bundled.conditions.entry($0) }
        var result: [CatalogPickerSection] = []
        if !recent.isEmpty {
            result.append(CatalogPickerSection(title: "Recently Used", items: recent.map(item)))
        }
        // Books in catalog order, which puts the Requiem core book first
        return result + CatalogPickerSection.byBook([CatalogPickerGroup("", all.sorted { $0.name < $1.name })], item: item)
    }

    private func item(_ entry: ConditionEntry) -> CatalogPickerItem {
        var details: [String] = []
        if entry.persistent { details.append("Persistent") }
        if let beat = entry.beat { details.append("Beat: \(beat)") }
        return CatalogPickerItem(
            id: entry.id,
            name: entry.name,
            summary: Self.firstSentence(of: entry.summary),
            details: details,
            citation: entry.source.citation(),
            isOwned: !character.canAdd(entry)
        )
    }

    /// The opening sentence, so the list stays readable; the card has the rest.
    static func firstSentence(of text: String) -> String {
        guard let end = text.range(of: ". ") else { return text }
        return String(text[..<end.lowerBound]) + "."
    }
}
