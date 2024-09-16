//
//  MeritRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct MeritRowView: View {
    @ObservedObject var merit: Merit
    @State private var isEditingMerit = false
    @FocusState private var meritFieldIsFocused: Bool

    var body: some View {
        HStack {
            
            /*
            // Name TextField
            TextField("Merit Name", text: $merit.name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .submitLabel(.done)
                .frame(maxWidth: .infinity)
             */
            
            if isEditingMerit {
                TextField("Merit Name", text: $merit.name, onCommit: {
                    isEditingMerit = false
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .submitLabel(.done)
                .focused($meritFieldIsFocused)
                .frame(maxWidth: .infinity)
            } else {
                if merit.name.isEmpty {
                    Button(action: {
                        isEditingMerit = true
                        meritFieldIsFocused = true
                    }) {
                        Text("Merit Name")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Display discipline name, tap to edit
                    Button(action: {
                        isEditingMerit = true
                        meritFieldIsFocused = true
                    }) {
                        Text(merit.name)
                            .font(.custom("CaslonAntique", size: 20))
                            .foregroundColor(.vampireRed)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Spacer()

            // Dots Rating View
            EditableDotsRatingView(rating: $merit.rating, maxRating: 5)
                .frame(width: 100)
        }
        .padding(.vertical, 4)
    }
}
