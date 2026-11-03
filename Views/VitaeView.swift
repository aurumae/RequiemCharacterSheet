//
//  VitaeView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct VitaeView: View {
    @Bindable var character: Character

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledValueRow("Vitae Per Turn:", value: character.vitaePerTurn)
                .padding(.horizontal)

            LabeledValueRow("Max Vitae:", value: character.maxVitae)
                .padding(.horizontal)

            CounterRow("Current Vitae:", value: $character.currentVitae, in: 0...character.maxVitae)
                .padding(.horizontal)
        }
        .padding(.vertical, 4)
        .padding(.horizontal)
    }
}
