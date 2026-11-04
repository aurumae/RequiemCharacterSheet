//
//  AttributeRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//

// Only Attribute names tappable
import SwiftUI

struct AttributeRowView: View {
    @Environment(\.theme) private var theme
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
                VStack(alignment: .leading, spacing: 0) {
                    Text(attribute.name)
                        .themedText(.label)
                    if character.creation?.favoredAttribute == attribute.kind {
                        // The clan's free dot, outside the 5/4/3
                        Text("Includes the \(character.clan) dot")
                            .themedText(.detail)
                            .foregroundStyle(theme.muted)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Double-tap to choose a rating")
            .confirmationDialog("Set \(attribute.name)", isPresented: $showingPicker, titleVisibility: .visible) {
                ForEach(Array(character.attributeRatingRange.clamped(to: character.minimumRating(of: attribute.kind)...max(maxEditableRating, character.minimumRating(of: attribute.kind)))), id: \.self) { value in
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
                minEditableRating: character.minimumRating(of: attribute.kind),
                showsOverflowTotal: true,
                onOverflowTap: {
                    showingPicker = true
                }
            )
        }
        .padding(.vertical, 4)
    }
}
