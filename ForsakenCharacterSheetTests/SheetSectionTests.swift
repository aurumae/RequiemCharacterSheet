//
//  SheetSectionTests.swift
//  ForsakenCharacterSheetTests
//
//  Which sections a character's sheet has, and their headings. These need the app's views and artwork, so they run in
//  Xcode only; the Swift package leaves this file out.
//

import Testing
import UIKit
@testable import ForsakenCharacterSheet

@MainActor
struct SheetSectionTests {
    @Test func thePureHaveNoMoonGiftsSection() {
        let character = ForsakenCharacter()
        #expect(character.sheetSections.contains(.moonGifts))
        character.tribe = "Fire-Touched"
        #expect(!character.sheetSections.contains(.moonGifts))
    }

    @Test func theAuspiceBenefitHasItsSectionExceptForThePure() {
        let character = ForsakenCharacter()
        #expect(!character.sheetSections.contains(.auspiceBenefit))
        character.auspice = "Rahu"
        #expect(character.sheetSections.contains(.auspiceBenefit))
        character.tribe = "Ivory Claws"
        #expect(!character.sheetSections.contains(.auspiceBenefit))
    }

    @Test func aLodgeWithRulesGetsItsSection() {
        let character = ForsakenCharacter()
        #expect(!character.sheetSections.contains(.lodge))
        character.lodgeSource = .catalog("eaters-of-the-dead")
        #expect(!character.sheetSections.contains(.lodge))
        character.lodgeSource = .catalog("the-pack-eaters-of-the-dead")
        #expect(character.sheetSections.contains(.lodge))
        character.lodgeSource = .catalog("field")
        #expect(character.sheetSections.contains(.lodge))
    }

    /// Flat Earth Scribe can't ship in the app, so every heading needs its picture from
    /// scripts/render-forsaken-headings.swift.
    @Test func everySectionHeadingHasItsPicture() {
        let blank = ForsakenCharacter()
        let rahu = ForsakenCharacter.guided()
        rahu.auspice = "Rahu"
        let pure = ForsakenCharacter.guided()
        pure.tribe = "Fire-Touched"
        let adherent = ForsakenCharacter()
        adherent.lodgeSource = .catalog("garm")
        let sections = Set([blank, rahu, pure, adherent].flatMap(\.sheetSections))
        for section in sections {
            #expect(UIImage(named: "Heading " + section.heading) != nil, "\(section.heading)")
        }
    }
}
