//
//  DisciplineRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct DisciplineRowView: View {
    @Bindable var discipline: Discipline
    let character: Character
    /// Opens the name for editing, for a custom Discipline that was just added.
    var beginsEditing = false
    @State private var showingDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            row
            // Crúac and Theban Sorcery are taught only within their covenants
            if let warning = discipline.entry.flatMap(character.ritualLearningWarning) {
                RowWarning(warning)
            }
        }
        .padding(.vertical, 4)
    }

    private var row: some View {
        HStack(alignment: .center, spacing: 8) {
            if let entry = discipline.entry {
                // Catalog Disciplines open their powers; to change one, delete it and add another
                Button {
                    showingDetail = true
                } label: {
                    Text(entry.name)
                        .themedText(.traitName)
                }
                .buttonStyle(.plain)
                .accessibilityHint(entry.kind == .ritual ? "Shows its rules and rituals" : "Shows its powers")
                .sheet(isPresented: $showingDetail) {
                    DisciplineDetailView(entry: entry, rating: discipline.rating, character: character)
                }
            } else {
                TapToEditText(placeholder: "Discipline Name", text: $discipline.name, beginsEditing: beginsEditing) { name in
                    Text(name)
                        .themedText(.traitName)
                }
            }

            Spacer()

            DotsRatingView(
                discipline.name.isEmpty ? "Discipline" : discipline.name,
                rating: $discipline.rating,
                maxRating: 5,
                allowsResetToZero: true
            )
        }
    }
}
