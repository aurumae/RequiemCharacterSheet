//
//  DotsRatingView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//


import SwiftUI

struct DotsRatingView: View {
    @Binding var rating: Int
    var totalRating: Int
    var maxRating: Int
    var maxEditableRating: Int
    var dotsPerRow: Int = 5
    var isInteractive: Bool = true
    var showsOverflowTotal: Bool = false
    var allowsResetToZero: Bool = false
    var onOverflowTap: (() -> Void)?

    init(
        rating: Binding<Int>,
        totalRating: Int? = nil,
        maxRating: Int,
        maxEditableRating: Int? = nil,
        dotsPerRow: Int = 5,
        isInteractive: Bool = true,
        showsOverflowTotal: Bool = false,
        allowsResetToZero: Bool = false,
        onOverflowTap: (() -> Void)? = nil
    ) {
        self._rating = rating
        self.totalRating = totalRating ?? rating.wrappedValue
        self.maxRating = maxRating
        self.maxEditableRating = maxEditableRating ?? maxRating
        self.dotsPerRow = dotsPerRow
        self.isInteractive = isInteractive
        self.showsOverflowTotal = showsOverflowTotal
        self.allowsResetToZero = allowsResetToZero
        self.onOverflowTap = onOverflowTap
    }
    
    var body: some View {
        let rows = (maxRating + dotsPerRow - 1) / dotsPerRow
        let visibleDots = min(maxRating, dotsPerRow)
        let dotRowsWidth = CGFloat(visibleDots * 20 + max(0, visibleDots - 1) * 4)

        HStack(alignment: .center, spacing: 8) {
            if showsOverflowTotal && totalRating > maxRating {
                HStack(spacing: 4) {
                    Text("\(totalRating)")
                        .font(.system(size: 22))
                        .foregroundColor(.black)

                    Text("(\(rating))")
                        .font(.system(size: 22))
                        .foregroundColor(.vampireRed)
                }
                .frame(width: dotRowsWidth, alignment: .center)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isInteractive {
                        onOverflowTap?()
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(0..<rows, id: \.self) { rowIndex in
                        DotsRowView(rating: $rating, totalRating: totalRating, rowIndex: rowIndex, maxRating: maxRating, maxEditableRating: maxEditableRating, dotsPerRow: dotsPerRow, isInteractive: isInteractive, allowsResetToZero: allowsResetToZero)
                    }
                }
            }
        }
    }
}
