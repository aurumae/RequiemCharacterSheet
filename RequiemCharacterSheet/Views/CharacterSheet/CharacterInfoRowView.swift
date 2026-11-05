//
//  CharacterInfoRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct CharacterInfoRowView: View {
    @Environment(\.theme) private var theme
    let label: String
    @Binding var text: String
    /// Official options to pick from, e.g. Mask archetypes. Typing your own still works.
    var choices: [String] = []

    var body: some View {
        HStack {
            Text(label)
                .themedText(.label)
                .frame(minWidth: 100, alignment: .leading)

            Spacer()

            TapToEditText("Tap to edit", text: $text)

            if !choices.isEmpty {
                Menu {
                    ForEach(choices, id: \.self) { choice in
                        Button(choice) { text = choice }
                    }
                } label: {
                    Image(systemName: "list.bullet")
                        .foregroundStyle(theme.accent)
                        .padding(.leading, 4)
                }
                .accessibilityLabel("Choose \(label.trimmingCharacters(in: CharacterSet(charactersIn: ":")))")
            }
        }
        .padding(.vertical, 4)
        .editingRow("info-\(label)")
    }
}
