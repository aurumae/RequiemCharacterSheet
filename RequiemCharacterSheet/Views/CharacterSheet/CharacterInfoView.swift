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
            archetypeRow(label: "Mask:", text: $character.mask)
            archetypeRow(label: "Dirge:", text: $character.dirge)
            CharacterInfoRowView(label: "Concept:", text: $character.concept)
            CatalogChoiceRow(
                label: "Clan:", value: character.clan, isCustom: character.clanSource.catalogID == nil,
                setCustomText: { character.clan = $0 },
                pickerTitle: "Choose Clan", searchPrompt: "Search clans",
                sections: character.clanPickerSections, customTitle: "Custom Clan",
                detail: { character.clanDetail }
            ) { id in
                character.clanSource = id.map { .catalog($0) } ?? .custom("")
            }
            CatalogChoiceRow(
                label: "Bloodline:", value: character.bloodline, isCustom: character.bloodlineSource.catalogID == nil,
                setCustomText: { character.bloodline = $0 },
                pickerTitle: "Choose Bloodline", searchPrompt: "Search bloodlines",
                sections: character.bloodlinePickerSections, customTitle: "Custom Bloodline", noneTitle: "No Bloodline",
                detail: { character.bloodlineDetail }
            ) { id in
                character.bloodlineSource = id.map { .catalog($0) } ?? .custom("")
            }
            CatalogChoiceRow(
                label: "Covenant:", value: character.covenant, isCustom: character.covenantSource.catalogID == nil,
                setCustomText: { character.covenant = $0 },
                pickerTitle: "Choose Covenant", searchPrompt: "Search covenants",
                sections: character.covenantPickerSections, customTitle: "Custom Covenant", noneTitle: "Unaligned",
                detail: { character.covenantDetail }
            ) { id in
                character.covenantSource = id.map { .catalog($0) } ?? .custom("")
            }
        }
    }

    /// Mask or Dirge: one of the book's archetypes, or the player's own.
    private func archetypeRow(label: String, text: Binding<String>) -> some View {
        CatalogChoiceRow(
            label: label, value: text.wrappedValue,
            isCustom: Catalog.bundled.archetypes.entry(named: text.wrappedValue) == nil,
            setCustomText: { text.wrappedValue = $0 },
            pickerTitle: "Choose \(label.dropLast())", searchPrompt: "Search archetypes",
            sections: { character.archetypePickerSections(chosen: text.wrappedValue) },
            customTitle: "Custom \(label.dropLast())",
            detail: { character.archetypeDetail(named: text.wrappedValue) }
        ) { id in
            text.wrappedValue = id.flatMap { Catalog.bundled.archetypes.entry($0)?.name } ?? ""
        }
    }
}
