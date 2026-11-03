//
//  CharacterInfoView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct CharacterInfoView: View {
    @Bindable var character: Character

    var body: some View {
        Section(header: Text("CHARACTER").themedText(.sectionHeader)) {
            CharacterInfoRowView(label: "Name:", text: $character.name)
            CharacterInfoRowView(label: "Player:", text: $character.player)
            CharacterInfoRowView(label: "Chronicle:", text: $character.chronicle)
            CharacterInfoRowView(label: "Mask:", text: $character.mask)
            CharacterInfoRowView(label: "Dirge:", text: $character.dirge)
            CharacterInfoRowView(label: "Concept:", text: $character.concept)
            CharacterInfoRowView(label: "Clan:", text: $character.clan)
            CharacterInfoRowView(label: "Bloodline:", text: $character.bloodline)
            CharacterInfoRowView(label: "Covenant:", text: $character.covenant)
        }
    }
}
