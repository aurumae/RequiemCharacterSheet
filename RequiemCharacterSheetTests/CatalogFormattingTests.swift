//
//  CatalogFormattingTests.swift
//  RequiemCharacterSheetTests
//

import Foundation
import Testing
@testable import RequiemCharacterSheet

/// How Discipline powers are described on the detail sheet, and how many dice a character rolls.
@MainActor
struct CatalogFormattingTests {

    private func power(_ name: String, of discipline: CatalogEntryID) throws -> DisciplinePower {
        let entry = try #require(Catalog.bundled.disciplines.entry(discipline))
        return try #require(entry.powers.first { $0.name == name })
    }

    // MARK: - Costs

    @Test func costsReadInWords() throws {
        #expect(try power("Mesmerize", of: "dominate").cost.displayText == "Free")
        #expect(try power("Iron Edict", of: "dominate").cost.displayText == "1 Vitae")
        #expect(try power("Possession", of: "dominate").cost.displayText == "1 Vitae and 1 Willpower")
        #expect(try power("Oubliette", of: "obfuscate").cost.displayText == "3–9 Vitae and 1 Willpower")
        #expect(try power("Unmarked Grave", of: "protean").cost.displayText == "Varies")
        #expect(try power("Vigor", of: "vigor").cost.displayText == "Optional: 1 Vitae")
    }

    // MARK: - Dice pools

    @Test func contestedPoolsListTheResistanceSeparately() throws {
        let pool = try #require(try power("Mesmerize", of: "dominate").dicePool)

        #expect(pool.formula(disciplineName: "Dominate") == "Intelligence + Expression + Dominate")
        #expect(pool.resistedBy == "Resolve + Blood Potency")
    }

    @Test func subtractedResistanceIsPartOfThePool() throws {
        let pool = try #require(try power("Entombed Command", of: "dominate").dicePool)

        #expect(pool.formula(disciplineName: "Dominate") == "Intelligence + Subterfuge + Dominate − victim's Resolve")
        #expect(pool.resistedBy == nil)
    }

    @Test func multiWordSkillsUseTheirNames() throws {
        let pool = try #require(try power("Feral Whispers", of: "animalism").dicePool)

        #expect(pool.formula(disciplineName: "Animalism") == "Manipulation + Animal Ken + Animalism")
    }

    @Test func diceAddAttributeSkillAndDiscipline() throws {
        let character = Character()
        character.attribute(.intelligence)?.rating = 3
        character.skill(.expression)?.rating = 2
        let pool = try #require(try power("Mesmerize", of: "dominate").dicePool)

        #expect(character.dice(for: pool, disciplineRating: 2) == 7)
    }

    @Test func unskilledPoolsTakeTheCategoryPenalty() throws {
        let character = Character()
        character.attribute(.intelligence)?.rating = 3
        let pool = try #require(try power("Mesmerize", of: "dominate").dicePool)

        // Expression is a Social Skill, so −1 unskilled
        #expect(character.dice(for: pool, disciplineRating: 2) == 4)
    }

    // MARK: - Sources and clans

    @Test func citationsNameTheBookAndPage() throws {
        let dominate = try #require(Catalog.bundled.disciplines.entry("dominate"))
        let praestantia = try #require(Catalog.bundled.disciplines.entry("praestantia"))

        #expect(dominate.source.citation() == "Vampire: The Requiem Second Edition, p. 131")
        #expect(praestantia.source.citation() == "A Thousand Years of Night, p. 29")
    }

    @Test func inClanDisciplinesComeFromTheClan() {
        let character = Character()
        #expect(character.inClanDisciplines.isEmpty)

        character.clan = "Akhud"
        #expect(character.inClanDisciplines == ["celerity", "praestantia", "obfuscate"])
    }

    @Test func newCharactersStartWithoutDisciplines() {
        #expect(Character().disciplines.isEmpty)
    }

    @Test func dotsAndArrowsAreSpokenAsWords() {
        #expect("Crúac ••".spokenForVoiceOver == "Crúac 2 dots")
        #expect("●".spokenForVoiceOver == "1 dot")
        #expect("•–•••".spokenForVoiceOver == "1 dot to 3 dots")
        #expect("1 → 3".spokenForVoiceOver == "1 to 3")
        #expect("Beast's Hunger (Mystery of the Wyrm ••)".spokenForVoiceOver == "Beast's Hunger (Mystery of the Wyrm 2 dots)")
    }
}
