//
//  DotsRatingView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//


import SwiftUI

/// A rating shown as rows of dots. VoiceOver reads it as one element named `label`,
/// adjustable by swiping up or down when it's interactive.
struct DotsRatingView: View {
    @Environment(\.theme) private var theme
    @Binding var rating: Int
    /// The rating including bonuses, e.g. Strength plus Vigor. Dots above `rating` are drawn in ink.
    var totalRating: Int
    var maxRating: Int
    var maxEditableRating: Int
    /// Dots at or below this can't be taken away, e.g. the clan's dot during guided creation.
    var minEditableRating: Int
    var dotsPerRow: Int = 5
    var isInteractive: Bool = true
    var showsOverflowTotal: Bool = false
    var allowsResetToZero: Bool = false
    var label: String
    var onOverflowTap: (() -> Void)?

    init(
        _ label: String,
        rating: Binding<Int>,
        totalRating: Int? = nil,
        maxRating: Int,
        maxEditableRating: Int? = nil,
        minEditableRating: Int = 0,
        dotsPerRow: Int = 5,
        isInteractive: Bool = true,
        showsOverflowTotal: Bool = false,
        allowsResetToZero: Bool = false,
        onOverflowTap: (() -> Void)? = nil
    ) {
        self.label = label
        self._rating = rating
        self.totalRating = totalRating ?? rating.wrappedValue
        self.maxRating = maxRating
        self.maxEditableRating = maxEditableRating ?? maxRating
        self.minEditableRating = minEditableRating
        self.dotsPerRow = dotsPerRow
        self.isInteractive = isInteractive
        self.showsOverflowTotal = showsOverflowTotal
        self.allowsResetToZero = allowsResetToZero
        self.onOverflowTap = onOverflowTap
    }

    /// The width of a row of `dots` dots, e.g. to give ratings with fewer dots the same column as five.
    static func width(forDots dots: Int) -> CGFloat {
        CGFloat(dots * 20 + max(0, dots - 1) * 4)
    }

    /// A rating that can't be changed by tapping, such as Health.
    init(_ label: String, value: Int, maxRating: Int, dotsPerRow: Int = 5) {
        self.init(label, rating: .constant(value), maxRating: maxRating, dotsPerRow: dotsPerRow, isInteractive: false)
    }

    var body: some View {
        let rows = (maxRating + dotsPerRow - 1) / dotsPerRow
        let visibleDots = min(maxRating, dotsPerRow)
        let dotRowsWidth = Self.width(forDots: visibleDots)

        VStack(alignment: .leading) {
            if showsOverflowTotal && totalRating > maxRating {
                // Too many dots to draw: show the total, with the base rating in brackets
                Button {
                    onOverflowTap?()
                } label: {
                    HStack(spacing: 4) {
                        Text("\(totalRating)")
                            .font(.system(size: 22))
                            .foregroundStyle(theme.ink)

                        Text("(\(rating))")
                            .font(.system(size: 22))
                            .foregroundStyle(theme.accent)
                    }
                    .frame(width: dotRowsWidth, alignment: .center)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(!isInteractive)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(0..<rows, id: \.self) { rowIndex in
                        DotsRowView(
                            rating: $rating,
                            totalRating: totalRating,
                            rowIndex: rowIndex,
                            maxRating: maxRating,
                            maxEditableRating: maxEditableRating,
                            minEditableRating: minEditableRating,
                            dotsPerRow: dotsPerRow,
                            isInteractive: isInteractive,
                            allowsResetToZero: allowsResetToZero
                        )
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue)
        .modifier(AdjustableRating(
            isEnabled: isInteractive,
            rating: $rating,
            range: max(allowsResetToZero ? 0 : 1, minEditableRating)...max(maxEditableRating, minEditableRating)
        ))
    }

    private var accessibilityValue: String {
        if totalRating > rating {
            return "\(totalRating): \(rating) base plus \(totalRating - rating) bonus"
        }
        return "\(rating) of \(maxEditableRating)"
    }
}

/// Lets VoiceOver users swipe up or down to change a rating within `range`.
private struct AdjustableRating: ViewModifier {
    let isEnabled: Bool
    @Binding var rating: Int
    let range: ClosedRange<Int>

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        rating = min(rating + 1, range.upperBound)
                    case .decrement:
                        rating = max(rating - 1, range.lowerBound)
                    @unknown default:
                        break
                    }
                }
        } else {
            content
        }
    }
}
