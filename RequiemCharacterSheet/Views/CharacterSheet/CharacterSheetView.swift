//
//  CharacterSheetView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//


import SwiftUI

/// A Requiem character's sheet: its sections inside the shared frame (logo, watermark, pill, saving), and the
/// question guided creation asks when a clan's free Attribute dot needs a home.
struct CharacterSheetView: View {
    let character: Character
    let store: CharacterStore

    /// During guided creation, asks which favoured Attribute takes the clan's dot.
    @State private var choosingFavoredAttribute = false

    var body: some View {
        CharacterSheetFrame(character: character, store: store, sections: character.sheetSections) {
            // GUIDED CREATION CHECKLIST
            if character.isInCreation {
                CreationPanelView(character: character) {
                    choosingFavoredAttribute = true
                }
            }

            // CHARACTER SECTION
            CharacterInfoView(character: character)

            // ATTRIBUTES SECTION
            AttributesView(character: character)

            // SKILLS SECTION
            SkillsView(character: character)

            // DISCIPLINES SECTION
            DisciplinesView(character: character)

            // DEVOTIONS, RITUALS and COILS SECTIONS
            DevotionsView(character: character)
            if character.showsRituals {
                RitualsView(character: character)
            }
            if character.showsCoils {
                CoilsView(character: character)
            }

            // MERITS SECTION
            MeritsView(character: character)

            // ASPIRATIONS SECTION
            AspirationsView(character: character)

            // BANES SECTION
            BanesView(character: character)

            // HEALTH SECTION
            SheetSectionBlock(.health) {
                HealthView(character: character)
            }

            // WILLPOWER SECTION
            SheetSectionBlock(.willpower) {
                WillpowerView(character: character)
            }

            // BLOOD POTENCY SECTION
            SheetSectionBlock(.bloodPotency) {
                BloodPotencyView(character: character)
            }
            // VITAE SECTION
            SheetSectionBlock(.vitae) {
                VitaeView(character: character)
            }

            // HUMANITY SECTION
            SheetSectionBlock(.humanity) {
                HumanityView(character: character)
            }

            // DERIVED ATTRIBUTES SECTION
            DerivedAttributesView(character: character)

            // EXPERIENCE SECTION
            ExperienceView(character: character)

            // CONDITIONS SECTION, last so swiping through its cards doesn't interrupt scrolling
            ConditionsView(character: character)
        }
        // Choosing a clan, or a bloodline with its own favoured Attributes, during guided creation asks where the free
        // Attribute dot goes
        .onChange(of: [character.clanSource, character.bloodlineSource]) {
            // The clan is usually chosen in a picker; ask once it has closed, as an alert can't show over it
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                if character.needsFavoredAttribute {
                    choosingFavoredAttribute = true
                }
            }
        }
        // An alert, not a menu: it always sits in the middle of the screen and always shows "Not Now"
        .alert(
            "\(character.creationFavoredAttributeGiver ?? character.clan) Favoured Attribute",
            isPresented: $choosingFavoredAttribute
        ) {
            ForEach(character.creationFavoredAttributes, id: \.self) { kind in
                Button(kind.name) { character.chooseFavoredAttribute(kind) }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("The \(character.creationFavoredAttributeGiver == character.bloodlineEntry?.name ? "bloodline" : "clan") gives one free dot to one of these. It doesn't count against your 5, 4 and 3 Attribute dots.")
        }
    }
}
