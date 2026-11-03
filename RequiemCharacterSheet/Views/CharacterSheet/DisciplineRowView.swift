//
//  DisciplineRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct DisciplineRowView: View {
    @Bindable var discipline: Discipline

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            TapToEditText(placeholder: "Discipline Name", text: $discipline.name) { name in
                Text(name)
                    .themedText(.traitName)
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
