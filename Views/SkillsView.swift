//
//  SkillsView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct SkillsView: View {
    let character: Character

    var body: some View {
        Section(header: Text("SKILLS").themedText(.sectionHeader)) {
            // MENTAL, PHYSICAL and SOCIAL SKILLS
            ForEach(TraitCategory.allCases, id: \.self) { category in
                Section(header: SkillsSectionHeader(title: category.title, subtitle: "(\(category.unskilledPenalty) unskilled)")) {
                    ForEach(character.skills(in: category)) { skill in
                        SkillRowView(character: character, skill: skill)
                    }
                }
            }
        }
    }
}
