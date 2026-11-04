//
//  AspirationRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct AspirationRowView: View {
    @Bindable var aspiration: Aspiration
    /// Opens the field for typing, for an Aspiration that was just added.
    var beginsEditing = false

    var body: some View {
        // Shown like other entries, in the theme's red display face; a sentence or two wraps over several lines
        TapToEditText(placeholder: "Tap to write an Aspiration", text: $aspiration.text, font: .traitName,
                      multiline: true, beginsEditing: beginsEditing) { text in
            Text(text)
                .themedText(.traitName)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}