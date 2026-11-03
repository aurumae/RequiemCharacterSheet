//
//  AspirationRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct AspirationRowView: View {
    @Environment(\.theme) private var theme
    @Bindable var aspiration: Aspiration

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextEditor(text: $aspiration.text)
                .frame(minHeight: 40, maxHeight: 100) // Adjust minHeight and maxHeight as needed
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(theme.muted, lineWidth: 1)
                )
                .themedText(.body)
                .accessibilityLabel("Aspiration")
        }
        .padding(.vertical, 4)
    }
}