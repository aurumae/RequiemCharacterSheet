//
//  ForsakenSheetView.swift
//  ForsakenCharacterSheet
//

import SwiftUI

/// A Forsaken character's sheet, in the official sheet's order, as one column.
struct ForsakenSheetView: View {
    let character: ForsakenCharacter
    let store: CharacterFileStore<ForsakenCharacter>

    var body: some View {
        CharacterSheetFrame(character: character, store: store, sections: character.sheetSections) {
            ForsakenCharacterInfoView(character: character)
            FormView(character: character)
            AttributesView(character: character)
            SkillsView(character: character)
            MeritsView(character: character)
            RenownView(character: character)
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
    }
}

extension ForsakenCharacter {
    /// The sections this character's sheet shows, in order.
    var sheetSections: [SheetSection] {
        let gifts: [SheetSection] = isPure ? [.shadowGifts, .wolfGifts] : [.moonGifts, .shadowGifts, .wolfGifts]
        return [.character, .form, .attributes, .skills, .merits, .renown] + gifts
            + [.rites, .fetishes, .aspirations, .health, .willpower, .primalUrge, .harmony, .kuruth, .experience, .conditions]
    }
}
