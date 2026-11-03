//
//  CharacterRulesTests.swift
//  RequiemCharacterSheetTests
//
//  Created by Oisín McColgan on 16/09/2024.
//

import Testing
@testable import RequiemCharacterSheet

/// Rating caps, Discipline bonuses, dice pools and Defense.
@MainActor
struct CharacterRulesTests {

    @Test func bloodPotencyCapsBaseRatingsAtFiveUntilBloodPotencySix() {
        let character = Character()

        character.bloodPotency = 1
        #expect(character.baseRatingCap == 5)
        #expect(character.attributeRatingRange == 1...5)
        #expect(character.skillRatingRange == 0...5)

        character.bloodPotency = 5
        #expect(character.baseRatingCap == 5)
        #expect(character.attributeRatingRange == 1...5)
        #expect(character.skillRatingRange == 0...5)
    }

    @Test func bloodPotencyAboveFiveCapsBaseRatingsAtBloodPotency() {
        let character = Character()

        character.bloodPotency = 6
        #expect(character.baseRatingCap == 6)
        #expect(character.attributeRatingRange == 1...6)
        #expect(character.skillRatingRange == 0...6)

        character.bloodPotency = 10
        #expect(character.baseRatingCap == 10)
        #expect(character.attributeRatingRange == 1...10)
        #expect(character.skillRatingRange == 0...10)
    }

    @Test func baseRatingsClampWhenBloodPotencyDrops() {
        let character = Character()
        let strength = attribute(named: "Strength", in: character)
        let brawl = skill(named: "Brawl", in: character)

        character.bloodPotency = 10
        strength.rating = 10
        brawl.rating = 10
        character.bloodPotency = 5

        // Clamped immediately, not on a later run loop pass
        #expect(strength.rating == 5)
        #expect(brawl.rating == 5)
    }

    @Test func vigorAddsToStrengthTotalAndStrengthDerivedValues() {
        let character = Character()
        let strength = attribute(named: "Strength", in: character)
        let brawl = skill(named: "Brawl", in: character)

        strength.rating = 10
        brawl.rating = 2
        character.disciplines = [Discipline(name: "Vigor", rating: 5)]

        #expect(character.totalAttributeRating(for: strength) == 15)
        #expect(character.speed == 21)
        #expect(character.brawlDicePool == 17)
    }

    @Test func resilienceAddsToStaminaTotalAndHealth() {
        let character = Character()
        let stamina = attribute(named: "Stamina", in: character)

        stamina.rating = 4
        character.disciplines = [Discipline(name: "Resilience", rating: 3)]

        #expect(character.totalAttributeRating(for: stamina) == 7)
        #expect(character.adjustedStamina == 7)
        #expect(character.health == 12)
    }

    /// A Thousand Years of Night p. 29: Praestantia adds to Dexterity for rolls and to Initiative,
    /// but not to traits derived from Dexterity such as Speed and Defense.
    @Test func praestantiaAddsToDexterityRollsAndInitiativeOnly() {
        let character = Character()
        let dexterity = attribute(named: "Dexterity", in: character)
        let composure = attribute(named: "Composure", in: character)
        let wits = attribute(named: "Wits", in: character)
        let firearms = skill(named: "Firearms", in: character)

        dexterity.rating = 4
        composure.rating = 3
        wits.rating = 5
        firearms.rating = 2
        character.disciplines = [Discipline(name: "Praestantia", rating: 5)]

        #expect(character.totalAttributeRating(for: dexterity) == 9)
        #expect(character.firearmsDicePool == 11)
        #expect(character.initiativeMod == 12)
        // Speed: 5 + Strength 1 + Dexterity 4, without Praestantia
        #expect(character.speed == 10)
        // Defense: lower of Dexterity 4 and Wits 5, without Praestantia
        #expect(character.defense == 4)
    }

    @Test func combatDicePoolsSubtractOneForZeroRatingSkills() {
        let character = Character()
        let strength = attribute(named: "Strength", in: character)
        let dexterity = attribute(named: "Dexterity", in: character)

        strength.rating = 3
        dexterity.rating = 4

        #expect(character.brawlDicePool == 2)
        #expect(character.firearmsDicePool == 3)
        #expect(character.weaponryDicePool == 2)
    }

    @Test func combatDicePoolsUseSkillRatingWhenSkillIsTrained() {
        let character = Character()
        let strength = attribute(named: "Strength", in: character)
        let dexterity = attribute(named: "Dexterity", in: character)
        let brawl = skill(named: "Brawl", in: character)
        let firearms = skill(named: "Firearms", in: character)
        let weaponry = skill(named: "Weaponry", in: character)

        strength.rating = 3
        dexterity.rating = 4
        brawl.rating = 2
        firearms.rating = 1
        weaponry.rating = 3

        #expect(character.brawlDicePool == 5)
        #expect(character.firearmsDicePool == 5)
        #expect(character.weaponryDicePool == 6)
    }

    @Test func defensiveCombatBrawlAddsAlternativeDefense() {
        let character = Character()
        let dexterity = attribute(named: "Dexterity", in: character)
        let wits = attribute(named: "Wits", in: character)
        let athletics = skill(named: "Athletics", in: character)
        let brawl = skill(named: "Brawl", in: character)

        dexterity.rating = 4
        wits.rating = 3
        athletics.rating = 1
        brawl.rating = 4
        character.merits = [Merit(name: "Defensive Combat (Brawl)", rating: 1)]

        #expect(character.hasDefensiveCombatBrawl)
        #expect(!character.hasDefensiveCombatWeaponry)
        #expect(character.defense == 4)
        #expect(character.defenseUsingBrawl == 7)
    }

    @Test func defensiveCombatWeaponryAddsAlternativeDefense() {
        let character = Character()
        let dexterity = attribute(named: "Dexterity", in: character)
        let wits = attribute(named: "Wits", in: character)
        let athletics = skill(named: "Athletics", in: character)
        let weaponry = skill(named: "Weaponry", in: character)

        dexterity.rating = 4
        wits.rating = 3
        athletics.rating = 1
        weaponry.rating = 5
        character.merits = [Merit(name: "Defensive Combat (Weaponry)", rating: 1)]

        #expect(!character.hasDefensiveCombatBrawl)
        #expect(character.hasDefensiveCombatWeaponry)
        #expect(character.defense == 4)
        #expect(character.defenseUsingWeaponry == 8)
    }

    private func attribute(named name: String, in character: Character) -> Attribute {
        guard let attribute = character.attributes.first(where: { $0.name == name }) else {
            Issue.record("Missing attribute named \(name)")
            return Attribute(AttributeKind(name: name) ?? .intelligence)
        }

        return attribute
    }

    private func skill(named name: String, in character: Character) -> Skill {
        guard let skill = character.skills.first(where: { $0.name == name }) else {
            Issue.record("Missing skill named \(name)")
            return Skill(SkillID(name.lowercased()))
        }

        return skill
    }
}
