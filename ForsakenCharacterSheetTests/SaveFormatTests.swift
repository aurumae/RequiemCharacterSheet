//
//  SaveFormatTests.swift
//  ForsakenCharacterSheetTests
//
//  Pins the save format (docs/forsaken-save-format.md) with two saved characters in Fixtures/.
//

import Foundation
import Testing
@testable import ForsakenCharacterSheet
#if SWIFT_PACKAGE
@testable import ChroniclesCore
#endif

/// Finds the test bundle, where the fixtures are.
private final class FixtureBundle {}

@MainActor
struct SaveFormatTests {
    /// A Cahalith well into play, and a Predator King part-way through guided creation. Between them they use every
    /// key the format has.
    private nonisolated static let fixtures = ["forsaken-v1-play", "forsaken-v1-creation"]

    private func data(_ name: String) throws -> Data {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: FixtureBundle.self)
        #endif
        let url = try #require(bundle.url(forResource: name, withExtension: "json"), "\(name)")
        return try Data(contentsOf: url)
    }

    private func object(_ data: Data) throws -> NSDictionary {
        try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }

    @Test(arguments: fixtures)
    func aSavedCharacterIsWrittenBackUnchanged(_ name: String) throws {
        let saved = try data(name)
        let character = try JSONDecoder().decode(ForsakenCharacter.self, from: saved)
        let written = try JSONEncoder().encode(character)
        #expect(try object(written) == object(saved))
    }

    /// A key added to the format has to be added to a fixture, and so to the format's description.
    @Test func theFixturesUseEveryKey() throws {
        let used = try Self.fixtures.reduce(into: Set<String>()) { keys, name in
            keys.formUnion(try object(data(name)).allKeys.compactMap { $0 as? String })
        }
        #expect(used == Set(ForsakenCharacter.CodingKeys.allCases.map(\.stringValue)))
        #expect(ForsakenCharacter.currentSchemaVersion == 1)
    }

    @Test func thePlayFixtureMeansWhatItSays() throws {
        let character = try JSONDecoder().decode(ForsakenCharacter.self, from: data("forsaken-v1-play"))
        #expect(character.name == "Mara Voss")
        #expect(character.auspiceEntry?.name == "Cahalith" && character.tribeEntry?.name == "Blood Talons")
        #expect(character.lodgeEntry?.id == "garm")
        #expect(character.bloodSource == .catalog("challenger") && character.boneSource == .custom("Stray"))
        #expect(character.form == .dalu)
        // Glory 3, Purity 1, Cunning 1
        #expect(character.spiritRank == 2)
        #expect(character.moonGiftName == "Gift of the Blood Moon" && character.moonGiftDots == 3)
        #expect(character.customMoonFacets.count == 3)
        #expect(character.extraMoonGifts.map(character.moonGiftName) == ["Gift of the Screaming Moon", "Gift of the Harvest Moon"])
        #expect(character.extraMoonGifts.map(\.dots) == [2, 1])
        #expect(character.facets.count == 5)
        #expect(character.facets.filter(\.isActive).map(character.facetName) == ["Primal Strength"])
        #expect(character.facets.filter(\.learnedWithRenown).count == 1)
        #expect(character.renownFacetCredits == [.honor: 1])
        #expect(character.rites.map(character.riteRating) == [1, 2])
        #expect(character.fetishes.map(\.note) == ["Two uses left", "A spirit of feedback"])
        #expect(character.totem.experiencesSpent == 6 && character.totem.experienceBudget == 3)
        // Strength 3, a dot from the totem, Totemic Empowerment and Primal Strength (Purity 1), Dalu's dot; and in
        // Gauru the form's three and Favored Form's
        #expect(character.rating(.strength, in: .dalu) == 7)
        #expect(character.rating(.strength, in: .gauru) == 10)
        #expect(character.rating(.strength, in: .hishu) == 5)
        #expect(character.armor(in: .gauru) == (2, 2))
        #expect(character.healthTrack.prefix(2) == [.lethal, .bashing])
        #expect(character.conditions.map(\.source) == [.catalog("siskur-dah"), .custom("Hoarse")])
        #expect(character.experiencesSpent == 10 && character.experiencesAvailable == 4)
        #expect(character.paidDots[TraitKey(.renown, "glory")] == [3: 3])
        #expect(character.showsUnofficialContent && character.xpMode && !character.isInCreation)
    }

    @Test func theCreationFixtureMeansWhatItSays() throws {
        let character = try JSONDecoder().decode(ForsakenCharacter.self, from: data("forsaken-v1-creation"))
        #expect(character.isInCreation && character.isPure)
        #expect(character.huntersAspect?.name == "Primal")
        #expect(character.creation?.attributePriorities == [.physical: 0, .social: 2])
        #expect(character.creation?.freeSkill == .survival)
        #expect(character.creation?.grantedRenown == [.purity])
        #expect(character.kuruthTriggerSet == nil)
        #expect(character.kuruthTrigger(.specific) == "Being chained")
    }

    /// The creation fixture was put together by hand, and its free Skill dot (Survival) and Renown dot (Purity) aren't
    /// what the Predator Kings give (Animal Ken, Brawl or Crafts; Glory). Opening a file never puts that right.
    @Test func openingASavedCreationLeavesItsGrantsAlone() throws {
        let character = try JSONDecoder().decode(ForsakenCharacter.self, from: data("forsaken-v1-creation"))
        #expect(character.freeSkillChoices == [.animalKen, .brawl, .crafts])
        #expect(character.creation?.freeSkill == .survival && character.creation?.grantedRenown == [.purity])
        #expect(character.renown(.purity) == 1 && character.renown(.glory) == 0)
        // The panel asks for the free Skill dot again, as Survival isn't one of the tribe's
        #expect(character.needsFreeSkill)
        // Looking at the sheet's numbers changes nothing in the file
        _ = character.creationReport
        _ = character.creationSteps
        #expect(try object(JSONEncoder().encode(character)) == object(data("forsaken-v1-creation")))
    }

    /// What the player does next is what moves them: placing the free Skill dot moves that dot alone, and a change
    /// of tribe or auspice, on which the sheet calls `applyCreationGrants`, brings both into line.
    @Test func editingAResumedCreationMovesItsGrants() throws {
        let character = try JSONDecoder().decode(ForsakenCharacter.self, from: data("forsaken-v1-creation"))
        let survival = try #require(character.skill(.survival)), brawl = try #require(character.skill(.brawl))
        let (survivalBefore, brawlBefore) = (survival.rating, brawl.rating)
        character.chooseFreeSkill(.brawl)
        #expect(survival.rating == max(survivalBefore - 1, 0) && brawl.rating == brawlBefore + 1)
        #expect(character.creation?.freeSkill == .brawl && !character.needsFreeSkill)
        #expect(character.creation?.grantedRenown == [.purity])

        let resumed = try JSONDecoder().decode(ForsakenCharacter.self, from: data("forsaken-v1-creation"))
        resumed.applyCreationGrants()
        // The Predator Kings' Renown is Glory; the Pure have no auspice to give another
        #expect(resumed.creation?.grantedRenown == [.glory])
        #expect(resumed.renown(.glory) == 1 && resumed.renown(.purity) == 0)
        #expect(resumed.creation?.freeSkill == nil && resumed.needsFreeSkill)
        #expect(try #require(resumed.skill(.survival)).rating == max(survivalBefore - 1, 0))
        // Once in line, calling it again changes nothing
        let settled = try object(JSONEncoder().encode(resumed))
        resumed.applyCreationGrants()
        #expect(try object(JSONEncoder().encode(resumed)) == settled)
    }

    /// The `trait` each kind of change is logged under. Attributes, Skills, Specialties and Renown are named by the
    /// trait; rows by their id; a Condition by its catalog id (or "custom") and its id; Primal Urge by itself.
    @Test func eachKindOfTraitHasItsLogKey() throws {
        let character = ForsakenCharacter()
        character.auspice = "Cahalith"
        character.xpMode = true
        character.experiences = 60
        let before = character.traitSnapshot
        try #require(character.attribute(.strength)).rating = 2
        let brawl = try #require(character.skill(.brawl))
        brawl.rating = 1
        brawl.specialties = ["Claws"]
        let merit = Merit(source: .catalog("fleet-of-foot"), rating: 1)
        character.merits.append(merit)
        character.setRenown(.glory, to: 1)
        let facet = OwnedFacet(source: .catalog("hunting-honed-senses"))
        character.facets.append(facet)
        let rite = OwnedRite(source: .catalog("sacred-hunt"))
        character.rites.append(rite)
        let moonGift = OwnedMoonGift(source: .catalog("screaming-moon"))
        character.extraMoonGifts.append(moonGift)
        character.primalUrge = 2
        character.recordChanges(since: before)
        let shaken = CharacterCondition(source: .catalog("shaken")), own = CharacterCondition(source: .custom("Hoarse"))
        character.addCondition(shaken)
        character.addCondition(own)
        character.resolveCondition(shaken)

        let keys = Set(character.changeLog.map(\.trait.storageKey))
        #expect(keys == [
            "attribute:strength", "skill:brawl", "specialty:brawl", "merit:\(merit.id.uuidString)", "renown:glory",
            "facet:\(facet.id.uuidString)", "rite:\(rite.id.uuidString)", "moonGift:\(moonGift.id.uuidString)",
            "primalUrge:primalUrge", "condition:shaken/\(shaken.id.uuidString)", "condition:custom/\(own.id.uuidString)",
        ])
        #expect(Set(character.paidDots.keys.map(\.storageKey)) == keys.filter { !$0.hasPrefix("condition:") })
    }

    /// The play fixture's history has a Condition logged under its id alone, which no version of the app wrote. It is
    /// kept as it is, and named by what the log recorded, as the Condition is no longer on the sheet.
    @Test func historyUnderOtherKeysIsKept() throws {
        let character = try JSONDecoder().decode(ForsakenCharacter.self, from: data("forsaken-v1-play"))
        let entry = try #require(character.changeLog.last)
        #expect(entry.trait.storageKey == "condition:00000000-0000-4000-8000-000000000399")
        #expect(character.condition(for: entry) == nil && entry.name == "Shaken")
        // A change after it is logged without touching it
        character.addCondition(CharacterCondition(source: .catalog("shaken")))
        let written = try JSONDecoder().decode(ForsakenCharacter.self, from: JSONEncoder().encode(character))
        #expect(written.changeLog.dropLast().last?.trait == entry.trait)
    }
}
