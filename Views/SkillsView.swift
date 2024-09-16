//
//  SkillsView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct SkillsView: View {
    @ObservedObject var character: Character

    var body: some View {
        Section(header: Text("SKILLS").font(.custom("CaslonAntique", size: 24))) {
            // MENTAL
            Section(header: SkillsSectionHeader(title: "MENTAL", subtitle: "(-3 unskilled)")) {
                ForEach(character.skills.filter { mentalSkills.contains($0.name) }) { skill in
                    SkillRowView(skill: skill)
                }
            }

            // PHYSICAL
            Section(header: SkillsSectionHeader(title: "PHYSICAL", subtitle: "(-1 unskilled)")) {
                ForEach(character.skills.filter { physicalSkills.contains($0.name) }) { skill in
                    SkillRowView(skill: skill)
                }
            }

            // SOCIAL
            Section(header: SkillsSectionHeader(title: "SOCIAL", subtitle: "(-1 unskilled)")) {
                ForEach(character.skills.filter { socialSkills.contains($0.name) }) { skill in
                    SkillRowView(skill: skill)
                }
            }
        }
    }

    // Skill names for filtering
    let mentalSkills = ["Academics", "Computer", "Crafts", "Investigation", "Medicine", "Occult", "Politics", "Science"]
    let physicalSkills = ["Athletics", "Brawl", "Drive", "Firearms", "Larceny", "Stealth", "Survival", "Weaponry"]
    let socialSkills = ["Animal Ken", "Empathy", "Expression", "Intimidation", "Persuasion", "Socialize", "Streetwise", "Subterfuge"]
}