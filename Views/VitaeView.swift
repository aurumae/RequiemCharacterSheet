//
//  VitaeView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct VitaeView: View {
    @Bindable var character: Character

    /// Each value is its own list row, like the rows in Advantages.
    var body: some View {
        LabeledValueRow("Vitae Per Turn:", value: character.vitaePerTurn)
        LabeledValueRow("Max Vitae:", value: character.maxVitae)
        CounterRow("Current Vitae:", value: $character.currentVitae, in: 0...character.maxVitae)
    }
}
