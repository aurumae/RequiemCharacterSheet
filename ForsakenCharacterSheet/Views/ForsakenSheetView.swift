//
//  ForsakenSheetView.swift
//  ForsakenCharacterSheet
//

import SwiftUI

/// A Forsaken character's sheet, in the official sheet's order. The rest of the shared sections, and the Werewolf ones,
/// follow.
struct ForsakenSheetView: View {
    let character: ForsakenCharacter
    let store: CharacterFileStore<ForsakenCharacter>

    var body: some View {
        CharacterSheetFrame(character: character, store: store, sections: character.sheetSections) {
            ForsakenCharacterInfoView(character: character)
            AttributesView(character: character)
            SkillsView(character: character)
            MeritsView(character: character)
            AspirationsView(character: character)
            SheetSectionBlock(.health) {
                HealthView(character: character)
            }
            SheetSectionBlock(.willpower) {
                WillpowerView(character: character)
            }
            ExperienceView(character: character)
            // Last, so swiping through its cards doesn't interrupt scrolling
            ConditionsView(character: character)
        }
    }
}

extension ForsakenCharacter {
    /// The sections this character's sheet shows, in order.
    var sheetSections: [SheetSection] {
        [.character, .attributes, .skills, .merits, .aspirations, .health, .willpower, .experience, .conditions]
    }
}

/// The Character section: the details at the top of the official sheet, in its order.
struct ForsakenCharacterInfoView: View {
    @Bindable var character: ForsakenCharacter

    var body: some View {
        SheetSectionBlock(.character) {
            CharacterInfoRowView(label: "Name:", text: $character.name)
            CharacterInfoRowView(label: "Player:", text: $character.player)
            CharacterInfoRowView(label: "Chronicle:", text: $character.chronicle)
            CharacterInfoRowView(label: "Blood:", text: $character.blood)
            CharacterInfoRowView(label: "Bone:", text: $character.bone)
            CharacterInfoRowView(label: "Concept:", text: $character.concept)
            CharacterInfoRowView(label: "Auspice:", text: $character.auspice)
            CharacterInfoRowView(label: "Tribe:", text: $character.tribe)
            CharacterInfoRowView(label: "Lodge:", text: $character.lodge)
        }
    }
}
