//
//  CharacterInfoRowView.swift
//  Chronicles
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct CharacterInfoRowView: View {
    let label: String
    @Binding var text: String
    /// Identifies the row in the list; must be unique on the sheet, so two rows with the same label (e.g. the
    /// character's and the totem's "Name:") need their own.
    var rowID: String?

    var body: some View {
        HStack {
            Text(label)
                .themedText(.label)
                .frame(minWidth: 100, alignment: .leading)

            Spacer()

            TapToEditText("Tap to edit", accessibilityName: label.trimmingCharacters(in: CharacterSet(charactersIn: ":")), text: $text)
        }
        .padding(.vertical, 4)
        .editingRow(rowID ?? "info-\(label)")
    }
}
