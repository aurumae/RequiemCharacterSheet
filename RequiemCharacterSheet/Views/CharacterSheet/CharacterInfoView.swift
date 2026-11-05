//
//  CharacterInfoView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct CharacterInfoView: View {
    @Bindable var character: Character

    /// The book's sample Mask and Dirge archetypes; players can also type their own.
    private var archetypes: [String] {
        Catalog.bundled.archetypes.all.map(\.name)
    }

    var body: some View {
        Section(header: Text("CHARACTER").themedText(.sectionHeader)) {
            CharacterInfoRowView(label: "Name:", text: $character.name)
            CharacterInfoRowView(label: "Player:", text: $character.player)
            CharacterInfoRowView(label: "Chronicle:", text: $character.chronicle)
            CharacterInfoRowView(label: "Mask:", text: $character.mask, choices: archetypes)
            CharacterInfoRowView(label: "Dirge:", text: $character.dirge, choices: archetypes)
            CharacterInfoRowView(label: "Concept:", text: $character.concept)
            CatalogChoiceRow(
                label: "Clan:", value: character.clan, isCustom: character.clanSource.catalogID == nil,
                setCustomText: { character.clan = $0 },
                pickerTitle: "Choose Clan", searchPrompt: "Search clans",
                sections: character.clanPickerSections, customTitle: "Custom Clan"
            ) { id in
                character.clanSource = id.map { .catalog($0) } ?? .custom("")
            }
            CatalogChoiceRow(
                label: "Bloodline:", value: character.bloodline, isCustom: character.bloodlineSource.catalogID == nil,
                setCustomText: { character.bloodline = $0 },
                pickerTitle: "Choose Bloodline", searchPrompt: "Search bloodlines",
                sections: character.bloodlinePickerSections, customTitle: "Custom Bloodline", noneTitle: "No Bloodline"
            ) { id in
                character.bloodlineSource = id.map { .catalog($0) } ?? .custom("")
            }
            CatalogChoiceRow(
                label: "Covenant:", value: character.covenant, isCustom: character.covenantSource.catalogID == nil,
                setCustomText: { character.covenant = $0 },
                pickerTitle: "Choose Covenant", searchPrompt: "Search covenants",
                sections: character.covenantPickerSections, customTitle: "Custom Covenant", noneTitle: "Unaligned"
            ) { id in
                character.covenantSource = id.map { .catalog($0) } ?? .custom("")
            }
        }
    }
}
