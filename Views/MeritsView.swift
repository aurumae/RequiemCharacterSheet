//
//  MeritsView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct MeritsView: View {
    @ObservedObject var character: Character

    var body: some View {
        Section(header: Text("MERITS").font(.custom("CaslonAntique", size: 24))) {
            ForEach(character.merits) { merit in
                MeritRowView(merit: merit)
            }
            .onDelete(perform: deleteMerit)

            // Add New Merit Button
            Button(action: {
                character.merits.append(Merit())
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Merit")
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    func deleteMerit(at offsets: IndexSet) {
        character.merits.remove(atOffsets: offsets)
    }
}