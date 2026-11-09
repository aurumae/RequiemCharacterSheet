//
//  DerivedAttributesView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct DerivedAttributesView: View {
    @Bindable var character: Character

    /// Armor can't go below 0; entries above 99 are capped.
    private let armorRange = 0...99

    var body: some View {
        SheetSectionBlock(.advantages) {
            LabeledValueRow("Size:", value: character.effectiveSize)
            LabeledValueRow("Speed:", value: character.speed)
            LabeledValueRow("Defense (Athletics):", value: character.defense, condition: (character, .defense))

            if character.hasDefensiveCombatBrawl {
                LabeledValueRow("Defense (Brawl):", value: character.defenseUsingBrawl, condition: (character, .defense))
            }

            if character.hasDefensiveCombatWeaponry {
                LabeledValueRow("Defense (Weaponry):", value: character.defenseUsingWeaponry, condition: (character, .defense))
            }

            TapToEditNumberRow("Armor:", value: $character.armor, in: armorRange)

            LabeledValueRow("Initiative Mod:", value: character.initiativeMod)

            // Combat Dice Pools section
            Text("Combat Dice Pools")
                .themedText(.subsectionHeader)
                .padding(.vertical, 4)
                .accessibilityAddTraits(.isHeader)

            LabeledValueRow("Brawl Pool:", value: character.brawlDicePool)
            LabeledValueRow("Firearms Pool:", value: character.firearmsDicePool)
            LabeledValueRow("Weaponry Pool:", value: character.weaponryDicePool)
        }
    }
}
