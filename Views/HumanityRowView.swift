//
//  HumanityRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct HumanityRowView: View {
    @Environment(\.theme) private var theme
    @Bindable var touchstone: Touchstone
    @Binding var humanity: Int

    var body: some View {
        HStack {
            // Level Number
            Text("\(touchstone.level)")
                .themedText(.label)

            // Touchstone Text
            TapToEditText(placeholder: "Add Touchstone", text: $touchstone.text, font: .detail) { text in
                Text(text)
                    .themedText(.detail)
                    // Touchstones above the current Humanity are lost
                    .strikethrough(touchstone.level > humanity, color: theme.accent)
            }

            Spacer()

            DotView(isFilled: touchstone.level <= humanity) {
                humanity = touchstone.level
            }
            .accessibilityLabel("Humanity \(touchstone.level)")
            .accessibilityValue(touchstone.level <= humanity ? "Reached" : "Not reached")
            .accessibilityHint("Double-tap to set Humanity to \(touchstone.level)")
        }
        .padding(.vertical, 4)
    }
}
