//
//  BloodPotencyView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 17/09/2024.
//


import SwiftUI

struct BloodPotencyView: View {
    @Bindable var character: Character

    private let bloodPotencyRange = 0...10

    /// During guided creation, at most 3, paid for with Merit dots.
    private var maxEditableRating: Int {
        character.editableMaximum(for: TraitKey(.bloodPotency, "bloodPotency"), upTo: bloodPotencyRange.upperBound)
    }

    var body: some View {
        HStack {
            DotsRatingView("Blood Potency", rating: $character.bloodPotency, maxRating: 10, maxEditableRating: maxEditableRating,
                           dotsPerRow: 10, allowsResetToZero: true)
            Spacer()
            StepperButtons(
                canDecrement: character.bloodPotency > bloodPotencyRange.lowerBound,
                canIncrement: character.bloodPotency < maxEditableRating,
                decrement: { character.bloodPotency -= 1 },
                increment: { character.bloodPotency += 1 }
            )
            // The dots above are adjustable with VoiceOver, so these would only repeat them
            .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }
}
