//
//  SkillsView.swift
//  Chronicles
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct SkillsView<C: SheetCharacter>: View {
    let character: C

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

/// The Attributes section: Mental, Physical and Social, each under its heading.
struct AttributesView<C: SheetCharacter>: View {
    let character: C

    var body: some View {
        SheetSectionBlock(.attributes) {
            ForEach(TraitCategory.allCases, id: \.self) { category in
                Section(header: CategoryHeader(title: category.name, character: character, category: category, skills: false)) {
                    ForEach(character.attributes.filter { $0.kind.category == category }) { attribute in
                        AttributeRowView(character: character, attribute: attribute)
                    }
                }
            }
        }
    }
}
