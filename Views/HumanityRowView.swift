//
//  HumanityRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct HumanityRowView: View {
    @ObservedObject var touchstone: Touchstone
    @Binding var humanity: Int
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            // Level Number
            Text("\(touchstone.level)")
                .vampireFont()

            // Touchstone Text
            if isEditing {
                TextField("Add Touchstone", text: $touchstone.text, onCommit: {
                    isEditing = false
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .submitLabel(.done)
                .focused($isFocused)
                .onAppear {
                    self.isFocused = true
                }
            } else {
                if touchstone.text.isEmpty {
                    Button(action: {
                        isEditing = true
                        isFocused = true
                    }) {
                        Text("Add Touchstone")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Button(action: {
                        isEditing = true
                        isFocused = true
                    }) {
                        Text(touchstone.text)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                            .strikethrough(touchstone.level > humanity, color: .vampireRed)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            Spacer()

            // Dot
            Circle()
                .fill(touchstone.level <= humanity ? Color.vampireRed : Color.clear)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle().stroke(Color.black, lineWidth: 1)
                )
                .onTapGesture {
                    humanity = touchstone.level
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
