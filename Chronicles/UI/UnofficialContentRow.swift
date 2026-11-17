//
//  UnofficialContentRow.swift
//  Chronicles
//

import SwiftUI

/// The switch that shows or hides unofficial content in every picker on the sheet. Official books are always shown.
struct UnofficialContentRow: View {
    @Environment(\.theme) private var theme
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Unofficial Content")
                    .themedText(.label)
                Text("Fan-made and preview material, e.g. from the publisher's blog.")
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
        }
        .tint(theme.accent)
        .padding(.vertical, 4)
    }
}
