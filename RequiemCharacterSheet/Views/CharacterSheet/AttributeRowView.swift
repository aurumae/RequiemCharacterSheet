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
                ForEach(Array(character.attributeRatingRange), id: \.self) { value in
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
                maxEditableRating: character.baseRatingCap,
                showsOverflowTotal: true,
                onOverflowTap: {
                    showingPicker = true
                }
            )
        }
        .padding(.vertical, 4)
    }
}
