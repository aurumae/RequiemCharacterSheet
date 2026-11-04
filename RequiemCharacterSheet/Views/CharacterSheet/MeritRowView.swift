//
//  MeritRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct MeritRowView: View {
    @Environment(\.theme) private var theme
    @Bindable var merit: Merit
    let character: Character
    /// Opens the name for editing, for a custom Merit that was just added.
    var beginsEditing = false
    @State private var showingDetail = false

    var body: some View {
        if let entry = merit.entry {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 8) {
                    // Catalog Merits open their details; to change one, delete it and add another
                    Button {
                        showingDetail = true
                    } label: {
                        Text(merit.name)
                            .themedText(.traitName)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows its details")
                    .sheet(isPresented: $showingDetail) {
                        MeritDetailView(merit: merit, entry: entry, character: character)
                    }

                    Spacer()

                    // Only as many dots as the Merit can have, centred in a five-dot column,
                    // so a Merit capped below five (e.g. Defensive Combat) reads as capped
                    DotsRatingView(
                        merit.name,
                        rating: allowedRating(for: entry),
                        maxRating: entry.ratings.max() ?? 5,
                        maxEditableRating: maxEditableRating(upTo: entry.ratings.max() ?? 5),
                        allowsResetToZero: true
                    )
                    .frame(width: DotsRatingView.width(forDots: 5), alignment: .center)
                }

                let unmet = character.unmetPrerequisites(for: entry)
                if !unmet.isEmpty {
                    Label(unmet.warningText, systemImage: "exclamationmark.triangle")
                        .themedText(.detail)
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.vertical, 4)
        } else {
            HStack(alignment: .center, spacing: 8) {
                TapToEditText(placeholder: "Merit Name", text: $merit.name, beginsEditing: beginsEditing) { name in
                    Text(name)
                        .themedText(.traitName)
                }

                Spacer()

                DotsRatingView(
                    merit.name.isEmpty ? "Merit" : merit.name,
                    rating: $merit.rating,
                    maxRating: 5,
                    maxEditableRating: maxEditableRating(upTo: 5),
                    allowsResetToZero: true
                )
            }
            .padding(.vertical, 4)
        }
    }

    /// During guided creation, the Merit dots left.
    private func maxEditableRating(upTo cap: Int) -> Int {
        character.editableMaximum(for: TraitKey(.merit, merit.id.uuidString), upTo: cap)
    }

    /// The rating, snapped to one the Merit allows, e.g. Iron Skin is bought at 2 or 4.
    private func allowedRating(for entry: MeritEntry) -> Binding<Int> {
        Binding(
            get: { merit.rating },
            set: { newValue in
                let snapped = entry.allowedRating(for: newValue)
                // Never snap up past the creation limit, e.g. to 4 when only 3 Merit dots are left
                let limit = maxEditableRating(upTo: entry.ratings.max() ?? 5)
                merit.rating = snapped <= limit ? snapped : (entry.ratings.filter { $0 <= limit }.max() ?? merit.rating)
            }
        )
    }
}
