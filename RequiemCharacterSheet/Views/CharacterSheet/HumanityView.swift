//
//  HumanityView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct HumanityView: View {
    @Environment(\.theme) private var theme
    @Bindable var character: Character

    /// During guided creation, Humanity starts at 7.
    private var maxHumanity: Int {
        character.editableMaximum(for: TraitKey(.humanity, "humanity"), upTo: 10)
    }

    /// Each Touchstone is its own list row, so the one being edited can be scrolled clear of the keyboard
    /// (lists scroll to whole rows). The rows are packed closely with no separators, to read as one track.
    var body: some View {
        Group {
            if let cap = character.humanityCap {
                // A warning only when Humanity is above the limit, e.g. just after learning a dot of Crúac
                if character.humanity > cap.limit {
                    RowWarning("\(cap.disciplineName) \(cap.dots) limits Humanity to \(cap.limit)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("\(cap.disciplineName) \(cap.dots) limits Humanity to \(cap.limit)")
                        .themedText(.detail)
                        .foregroundStyle(theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            ForEach(character.touchstones.sorted(by: { $0.level > $1.level })) { touchstone in
                HumanityRowView(touchstone: touchstone, humanity: $character.humanity, maxHumanity: maxHumanity)
                    .editingRow(touchstone.id)
            }
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }
}
