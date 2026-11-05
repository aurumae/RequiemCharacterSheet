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
    @State private var showingPicker = false
    /// A custom Bane that was just added, whose text opens for typing.
    @State private var newCustomBaneID: UUID?
    /// Set when "Custom Bane" is chosen; the row is added once the picker has closed,
    /// so its text can take keyboard focus from the picker's search field.
    @State private var addsCustomBaneOnDismiss = false

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

            if let bloodline = character.bloodlineEntry {
                // Always in effect, alongside the clan's bane
                VStack(alignment: .leading, spacing: 4) {
                    Text(bloodline.bane.name)
                        .themedText(.traitName)
                    Text(bloodline.bane.summary)
                        .themedText(.detail)
                    Text("\(bloodline.name) bloodline bane · \(bloodline.source.citation())")
                        .themedText(.detail)
                        .foregroundStyle(theme.muted)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }

            ForEach(character.banes) { bane in
                BaneRowView(bane: bane, beginsEditing: bane.id == newCustomBaneID)
                    .editingRow(bane.id)
            }
            .onDelete(perform: deleteBane)

            if character.canAddBane {
                AddRowButton("Add Bane") {
                    showingPicker = true
                }
                .sheet(isPresented: $showingPicker, onDismiss: addCustomBaneIfChosen) {
                    BanePickerView(character: character) { entry in
                        if let entry {
                            character.banes.append(Bane(source: .catalog(entry.id)))
                        } else {
                            addsCustomBaneOnDismiss = true
                        }
                    }
                }
            } else {
                Text("A vampire can have at most \(Character.maxBanes) Banes.")
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
        }
    }

    private func addCustomBaneIfChosen() {
        guard addsCustomBaneOnDismiss else { return }
        addsCustomBaneOnDismiss = false
        let bane = Bane(source: .custom(""))
        newCustomBaneID = bane.id
        character.banes.append(bane)
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
