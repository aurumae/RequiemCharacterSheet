//
//  RequiemSheetCharacter.swift
//  RequiemCharacterSheet
//
//  Requiem's rules for the shared sheet sections: Blood Potency caps, guided creation and Conditions.
//

import SwiftUI

extension Character: SheetCharacter {
    func attributeNote(for kind: AttributeKind) -> String? {
        // The clan's free dot, outside the 5/4/3
        creation?.favoredAttribute == kind ? "Includes the \(clan) dot" : nil
    }

    func meritsDepending(onSpecialty specialty: String) -> [String] {
        merits.filter { $0.entry?.qualifier?.usesSpecialty == true && $0.qualifier == specialty }.map(\.name)
    }

    func creationAllowsMerit(_ entry: MeritEntry?, rating: Int) -> Bool {
        creationAllows(.merit(entry, rating: rating))
    }

    var meritCategoryOrder: [MeritEntry.Category] {
        [.vampire, .covenant, .mental, .physical, .social, .fighting, .other, .supernatural]
    }

    func meritCategoryTitle(_ category: MeritEntry.Category) -> String {
        switch category {
        case .mental: "Mental"
        case .physical: "Physical"
        case .social: "Social"
        case .fighting: "Fighting"
        case .vampire: "Vampire"
        case .covenant: "Covenant"
        case .supernatural: "Supernatural (not for Kindred)"
        case .other: "Other"
        default: category.rawValue.capitalized
        }
    }

    func meritUnavailableReason(_ entry: MeritEntry) -> String? {
        entry.unavailableToKindred ? PrerequisiteCheck.notForKindred : nil
    }

    func conditionMark(for target: ConditionTarget, traitName: String) -> AnyView? {
        AnyView(ConditionIndicator(character: self, target: target, traitName: traitName))
    }

    func categoryAccessory(for category: TraitCategory, skills: Bool) -> AnyView? {
        // During guided creation, the player chooses where the 5/4/3 or 11/7/4 dots go
        isInCreation ? AnyView(CreationPriorityMenu(character: self, category: category, skills: skills)) : nil
    }
}

/// Chooses a category's priority, showing the dots left to spend in it.
struct CreationPriorityMenu: View {
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
