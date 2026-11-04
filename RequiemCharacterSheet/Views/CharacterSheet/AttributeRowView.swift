//
//  AttributeRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//

// Only Attribute names tappable
import SwiftUI

struct AttributeRowView: View {
    let character: Character
    @Bindable var attribute: Attribute
    @State private var showingPicker = false

    private var totalRating: Int {
        character.totalAttributeRating(for: attribute)
    }

    /// The Blood Potency cap, and during guided creation, the starting dots left.
    private var maxEditableRating: Int {
        character.editableMaximum(for: TraitKey(.attribute, attribute.kind.rawValue), upTo: character.baseRatingCap)
    }

    private var maximumVisibleRating: Int {
        character.baseRatingCap >= 6 || totalRating >= 6 ? 10 : 5
    }

    var body: some View {
        HStack {
            Button(action: {
                showingPicker = true
            }) {
                Text(attribute.name)
                    .themedText(.label)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Double-tap to choose a rating")
            .confirmationDialog("Set \(attribute.name)", isPresented: $showingPicker, titleVisibility: .visible) {
                ForEach(Array(character.attributeRatingRange.clamped(to: 1...maxEditableRating)), id: \.self) { value in
                    Button("\(value)") {
                        attribute.rating = value
                    }
                }
            }
            Spacer()
            DotsRatingView(
                attribute.name,
                rating: $attribute.rating,
                totalRating: totalRating,
                maxRating: maximumVisibleRating,
                maxEditableRating: maxEditableRating,
                showsOverflowTotal: true,
                onOverflowTap: {
                    showingPicker = true
                }
            )
        }
        .padding(.vertical, 4)
    }
}
