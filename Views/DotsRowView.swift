//
//  DotsRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//


import SwiftUI

struct DotsRowView: View {
    @Binding var rating: Int
    var totalRating: Int
    var rowIndex: Int
    var maxRating: Int
    var maxEditableRating: Int
    var dotsPerRow: Int = 5
    var isInteractive: Bool = true
    var allowsResetToZero: Bool = false
    
    var body: some View {
        let startIndex = rowIndex * dotsPerRow + 1
        let endIndex = min(startIndex + dotsPerRow - 1, maxRating)
        HStack(spacing: 4) {
            ForEach(startIndex...endIndex, id: \.self) { index in
                DotView(index: index, isFilled: index <= totalRating, fillColor: fillColor(for: index), isInteractive: isInteractive && index <= maxEditableRating) { tappedIndex in
                    if allowsResetToZero && tappedIndex == 1 && rating == 1 {
                        rating = 0
                    } else {
                        rating = tappedIndex
                    }
                }
            }
        }
    }

    private func fillColor(for index: Int) -> Color {
        index <= rating ? .vampireRed : .black
    }
}
