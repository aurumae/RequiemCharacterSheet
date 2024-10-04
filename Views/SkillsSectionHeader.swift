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
                .font(.custom("CaslonAntique", size: 20))
            Text(subtitle)
                .font(.custom("CaslonAntique", size: 16))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}
