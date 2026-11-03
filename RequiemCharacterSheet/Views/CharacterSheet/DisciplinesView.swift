//
//  DisciplinesView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct DisciplinesView: View {
    let character: Character

    var body: some View {
        Section(header: Text("DISCIPLINES").themedText(.sectionHeader)) {
            ForEach(character.disciplines) { discipline in
                DisciplineRowView(discipline: discipline)
            }
            .onDelete(perform: deleteDiscipline)

            AddRowButton("Add Discipline") {
                character.disciplines.append(Discipline())
            }
        }
    }

    func deleteDiscipline(at offsets: IndexSet) {
        character.disciplines.remove(atOffsets: offsets)
    }
}
