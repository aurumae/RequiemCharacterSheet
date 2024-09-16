//
//  DotsRatingView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//

import SwiftUI

struct DotsRatingView: View {
    @Binding var rating: Int
    var maxRating: Int
    var dotsPerRow: Int = 5
    
    var body: some View {
        let rows = (maxRating + dotsPerRow - 1) / dotsPerRow
        VStack(alignment: .leading, spacing: 2) {
            ForEach(0..<rows, id: \.self) { rowIndex in
                DotsRowView(rating: $rating, rowIndex: rowIndex, maxRating: maxRating, dotsPerRow: dotsPerRow)
            }
        }
    }
}
