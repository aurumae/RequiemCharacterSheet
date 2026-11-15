//
//  RequiemSheetSections.swift
//  RequiemCharacterSheet
//
//  The sections of a Requiem sheet, for the section pill.
//

import SwiftUI

extension SheetSection {
    static let creation = SheetSection("creation", title: "Creation", heading: "Character Creation")
    static let disciplines = SheetSection("disciplines", title: "Disciplines")
    static let devotions = SheetSection("devotions", title: "Devotions")
    static let rituals = SheetSection("rituals", title: "Rituals")
    static let coils = SheetSection("coils", title: "Coils", heading: "Coils of the Dragon")
    static let banes = SheetSection("banes", title: "Banes")
    static let bloodPotency = SheetSection("bloodPotency", title: "Blood Potency")
    static let vitae = SheetSection("vitae", title: "Vitae")
    static let humanity = SheetSection("humanity", title: "Humanity")

    /// Every section a Requiem sheet can have, in order.
    static let requiemOrder: [SheetSection] = [
        .creation, .character, .attributes, .skills, .disciplines, .devotions, .rituals, .coils, .merits,
        .aspirations, .banes, .health, .willpower, .bloodPotency, .vitae, .humanity, .advantages, .experience,
        .conditions,
    ]
}

extension Character {
    /// The sections this character's sheet shows, in order.
    var sheetSections: [SheetSection] {
        SheetSection.requiemOrder.filter { section in
            switch section {
            case .creation: isInCreation
            case .rituals: showsRituals
            case .coils: showsCoils
            default: true
            }
        }
    }
}
