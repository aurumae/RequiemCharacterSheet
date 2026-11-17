//
//  CategoryHeader.swift
//  Chronicles
//

import SwiftUI

/// The header of a Mental, Physical or Social group of Attributes or Skills, with any controls the game puts
/// beside it, e.g. Requiem's guided-creation priority.
struct CategoryHeader<C: SheetCharacter>: View {
    let title: String
    /// e.g. "(-3 unskilled)" for Skills.
    var subtitle: String?
    let character: C
    let category: TraitCategory
    let skills: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading) {
                Text(title)
                    .themedText(.subsectionHeader)
                    // A mark if a Condition affects the whole group, e.g. Broken's Social rolls. An overlay, just
                    // after the title, so the heading's spacing is the same with or without it.
                    .overlay(alignment: .trailing) {
                        if let mark = character.conditionMark(
                            for: skills ? .skillCategory(category) : .attributeCategory(category),
                            traitName: "\(category.name) \(skills ? "Skills" : "Attributes")"
                        ) {
                            mark
                                .alignmentGuide(.trailing) { $0[.leading] - 4 }
                        }
                    }
                if let subtitle {
                    Text(subtitle)
                        .themedText(.note)
                }
            }
            Spacer()
            if let accessory = character.categoryAccessory(for: category, skills: skills) {
                accessory
            }
        }
        .padding(.vertical, 4)
    }
}
