//
//  FontTest.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//

import SwiftUI

struct FontListView: View {
    var body: some View {
        List {
            ForEach(UIFont.familyNames.sorted(), id: \.self) { family in
                Section(header: Text(family)) {
                    ForEach(UIFont.fontNames(forFamilyName: family), id: \.self) { name in
                        Text(name).font(.custom(name, size: 16))
                    }
                }
            }
        }
    }
}

#Preview {
    FontListView()
    // CaslonAntique
    // MrsEavesRoman
    // MrsEavesSmallCaps
}
