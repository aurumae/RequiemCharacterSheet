//
//  SkillRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//

import SwiftUI

struct SkillRowView: View {
    @ObservedObject var skill: Skill
    @State private var showingPicker = false
    @State private var isEditingSpecialty = false
    @FocusState private var specialtyFieldIsFocused: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                // Skill Name
                Button(action: {
                    showingPicker = true
                }) {
                    Text(skill.name)
                        .vampireFont()
                }
                .buttonStyle(PlainButtonStyle())
                .actionSheet(isPresented: $showingPicker) {
                    ActionSheet(title: Text("Set \(skill.name)"), message: nil, buttons: actionSheetButtons())
                }
                
                // Specialty Field or Prompt
                if isEditingSpecialty {
                    TextField("Specialty", text: $skill.specialty, onCommit: {
                        isEditingSpecialty = false
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .submitLabel(.done)
                    .focused($specialtyFieldIsFocused)
                } else {
                    if skill.specialty.isEmpty {
                        Button(action: {
                            isEditingSpecialty = true
                            specialtyFieldIsFocused = true
                        }) {
                            Text("Add Specialty")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        // Display specialty text, tap to edit
                        Button(action: {
                            isEditingSpecialty = true
                            specialtyFieldIsFocused = true
                        }) {
                            Text(skill.specialty)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            Spacer()
            
            
            DotsRatingView(rating: $skill.rating, maxRating: skill.rating > 5 ? skill.rating : 5)
                .frame(width: 100)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if specialtyFieldIsFocused {
                specialtyFieldIsFocused = false
                isEditingSpecialty = false
            }
        }
    }
    
    func actionSheetButtons() -> [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        for value in 0...10 {
            buttons.append(.default(Text("\(value)")) {
                skill.rating = value
            })
        }
        buttons.append(.cancel())
        return buttons
    }
}
