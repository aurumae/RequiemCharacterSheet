//
//  WillpowerView.swift
//  Chronicles
//
//  Created by Oisín McColgan on 17/09/2024.
//


import SwiftUI

struct WillpowerView<C: ChroniclesCharacter>: View {
    let character: C

    var body: some View {
        VStack(alignment: .leading) {
            DotsRatingView("Willpower", value: character.willpower, maxRating: character.willpower, dotsPerRow: 10)
            WillpowerBoxesView(character: character)
                .padding(.vertical, 4)
        }
    }
}

