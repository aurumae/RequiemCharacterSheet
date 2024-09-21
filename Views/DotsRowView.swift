//
//  DotsRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//

import SwiftUI

struct DotsRowView: View {
    @Binding var rating: Int
    var rowIndex: Int
    var maxRating: Int
    var dotsPerRow: Int = 5
    var isInteractive: Bool = true
    
    var body: some View {
        let startIndex = rowIndex * dotsPerRow + 1
        let endIndex = min(startIndex + dotsPerRow - 1, maxRating)
        HStack(spacing: 4) {
            ForEach(startIndex...endIndex, id: \.self) { index in
                DotView(index: index, isFilled: index <= rating, isInteractive: isInteractive) { tappedIndex in
                    rating = tappedIndex
                }
            }
        }
    }
}

