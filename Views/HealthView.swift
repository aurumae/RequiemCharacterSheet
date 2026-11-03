//
//  HealthView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//


import SwiftUI

struct HealthView: View {
    let character: Character

    var body: some View {
        VStack(alignment: .leading) {
            DotsRatingView(rating: .constant(character.health), maxRating: character.health, dotsPerRow: 10)
            HealthBoxesView(character: character)
                .padding(.vertical, 4)
        }
    }
}
