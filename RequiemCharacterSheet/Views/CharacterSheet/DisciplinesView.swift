//
//  DisciplinesView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct DisciplinesView: View {
    let character: Character
    @State private var showingPicker = false
    /// A custom Discipline that was just added, whose name opens for editing.
    @State private var newCustomDisciplineID: UUID?
    /// Set when "Custom Discipline" is chosen; the row is added once the picker has closed, so its name
    /// field can take keyboard focus from the picker's search field.
    @State private var addsCustomDisciplineOnDismiss = false

    var body: some View {
        Section(header: Text("DISCIPLINES").themedText(.sectionHeader)) {
            ForEach(character.disciplines) { discipline in
                DisciplineRowView(discipline: discipline, character: character, beginsEditing: discipline.id == newCustomDisciplineID)
            }
            .onDelete(perform: deleteDiscipline)

            AddRowButton("Add Discipline") {
                showingPicker = true
            }
            .sheet(isPresented: $showingPicker, onDismiss: addCustomDisciplineIfChosen) {
                DisciplinePickerView(character: character) { entry in
                    // A chosen Discipline starts at one dot; a custom one starts blank for its name
                    if let entry {
                        character.disciplines.append(Discipline(source: .catalog(entry.id), rating: 1))
                    } else {
                        addsCustomDisciplineOnDismiss = true
                    }
                }
            }
        }
    }

    private func addCustomDisciplineIfChosen() {
        guard addsCustomDisciplineOnDismiss else { return }
        addsCustomDisciplineOnDismiss = false
        let discipline = Discipline(source: .custom(""), rating: 1)
        newCustomDisciplineID = discipline.id
        character.disciplines.append(discipline)
    }

    func deleteDiscipline(at offsets: IndexSet) {
        character.disciplines.remove(atOffsets: offsets)
    }
}
