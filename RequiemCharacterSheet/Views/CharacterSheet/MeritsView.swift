//
//  MeritsView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct MeritsView: View {
    let character: Character
    @State private var showingPicker = false
    /// A custom Merit that was just added, whose name opens for editing.
    @State private var newCustomMeritID: UUID?
    /// Set when "Custom Merit" is chosen; the row is added once the picker has closed, so its name
    /// field can take keyboard focus from the picker's search field.
    @State private var addsCustomMeritOnDismiss = false

    var body: some View {
        Section(header: Text("MERITS").themedText(.sectionHeader)) {
            ForEach(character.merits) { merit in
                MeritRowView(merit: merit, character: character, beginsEditing: merit.id == newCustomMeritID)
            }
            .onDelete(perform: deleteMerit)

            AddRowButton("Add Merit") {
                showingPicker = true
            }
            .sheet(isPresented: $showingPicker, onDismiss: addCustomMeritIfChosen) {
                MeritPickerView(character: character) { entry, qualifier in
                    if let entry {
                        // A chosen Merit starts at its lowest rating
                        character.merits.append(Merit(source: .catalog(entry.id), qualifier: qualifier, rating: entry.ratings.min() ?? 1))
                    } else {
                        addsCustomMeritOnDismiss = true
                    }
                }
            }
        }
    }

    private func addCustomMeritIfChosen() {
        guard addsCustomMeritOnDismiss else { return }
        addsCustomMeritOnDismiss = false
        let merit = Merit(source: .custom(""), rating: 1)
        newCustomMeritID = merit.id
        character.merits.append(merit)
    }

    func deleteMerit(at offsets: IndexSet) {
        character.merits.remove(atOffsets: offsets)
    }
}
