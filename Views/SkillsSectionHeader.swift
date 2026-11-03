//
//  SkillsSectionHeader.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct SkillsSectionHeader: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .themedText(.subsectionHeader)
            Text(subtitle)
                .themedText(.note)
        }
        .padding(.vertical, 4)
    }
}
