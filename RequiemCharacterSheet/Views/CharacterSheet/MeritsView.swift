//
//  MeritsView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct MeritsView: View {
    let character: Character

    var body: some View {
        Section(header: Text("MERITS").themedText(.sectionHeader)) {
            ForEach(character.merits) { merit in
                MeritRowView(merit: merit)
            }
            .onDelete(perform: deleteMerit)

            AddRowButton("Add Merit") {
                character.merits.append(Merit())
            }
        }
    }

    func deleteMerit(at offsets: IndexSet) {
        character.merits.remove(atOffsets: offsets)
    }
}