//
//  BaneRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct BaneRowView: View {
    @Environment(\.theme) private var theme
    @Bindable var bane: Bane

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextEditor(text: $bane.text)
                .frame(minHeight: 40, maxHeight: 100) // Adjust minHeight and maxHeight as needed
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(theme.muted, lineWidth: 1)
                )
                .themedText(.body)
                .accessibilityLabel("Bane")
        }
        .padding(.vertical, 4)
    }
}