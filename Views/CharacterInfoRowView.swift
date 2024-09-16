//
//  CharacterInfoRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct CharacterInfoRowView: View {
    let label: String
    @Binding var text: String
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text(label)
                .vampireFont()
                .frame(minWidth: 100, alignment: .leading)

            Spacer()

            if isEditing {
                TextField("Tap to edit", text: $text, onCommit: {
                    isEditing = false
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .submitLabel(.done)
                .focused($isFocused)
                .onAppear {
                    self.isFocused = true
                }
            } else {
                if text.isEmpty {
                    Button(action: {
                        isEditing = true
                        isFocused = true
                    }) {
                        Text("Tap to edit")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Button(action: {
                        isEditing = true
                        isFocused = true
                    }) {
                        Text(text)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if isFocused {
                isFocused = false
                isEditing = false
            }
        }
    }
}
