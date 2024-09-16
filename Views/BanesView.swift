//
//  BanesView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct BanesView: View {
    @ObservedObject var character: Character

    var body: some View {
        Section(header: Text("BANES").font(.custom("CaslonAntique", size: 24))) {
            ForEach(character.banes) { bane in
                BaneRowView(bane: bane)
            }
            .onDelete(perform: deleteBane)

            // Add New Bane Button
            Button(action: {
                character.banes.append(Bane())
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Bane")
                }
                .foregroundColor(.vampireRed)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    func deleteBane(at offsets: IndexSet) {
        character.banes.remove(atOffsets: offsets)
    }
}