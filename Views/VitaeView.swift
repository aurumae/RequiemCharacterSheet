//
//  VitaeView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct VitaeView: View {
    @ObservedObject var character: Character

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Vitae Per Turn
            HStack {
                Text("Vitae Per Turn:")
                    .vampireFont()
                Spacer()
                Text("\(character.vitaePerTurn)")
                    .vampireFont()
            }
            .padding(.vertical, 4)
            
            // Max Vitae
            HStack {
                Text("Max Vitae:")
                    .vampireFont()
                Spacer()
                Text("\(character.maxVitae)")
                    .vampireFont()
            }
            .padding(.vertical, 4)
            
            // Current Vitae with plus and minus buttons
            HStack {
                Text("Current Vitae:")
                    .vampireFont()
                Spacer()
                HStack(spacing: 16) {
                    Button(action: {
                        if character.currentVitae > 0 {
                            character.currentVitae -= 1
                        }
                    }) {
                        Image(systemName: "minus.circle")
                            .font(.title2)
                            .foregroundColor(.vampireRed)
                    }
                    .buttonStyle(BorderlessButtonStyle())

                    Text("\(character.currentVitae)")
                        .vampireFont()
                        .frame(minWidth: 30)

                    Button(action: {
                        if character.currentVitae < character.maxVitae {
                            character.currentVitae += 1
                        }
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundColor(.vampireRed)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding(.vertical, 4)
        }
        .padding(.vertical, 4)
    }
}
