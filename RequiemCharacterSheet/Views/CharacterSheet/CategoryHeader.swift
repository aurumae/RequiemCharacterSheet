//
//  CategoryHeader.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// The header of a Mental, Physical or Social group of Attributes or Skills. During guided creation it
/// also holds the category's priority, so the player chooses where the 5/4/3 or 11/7/4 dots go.
struct CategoryHeader: View {
    let title: String
    /// e.g. "(-3 unskilled)" for Skills.
    var subtitle: String?
    let character: Character
    let category: TraitCategory
    let skills: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading) {
                Text(title)
                    .themedText(.subsectionHeader)
                if let subtitle {
                    Text(subtitle)
                        .themedText(.note)
                }
            }
            Spacer()
            if character.isInCreation {
                CreationPriorityMenu(character: character, category: category, skills: skills)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Chooses a category's priority, showing the dots left to spend in it.
private struct CreationPriorityMenu: View {
    @Environment(\.theme) private var theme
    let character: Character
    let category: TraitCategory
    let skills: Bool

    private var allotments: [Int] {
        skills ? CreationRules.skillDots : CreationRules.attributeDots
    }

    var body: some View {
        let report = character.creationReport
        let budget = (skills ? report.skills : report.attributes)[category]
        let kind = skills ? "Skill" : "Attribute"
        Menu {
            ForEach(CreationPriority.allCases, id: \.self) { priority in
                Button {
                    character.setPriority(priority, for: category, skills: skills)
                } label: {
                    if budget?.priority == priority {
                        Label("\(priority.name): \(allotments[priority.rawValue]) dots", systemImage: "checkmark")
                    } else {
                        Text("\(priority.name): \(allotments[priority.rawValue]) dots")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                if let budget, let priority = budget.priority {
                    Text(budget.remaining < 0 ? "\(priority.name) · \(-budget.remaining) over" : "\(priority.name) · \(budget.remaining) left")
                        .foregroundStyle(budget.remaining < 0 ? theme.caution : theme.accent)
                } else {
                    Text("Choose priority")
                        .foregroundStyle(theme.accent)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(theme.accent)
            }
            .font(.subheadline)
            .textCase(nil)
        }
        .accessibilityLabel("\(category.name) \(kind) priority")
        .accessibilityValue(budget?.priority.map { "\($0.name), \(budget?.remaining ?? 0) dots left" } ?? "Not chosen")
    }
}
