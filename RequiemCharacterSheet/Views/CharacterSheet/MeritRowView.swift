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

                    // Only as many dots as the Merit can have, e.g. one for Defensive Combat
                    DotsRatingView(
                        merit.name,
                        rating: allowedRating(for: entry),
                        maxRating: entry.ratings.max() ?? 5,
                        allowsResetToZero: true
                    )
                }

                let unmet = character.unmetPrerequisites(for: entry)
                if !unmet.isEmpty {
                    Label("Requires \(unmet.map(\.description).joined(separator: "; "))", systemImage: "exclamationmark.triangle")
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
                    allowsResetToZero: true
                )
            }
            .padding(.vertical, 4)
        }
    }

    /// The rating, snapped to one the Merit allows, e.g. Iron Skin is bought at 2 or 4.
    private func allowedRating(for entry: MeritEntry) -> Binding<Int> {
        Binding(
            get: { merit.rating },
            set: { merit.rating = entry.allowedRating(for: $0) }
        )
    }
}
