//
//  AspirationsView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct AspirationsView: View {
    @ObservedObject var character: Character

    var body: some View {
        Section(header: Text("ASPIRATIONS").font(.custom("CaslonAntique", size: 24))) {
            ForEach(character.aspirations) { aspiration in
                AspirationRowView(aspiration: aspiration)
            }
            .onDelete(perform: deleteAspiration)

            // Add New Aspiration Button
            Button(action: {
                character.aspirations.append(Aspiration())
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Aspiration")
                }
                .foregroundColor(.vampireRed)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    func deleteAspiration(at offsets: IndexSet) {
        character.aspirations.remove(atOffsets: offsets)
    }
}