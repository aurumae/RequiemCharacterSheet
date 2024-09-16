//
//  DisciplinesView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct DisciplinesView: View {
    @ObservedObject var character: Character

    var body: some View {
        Section(header: Text("DISCIPLINES").font(.custom("CaslonAntique", size: 24))) {
            ForEach(character.disciplines) { discipline in
                DisciplineRowView(discipline: discipline)
            }
            .onDelete(perform: deleteDiscipline)

            // Add New Discipline Button
            Button(action: {
                character.disciplines.append(Discipline())
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Discipline")
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    func deleteDiscipline(at offsets: IndexSet) {
        character.disciplines.remove(atOffsets: offsets)
    }
}
