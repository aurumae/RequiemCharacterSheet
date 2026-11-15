//
//  AttributeRowView.swift
//  Chronicles
//
//  Created by Oisín McColgan on 16/09/2024.
//

// Only Attribute names tappable
import SwiftUI

struct AttributeRowView<C: SheetCharacter>: View {
    @Environment(\.theme) private var theme
    let character: C
    @Bindable var attribute: Attribute
    @State private var showingPicker = false

    private var totalRating: Int {
        character.totalAttributeRating(for: attribute)
    }

    /// The Blood Potency cap, and during guided creation, the starting dots left.
    private var maxEditableRating: Int {
        character.editableMaximum(for: TraitKey(.attribute, attribute.kind.rawValue), upTo: character.baseRatingCap)
    }

    /// As many dots as Blood Potency allows, or the rating with bonuses if that's more, e.g. with Vigor.
    /// Dots that can never be bought aren't drawn.
    private var maximumVisibleRating: Int {
        min(10, max(character.baseRatingCap, totalRating))
    }

    var body: some View {
        HStack {
            Button(action: {
                showingPicker = true
            }) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(attribute.name)
                        .themedText(.ratedTrait)
                    if let note = character.attributeNote(for: attribute.kind) {
                        Text(note)
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
            // A mark if a Condition affects it
            character.conditionMark(for: .attribute(attribute.kind), traitName: attribute.name)
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
