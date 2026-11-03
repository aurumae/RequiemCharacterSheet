//
//  BaneRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

/// A catalog Bane with its summary and source, or a custom Bane described in free text.
struct BaneRowView: View {
    @Environment(\.theme) private var theme
    @Bindable var bane: Bane
    /// Opens the text for typing, for a custom Bane that was just added.
    var beginsEditing = false
    @FocusState private var isFocused: Bool

    var body: some View {
        if let entry = bane.entry {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .themedText(.traitName)
                Text(entry.summary)
                    .themedText(.detail)
                Text(entry.source.citation())
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        } else {
            TextEditor(text: $bane.text)
                .frame(minHeight: 40, maxHeight: 100)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(theme.muted, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if bane.text.isEmpty {
                        Text("Describe the Bane")
                            .themedText(.body)
                            .foregroundStyle(theme.muted)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .themedText(.body)
                .focused($isFocused)
                .accessibilityLabel("Bane")
                .padding(.vertical, 4)
                .onAppear {
                    if beginsEditing { isFocused = true }
                }
        }
    }
}
