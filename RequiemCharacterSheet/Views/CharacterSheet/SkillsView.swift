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
        SheetSectionBlock(.skills) {
            // MENTAL, PHYSICAL and SOCIAL SKILLS
            ForEach(TraitCategory.allCases, id: \.self) { category in
                Section(header: CategoryHeader(title: category.name, subtitle: "(\(category.unskilledPenalty) unskilled)",
                                               character: character, category: category, skills: true)) {
                    ForEach(character.skills(in: category)) { skill in
                        SkillRowView(character: character, skill: skill)
                    }
                }
            }
        }
    }
}
