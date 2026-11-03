//
//  DerivedAttributesView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct DerivedAttributesView: View {
    @Bindable var character: Character

    /// Armor can't go below 0; the upper limit just keeps the counter sensible.
    private let armorRange = 0...32

    var body: some View {
        Section(header: Text("ADVANTAGES").themedText(.sectionHeader)) {
            LabeledValueRow("Size:", value: character.size)
            LabeledValueRow("Speed:", value: character.speed)
            LabeledValueRow("Defense (Athletics):", value: character.defense)

            if character.hasDefensiveCombatBrawl {
                LabeledValueRow("Defense (Brawl):", value: character.defenseUsingBrawl)
            }

            if character.hasDefensiveCombatWeaponry {
                LabeledValueRow("Defense (Weaponry):", value: character.defenseUsingWeaponry)
            }

            CounterRow("Armor:", value: $character.armor, in: armorRange)

            LabeledValueRow("Initiative Mod:", value: character.initiativeMod)

            // Five Beats make an Experience
            CounterRow(
                "Beats:",
                value: character.beats,
                canDecrement: character.beats > 0,
                decrement: character.decrementBeats,
                increment: character.incrementBeats
            )

            CounterRow(
                "Experiences:",
                value: character.experiences,
                canDecrement: character.experiences > 0,
                decrement: character.decrementExperiences,
                increment: character.incrementExperiences
            )

            // Combat Dice Pools section
            Text("COMBAT DICE POOLS")
                .themedText(.sectionHeader)
                .padding(.vertical, 4)
                .accessibilityAddTraits(.isHeader)

            LabeledValueRow("Brawl Pool:", value: character.brawlDicePool)
            LabeledValueRow("Firearms Pool:", value: character.firearmsDicePool)
            LabeledValueRow("Weaponry Pool:", value: character.weaponryDicePool)
        }
    }
}
