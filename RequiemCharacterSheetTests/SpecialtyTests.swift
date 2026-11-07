//
//  SpecialtyTests.swift
//  RequiemCharacterSheetTests
//

import Foundation
import Testing
@testable import RequiemCharacterSheet

/// Specialties, and Merits such as Area of Expertise that are for one of them.
@MainActor
struct SpecialtyTests {

    private func change(_ character: Character, _ edit: () -> Void) {
        let before = character.traitSnapshot
        edit()
        character.recordChanges(since: before)
    }

    private func firearms(_ character: Character) throws -> Skill {
        try #require(character.skill(.firearms))
    }

    private func athletics(_ character: Character) throws -> Skill {
        try #require(character.skill(.athletics))
    }

    private func areaOfExpertise(for specialty: String) -> Merit {
        Merit(source: .catalog("area-of-expertise"), qualifier: specialty, rating: 1)
    }

    @Test func areaOfExpertiseChoosesFromSpecialties() throws {
        let character = Character()
        let entry = try #require(Catalog.bundled.merits.entry("area-of-expertise"))
        #expect(character.qualifierOptions(for: entry) == [])

        character.addSpecialty("Rifles", to: try firearms(character))
        character.addSpecialty(" Parkour ", to: try athletics(character))

        #expect(Set(character.qualifierOptions(for: entry) ?? []) == ["Rifles", "Parkour"])
    }

    @Test func otherQualifiersAreUnchanged() throws {
        let character = Character()
        let language = try #require(Catalog.bundled.merits.entry("language"))
        let defensiveCombat = try #require(Catalog.bundled.merits.entry("defensive-combat"))

        #expect(character.qualifierOptions(for: language) == nil)
        #expect(character.qualifierOptions(for: defensiveCombat) == ["Brawl", "Weaponry"])
    }

    @Test func removingTheSpecialtyRemovesTheMerit() throws {
        let character = Character()
        let skill = try firearms(character)
        character.addSpecialty("Rifles", to: skill)
        character.merits.append(areaOfExpertise(for: "Rifles"))

        character.removeSpecialty(of: skill, at: 0)

        #expect(skill.specialties.isEmpty)
        #expect(character.merits.isEmpty)
    }

    @Test func removedMeritIsRefundedInXPMode() throws {
        let character = Character()
        character.experiences = 10
        character.xpMode = true
        let skill = try firearms(character)
        change(character) {
            character.addSpecialty("Rifles", to: skill)
            character.merits.append(areaOfExpertise(for: "Rifles"))
        }
        #expect(character.experiencesSpent == 2)

        change(character) { character.removeSpecialty(of: skill, at: 0) }

        #expect(character.experiencesSpent == 0)
    }

    @Test func renamingTheSpecialtyRenamesTheMerit() throws {
        let character = Character()
        let skill = try firearms(character)
        character.addSpecialty("Rifles", to: skill)
        let merit = areaOfExpertise(for: "Rifles")
        character.merits.append(merit)

        character.renameSpecialty(of: skill, at: 0, to: "Sniper Rifles")

        #expect(merit.qualifier == "Sniper Rifles")
        #expect(character.merits.count == 1)
    }

    @Test func renamingToNothingRemovesBoth() throws {
        let character = Character()
        let skill = try firearms(character)
        character.addSpecialty("Rifles", to: skill)
        character.merits.append(areaOfExpertise(for: "Rifles"))

        character.renameSpecialty(of: skill, at: 0, to: "  ")

        #expect(skill.specialties.isEmpty)
        #expect(character.merits.isEmpty)
    }

    @Test func meritStaysWhileAnotherSkillHasTheSpecialty() throws {
        let character = Character()
        character.addSpecialty("Running", to: try firearms(character))
        character.addSpecialty("Running", to: try athletics(character))
        character.merits.append(areaOfExpertise(for: "Running"))

        character.removeSpecialty(of: try firearms(character), at: 0)

        #expect(character.merits.count == 1)
    }

    @Test func otherMeritsAreLeftAlone() throws {
        let character = Character()
        let skill = try firearms(character)
        character.addSpecialty("French", to: skill)
        character.merits.append(Merit(source: .catalog("language"), qualifier: "French", rating: 1))

        character.removeSpecialty(of: skill, at: 0)

        #expect(character.merits.count == 1)
    }
}
