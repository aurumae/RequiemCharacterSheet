//
//  SkillRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct SkillRowView: View {
    @Environment(\.theme) private var theme
    let character: Character
    @Bindable var skill: Skill
    @State private var showingPicker = false

    // Specialty being added or edited in the prompt
    @State private var isAddingSpecialty = false
    @State private var editingSpecialtyIndex: Int?
    @State private var specialtyDraft = ""

    /// The Blood Potency cap, and during guided creation, the starting dots left.
    private var maxEditableRating: Int {
        character.editableMaximum(for: TraitKey(.skill, skill.skillID.rawValue), upTo: character.baseRatingCap)
    }

    private var maximumVisibleRating: Int {
        character.baseRatingCap >= 6 || skill.rating >= 6 ? 10 : 5
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
                        specialtyDraft = specialty
                        editingSpecialtyIndex = index
                    } label: {
                        Text(specialty)
                            .themedText(.detail)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Specialty: \(specialty)")
                    .accessibilityHint("Double-tap to edit")
                }

                Button {
                    specialtyDraft = ""
                    isAddingSpecialty = true
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
        .alert("Add Specialty", isPresented: $isAddingSpecialty) {
            TextField("Specialty", text: $specialtyDraft)
            Button("Add") {
                addSpecialty()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(skill.name)
        }
        .alert(
            "Edit Specialty",
            isPresented: Binding(
                get: { editingSpecialtyIndex != nil },
                set: { if !$0 { editingSpecialtyIndex = nil } }
            )
        ) {
            TextField("Specialty", text: $specialtyDraft)
            Button("Save") {
                saveEditedSpecialty()
            }
            Button("Delete", role: .destructive) {
                deleteEditedSpecialty()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(skill.name)
        }
    }

    private var trimmedDraft: String {
        specialtyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addSpecialty() {
        guard !trimmedDraft.isEmpty else { return }
        skill.specialties.append(trimmedDraft)
    }

    private func saveEditedSpecialty() {
        guard let index = editingSpecialtyIndex, skill.specialties.indices.contains(index) else { return }
        // Saving an empty specialty removes it
        if trimmedDraft.isEmpty {
            skill.specialties.remove(at: index)
        } else {
            skill.specialties[index] = trimmedDraft
        }
    }

    private func deleteEditedSpecialty() {
        guard let index = editingSpecialtyIndex, skill.specialties.indices.contains(index) else { return }
        skill.specialties.remove(at: index)
    }
}
