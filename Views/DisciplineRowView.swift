//
//  DisciplineRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct DisciplineRowView: View {
    @ObservedObject var discipline: Discipline
    @State private var isEditingDiscipline = false
    @FocusState private var disciplineFieldIsFocused: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            
            // Name TextField
            if isEditingDiscipline {
                TextField("Discipline Name", text: $discipline.name, onCommit: {
                    isEditingDiscipline = false
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .submitLabel(.done)
                .focused($disciplineFieldIsFocused)
                .frame(maxWidth: .infinity)
            } else {
                if discipline.name.isEmpty {
                    Button(action: {
                        isEditingDiscipline = true
                        disciplineFieldIsFocused = true
                    }) {
                        Text("Discipline Name")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Display discipline name, tap to edit
                    Button(action: {
                        isEditingDiscipline = true
                        disciplineFieldIsFocused = true
                    }) {
                        Text(discipline.name)
                            .font(.custom("CaslonAntique", size: 20))
                            .foregroundColor(.vampireRed)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Spacer()
            
            // Dots Rating View
            EditableDotsRatingView(rating: $discipline.rating, maxRating: 5)
                .frame(width: 100)
        }
        .padding(.vertical, 4)
    }
}
