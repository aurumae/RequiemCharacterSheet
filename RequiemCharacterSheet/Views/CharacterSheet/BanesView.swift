//
//  BanesView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct BanesView: View {
    @Environment(\.theme) private var theme
    @Bindable var character: Character

    var body: some View {
        Section(header: Text("BANES").themedText(.sectionHeader)) {
            if let clan = character.clanEntry {
                ClanBaneRow(
                    clan: clan,
                    threshold: character.clanBaneThreshold,
                    humanity: character.humanity,
                    isActive: $character.clanBaneActive
                )
            }

            ForEach(character.banes) { bane in
                BaneRowView(bane: bane)
            }
            .onDelete(perform: deleteBane)

            if character.canAddBane {
                AddRowButton("Add Bane") {
                    character.banes.append(Bane())
                }
            } else {
                Text("A vampire can have at most \(Character.maxBanes) Banes.")
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
        }
    }

    func deleteBane(at offsets: IndexSet) {
        character.banes.remove(atOffsets: offsets)
    }
}

/// The clan's bane, with a switch for whether it's in effect. It switches on by itself when Humanity
/// falls to the threshold; switching it off undoes that, e.g. after trying out changes.
private struct ClanBaneRow: View {
    @Environment(\.theme) private var theme
    let clan: ClanEntry
    let threshold: Int
    let humanity: Int
    @Binding var isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Clan Bane: \(clan.bane.name)")
                .themedText(.traitName)
            Text(clan.bane.summary)
                .themedText(.detail)

            Toggle(isOn: $isActive) {
                Text("In effect")
                    .themedText(.body)
            }
            .tint(theme.accent)
            .accessibilityLabel("\(clan.bane.name) in effect")
            .accessibilityHint("Turns on by itself when Humanity falls to \(threshold).")

            Text(status)
                .themedText(.detail)
                .foregroundStyle(theme.muted)
        }
        .padding(.vertical, 4)
    }

    private var status: String {
        if isActive {
            if clan.bane.grantsExtraBane {
                return "Record the extra Bane below; it counts toward the limit of \(Character.maxBanes)."
            }
            return "Stays in effect if Humanity rises again."
        }
        if humanity <= threshold {
            return "Switched off. Turns on again if Humanity falls to \(threshold) from above."
        }
        return "Takes effect when Humanity falls to \(threshold)."
    }
}
