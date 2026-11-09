//
//  AspirationsView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct AspirationsView: View {
    let character: Character
    /// An Aspiration that was just added, which opens for typing.
    @State private var newAspirationID: UUID?

    var body: some View {
        SheetSectionBlock(.aspirations) {
            ForEach(character.aspirations) { aspiration in
                AspirationRowView(aspiration: aspiration, beginsEditing: aspiration.id == newAspirationID)
                    .editingRow(aspiration.id)
            }
            .onDelete(perform: deleteAspiration)

            AddRowButton("Add Aspiration") {
                let aspiration = Aspiration()
                newAspirationID = aspiration.id
                character.aspirations.append(aspiration)
            }
        }
    }

    func deleteAspiration(at offsets: IndexSet) {
        character.aspirations.remove(atOffsets: offsets)
    }
}