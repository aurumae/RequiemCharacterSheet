//
//  DisciplineRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct DisciplineRowView: View {
    @Bindable var discipline: Discipline
    let character: Character
    @State private var showingDetail = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let entry = discipline.entry {
                // Catalog Disciplines open their powers; to change one, delete it and add another
                Button {
                    showingDetail = true
                } label: {
                    Text(entry.name)
                        .themedText(.traitName)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows its powers")
                .sheet(isPresented: $showingDetail) {
                    DisciplineDetailView(entry: entry, rating: discipline.rating, character: character)
                }
            } else {
                TapToEditText(placeholder: "Discipline Name", text: $discipline.name) { name in
                    Text(name)
                        .themedText(.traitName)
                }
            }

            Spacer()

            DotsRatingView(
                discipline.name.isEmpty ? "Discipline" : discipline.name,
                rating: $discipline.rating,
                maxRating: 5,
                allowsResetToZero: true
            )
        }
        .padding(.vertical, 4)
    }
}
