//
//  DotsRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//


import SwiftUI

struct DotsRowView: View {
    @Environment(\.theme) private var theme
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
                DotView(
                    isFilled: index <= totalRating,
                    // Dots above the base rating come from bonuses and are drawn in ink
                    fillColor: index <= rating ? theme.accent : theme.ink,
                    action: isInteractive && index <= maxEditableRating ? { tap(index) } : nil
                )
                // The whole rating is one accessibility element (see DotsRatingView), not each dot
                .accessibilityHidden(true)
            }
        }
    }

    private func tap(_ index: Int) {
        // Tapping the only filled dot clears it, where zero is allowed
        if allowsResetToZero && index == 1 && rating == 1 {
            rating = 0
        } else {
            rating = index
        }
    }
}
