//
//  EffectsTests.swift
//  RequiemCharacterSheetTests
//

import Foundation
import Testing
@testable import RequiemCharacterSheet

/// Rules effects come from catalog data, not from recognising names.
@MainActor
struct EffectsTests {

    // MARK: - Disciplines

    @Test func celerityAddsToDefense() {
        let character = Character()
        character.attribute(.dexterity)?.rating = 3
        character.attribute(.wits)?.rating = 3
        character.disciplines = [Discipline(name: "Celerity", rating: 2)]

        #expect(character.defense == 5) // 3 + Athletics 0 + Celerity 2
    }

    @Test func vigorRaisesStrengthAsATrait() {
        let character = Character()
        character.disciplines = [Discipline(name: "Vigor", rating: 3)]

        #expect(character.totalRating(of: .strength) == 4)
        #expect(character.rollRating(of: .strength) == 4)
        #expect(character.speed == 10) // 5 + Strength 4 + Dexterity 1
    }

    @Test func disciplinesWithNoDotsHaveNoEffect() {
        let character = Character()
        character.disciplines = [Discipline(name: "Resilience", rating: 0)]

        #expect(character.health == 6)
    }

    @Test func customDisciplinesHaveNoEffect() {
        let character = Character()
        character.disciplines = [Discipline(name: "Vigor-ish Homebrew", rating: 5)]

        #expect(character.totalRating(of: .strength) == 1)
    }

    @Test func effectsStack() {
        let character = Character()
        character.disciplines = [Discipline(name: "Vigor", rating: 2)]
        character.merits = [Merit(name: "Fleet of Foot", rating: 3)]

        #expect(character.speed == 12) // 5 + Strength 3 + Dexterity 1 + Fleet of Foot 3
    }

    // MARK: - Merits

    @Test func defensiveCombatUsesTheQualifierSkill() {
        let character = Character()
        character.attribute(.dexterity)?.rating = 3
        character.attribute(.wits)?.rating = 2
        character.skill(.weaponry)?.rating = 4
        character.merits = [Merit(name: "Defensive Combat (Weaponry)", rating: 1)]

        #expect(character.alternativeDefenseSkills == [.weaponry])
        #expect(character.hasDefensiveCombatWeaponry)
        #expect(!character.hasDefensiveCombatBrawl)
        #expect(character.defenseUsingWeaponry == 6)
    }

    @Test func fastReflexesAddsToInitiative() {
        let character = Character()
        character.merits = [Merit(name: "Fast Reflexes", rating: 2)]

        #expect(character.initiativeMod == 4) // Dexterity 1 + Composure 1 + 2
    }

    @Test func giantAndSmallFramedChangeSizeAndHealth() {
        let giant = Character()
        giant.merits = [Merit(name: "Giant", rating: 3)]
        #expect(giant.effectiveSize == 6)
        #expect(giant.health == 7)

        let small = Character()
        small.merits = [Merit(name: "Small-Framed", rating: 2)]
        #expect(small.effectiveSize == 4)
        #expect(small.health == 5)
    }

    // MARK: - Saves and catalogs

    @Test func customNamesSavedBeforeACatalogEntryExistedAreLinked() throws {
        // Saved as custom text before Defensive Combat was in the catalog
        let character = try JSONDecoder().decode(Character.self, from: Data("""
        {
          "schemaVersion": 5,
          "merits": [{"source": {"custom": "Defensive Combat (Brawl)"}, "rating": 1}],
          "disciplines": [{"source": {"custom": "Celerity"}, "rating": 1}]
        }
        """.utf8))

        #expect(character.merits.first?.source == .catalog("defensive-combat"))
        #expect(character.merits.first?.qualifier == "Brawl")
        #expect(character.disciplines.first?.source == .catalog("celerity"))
        #expect(character.hasDefensiveCombatBrawl)
    }

    @Test func unknownEffectsAreSkipped() throws {
        let file = try JSONDecoder().decode(CatalogFile.self, from: Data("""
        {
          "format": "requiem-catalog", "version": 1,
          "book": {"id": "test", "name": "Test"},
          "disciplines": [{
            "id": "test-discipline", "name": "Test", "kind": "scaling",
            "source": {"book": "test"}, "summary": "Test.",
            "powers": [{"id": "test-power", "name": "Test", "dots": [1, 5], "summary": "Test."}],
            "effects": [
              {"type": "somethingFromTheFuture", "amount": "rating"},
              {"type": "defense", "amount": {"fixed": 2}}
            ]
          }]
        }
        """.utf8))

        #expect(file.disciplines.first?.effects == [.defense(.fixed(2))])
    }

    @Test func bundledEffectsAreAttached() {
        let catalog = Catalog.bundled
        #expect(catalog.disciplines.entry("vigor")?.effects == [.attribute(.strength, .rating)])
        #expect(catalog.disciplines.entry("praestantia")?.effects == [.attributeRolls(.dexterity, .rating), .initiative(.rating)])
        #expect(catalog.merits.entry("defensive-combat")?.effects == [.defenseSkillFromQualifier])
    }
}
