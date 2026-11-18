//
//  ForsakenSheetView.swift
//  ForsakenCharacterSheet
//

import SwiftUI

/// A Forsaken character's sheet, in the official sheet's order, as one column.
struct ForsakenSheetView: View {
    let character: ForsakenCharacter
    let store: CharacterFileStore<ForsakenCharacter>
    /// During guided creation, asks which of the auspice's Skills takes the free dot.
    @State private var choosingFreeSkill = false

    var body: some View {
        CharacterSheetFrame(character: character, store: store, sections: character.sheetSections) {
            if character.isInCreation {
                CreationPanelView(character: character)
            }
            ForsakenCharacterInfoView(character: character)
            FormView(character: character)
            AdvantagesView(character: character)
            AttributesView(character: character)
            SkillsView(character: character)
            MeritsView(character: character)
            TotemView(character: character)
            RenownView(character: character)
            if let (auspice, benefit) = character.auspiceBenefit {
                AuspiceBenefitView(benefit: benefit, auspice: auspice)
            }
            if let lodge = character.lodgeWithRules {
                LodgeView(lodge: lodge)
            }
            // The Pure flay away Luna's mark, and with it any Moon Gift
            if !character.isPure {
                MoonGiftView(character: character)
            }
            GiftsView(character: character, kind: .shadow)
            GiftsView(character: character, kind: .wolf)
            RitesView(character: character)
            FetishesView(character: character)
            AspirationsView(character: character)
            SheetSectionBlock(.health) {
                HealthView(character: character)
            }
            SheetSectionBlock(.willpower) {
                WillpowerView(character: character)
            }
            PrimalUrgeView(character: character)
            HarmonyView(character: character)
            KuruthView(character: character)
            ExperienceView(character: character)
            // Last, so swiping through its cards doesn't interrupt scrolling
            ConditionsView(character: character)
        }
        // As a shift to a smaller form does, anything else that takes Health boxes away keeps their wounds (p. 172)
        .onChange(of: character.health) { old, new in
            if new < old { character.foldLostHealth() }
        }
        // Choosing an auspice or tribe during creation gives its Renown dot, and asks for the free Skill dot
        .onChange(of: character.auspiceSource) { creationTraitsChanged() }
        .onChange(of: character.tribeSource) { creationTraitsChanged() }
        .confirmationDialog("Free Skill Dot", isPresented: $choosingFreeSkill, titleVisibility: .visible) {
            ForEach(character.freeSkillChoices, id: \.self) { id in
                Button(SkillDefinition.withID(id)?.name ?? id.rawValue) { character.chooseFreeSkill(id) }
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("\(character.freeSkillGiver ?? "Your auspice") gives a free dot in one of these Skills. You can change it in the Character Creation panel.")
        }
    }
}

extension ForsakenSheetView {
    private func creationTraitsChanged() {
        guard character.isInCreation else { return }
        character.applyCreationGrants()
        if character.needsFreeSkill {
            choosingFreeSkill = true
        }
    }
}

extension ForsakenCharacter {
    /// The sections this character's sheet shows, in order.
    var sheetSections: [SheetSection] {
        let gifts: [SheetSection] = isPure ? [.shadowGifts, .wolfGifts] : [.moonGifts, .shadowGifts, .wolfGifts]
        let benefit: [SheetSection] = (auspiceBenefit == nil ? [] : [.auspiceBenefit]) + (lodgeWithRules == nil ? [] : [.lodge])
        return (isInCreation ? [.creation] : []) + [.character, .form, .advantages, .attributes, .skills, .merits, .totem, .renown] + benefit + gifts
            + [.rites, .fetishes, .aspirations, .health, .willpower, .primalUrge, .harmony, .kuruth, .experience, .conditions]
    }
}
