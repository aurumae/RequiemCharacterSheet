//
//  WillpowerView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 17/09/2024.
//


import SwiftUI

struct WillpowerView: View {
    let character: Character

    var body: some View {
        VStack(alignment: .leading) {
            DotsRatingView(rating: .constant(character.willpower), maxRating: character.willpower, dotsPerRow: 10)
            WillpowerBoxesView(character: character)
                .padding(.vertical, 4)
        }
    }
}

