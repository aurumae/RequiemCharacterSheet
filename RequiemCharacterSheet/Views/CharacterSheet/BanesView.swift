//
//  BanesView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct BanesView: View {
    let character: Character

    var body: some View {
        Section(header: Text("BANES").themedText(.sectionHeader)) {
            ForEach(character.banes) { bane in
                BaneRowView(bane: bane)
            }
            .onDelete(perform: deleteBane)

            AddRowButton("Add Bane") {
                character.banes.append(Bane())
            }
        }
    }

    func deleteBane(at offsets: IndexSet) {
        character.banes.remove(atOffsets: offsets)
    }
}
