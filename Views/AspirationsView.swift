//
//  AspirationsView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct AspirationsView: View {
    let character: Character

    var body: some View {
        Section(header: Text("ASPIRATIONS").themedText(.sectionHeader)) {
            ForEach(character.aspirations) { aspiration in
                AspirationRowView(aspiration: aspiration)
            }
            .onDelete(perform: deleteAspiration)

            AddRowButton("Add Aspiration") {
                character.aspirations.append(Aspiration())
            }
        }
    }

    func deleteAspiration(at offsets: IndexSet) {
        character.aspirations.remove(atOffsets: offsets)
    }
}