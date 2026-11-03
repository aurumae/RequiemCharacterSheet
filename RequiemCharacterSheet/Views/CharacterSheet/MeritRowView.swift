//
//  MeritRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct MeritRowView: View {
    @Bindable var merit: Merit

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            TapToEditText(placeholder: "Merit Name", text: $merit.name) { name in
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
