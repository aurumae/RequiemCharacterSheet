//
//  ForsakenSheetCharacter.swift
//  ForsakenCharacterSheet
//
//  Makes a Forsaken character one the shared sheet sections and character list can show. The rules they ask for are
//  in Models/ForsakenCharacter.swift; here is only what needs SwiftUI.
//

import SwiftUI

extension ForsakenCharacter: SheetCharacter {
    func categoryAccessory(for category: TraitCategory, skills: Bool) -> AnyView? {
        // During guided creation, the player chooses where the 5/4/3 or 11/7/4 dots go
        isInCreation ? AnyView(CreationPriorityMenu(character: self, category: category, skills: skills)) : nil
    }
}

extension ForsakenCharacter: ListedCharacter {
    static var offersGuidedCreation: Bool { true }

    static func newCharacter(guided: Bool) -> ForsakenCharacter {
        guided ? .guided() : ForsakenCharacter()
    }
}
