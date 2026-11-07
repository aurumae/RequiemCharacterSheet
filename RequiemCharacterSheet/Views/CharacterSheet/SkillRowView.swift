//
//  SkillRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

/// A Specialty being added (no index) or edited.
struct SpecialtyEdit {
    let skill: Skill
    let index: Int?

    /// The text the prompt starts with: the Specialty being edited, or nothing when adding.
    var initialText: String {
        index.flatMap { skill.specialties.indices.contains($0) ? skill.specialties[$0] : nil } ?? ""
    }
}

/// Opens the Specialty prompt, which the sheet shows. It isn't attached to the row: rows in a list can be
/// discarded while the keyboard appears, which would close the prompt before anything could be typed.
/// Always compares equal, as closures can't be compared; see `RevealEditingFieldAction`.
struct EditSpecialtyAction: Equatable {
    private let open: (SpecialtyEdit) -> Void

    init(_ open: @escaping (SpecialtyEdit) -> Void) {
        self.open = open
    }

    func callAsFunction(_ edit: SpecialtyEdit) {
        open(edit)
    }

    static func == (lhs: Self, rhs: Self) -> Bool { true }
}

extension EnvironmentValues {
    @Entry var editSpecialty = EditSpecialtyAction { _ in }
}

/// The prompt for adding, renaming or deleting a Specialty.
struct SpecialtyPrompt: ViewModifier {
    let character: Character
    @Binding var edit: SpecialtyEdit?
    /// Kept apart from `edit`, which is cleared as the prompt closes, so the buttons always see the text.
    @Binding var draft: String

    func body(content: Content) -> some View {
        content
            .alert(
                edit?.index == nil ? "Add Specialty" : "Edit Specialty",
                isPresented: Binding(get: { edit != nil }, set: { if !$0 { edit = nil } }),
                presenting: edit
            ) { edit in
                TextField("Specialty", text: $draft)
                if let index = edit.index {
                    Button("Save") { character.renameSpecialty(of: edit.skill, at: index, to: draft) }
                    Button("Delete", role: .destructive) { character.removeSpecialty(of: edit.skill, at: index) }
                } else {
                    Button("Add") { character.addSpecialty(draft, to: edit.skill) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { edit in
                Text(message(for: edit))
            }
    }

    private func message(for edit: SpecialtyEdit) -> String {
        guard let index = edit.index, edit.skill.specialties.indices.contains(index) else { return edit.skill.name }
        let specialty = edit.skill.specialties[index]
        let following = character.merits.filter { $0.entry?.qualifier?.usesSpecialty == true && $0.qualifier == specialty }
        guard !following.isEmpty else { return edit.skill.name }
        // Deleting it takes the Merit with it
        return "\(edit.skill.name). \(following.map(\.name).joined(separator: ", ")) depends on this Specialty."
    }
}

struct SkillRowView: View {
    @Environment(\.theme) private var theme
    let character: Character
    @Bindable var skill: Skill
    @Environment(\.editSpecialty) private var editSpecialty
    @State private var showingPicker = false

    /// The Blood Potency cap, and during guided creation, the starting dots left.
    private var maxEditableRating: Int {
        character.editableMaximum(for: TraitKey(.skill, skill.skillID.rawValue), upTo: character.baseRatingCap)
    }

    /// As many dots as Blood Potency allows, or the rating if that's more. Dots that can never be bought aren't drawn.
    private var maximumVisibleRating: Int {
        min(10, max(character.baseRatingCap, skill.rating))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                // Skill Name
                Button(action: {
                    showingPicker = true
                }) {
                    Text(skill.name)
                        .themedText(.label)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Double-tap to choose a rating")
                .confirmationDialog("Set \(skill.name)", isPresented: $showingPicker, titleVisibility: .visible) {
                    ForEach(Array(character.skillRatingRange.clamped(to: 0...maxEditableRating)), id: \.self) { value in
                        Button("\(value)") {
                            skill.rating = value
                        }
                    }
                }

                // Specialties, each tappable to edit
                ForEach(Array(skill.specialties.enumerated()), id: \.offset) { index, specialty in
                    Button {
                        editSpecialty(SpecialtyEdit(skill: skill, index: index))
                    } label: {
                        Text(specialty)
                            .themedText(.detail)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Specialty: \(specialty)")
                    .accessibilityHint("Double-tap to edit")
                }

                Button {
                    editSpecialty(SpecialtyEdit(skill: skill, index: nil))
                } label: {
                    Text("Add Specialty")
                        .themedText(.detail)
                        .foregroundStyle(theme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add \(skill.name) specialty")
                // During guided creation, three Specialties in all
                .disabled(!character.canAddSpecialty)
            }

            Spacer()

            DotsRatingView(
                skill.name,
                rating: $skill.rating,
                maxRating: maximumVisibleRating,
                maxEditableRating: maxEditableRating,
                showsOverflowTotal: true,
                allowsResetToZero: true,
                onOverflowTap: {
                    showingPicker = true
                }
            )
                .frame(width: 116)
        }
        .padding(.vertical, 4)
    }
}
