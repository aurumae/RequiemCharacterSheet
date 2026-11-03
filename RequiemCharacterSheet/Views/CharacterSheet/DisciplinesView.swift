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

    var body: some View {
        Section(header: Text("DISCIPLINES").themedText(.sectionHeader)) {
            ForEach(character.disciplines) { discipline in
                DisciplineRowView(discipline: discipline, character: character)
            }
            .onDelete(perform: deleteDiscipline)

            AddRowButton("Add Discipline") {
                showingPicker = true
            }
            .sheet(isPresented: $showingPicker) {
                DisciplinePickerView(character: character) { entry in
                    // A chosen Discipline starts at one dot; a custom one starts blank for its name
                    let source = entry.map { TraitSource.catalog($0.id) } ?? .custom("")
                    character.disciplines.append(Discipline(source: source, rating: 1))
                }
            }
        }
    }

    func deleteDiscipline(at offsets: IndexSet) {
        character.disciplines.remove(atOffsets: offsets)
    }
}
