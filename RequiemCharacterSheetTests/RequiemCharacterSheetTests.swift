//
//  RequiemCharacterSheetTests.swift
//  RequiemCharacterSheetTests
//
//  Created by Oisín McColgan on 16/09/2024.
//

import XCTest
@testable import RequiemCharacterSheet

final class RequiemCharacterSheetTests: XCTestCase {

    func testBloodPotencyCapsBaseRatingsAtFiveUntilBloodPotencySix() {
        let character = Character()

        character.bloodPotency = 1
        XCTAssertEqual(character.baseRatingCap, 5)
        XCTAssertEqual(character.attributeRatingRange, 1...5)
        XCTAssertEqual(character.skillRatingRange, 0...5)

        character.bloodPotency = 5
        XCTAssertEqual(character.baseRatingCap, 5)
        XCTAssertEqual(character.attributeRatingRange, 1...5)
        XCTAssertEqual(character.skillRatingRange, 0...5)
    }

    func testBloodPotencyAboveFiveCapsBaseRatingsAtBloodPotency() {
        let character = Character()

        character.bloodPotency = 6
        XCTAssertEqual(character.baseRatingCap, 6)
        XCTAssertEqual(character.attributeRatingRange, 1...6)
        XCTAssertEqual(character.skillRatingRange, 0...6)

        character.bloodPotency = 10
        XCTAssertEqual(character.baseRatingCap, 10)
        XCTAssertEqual(character.attributeRatingRange, 1...10)
        XCTAssertEqual(character.skillRatingRange, 0...10)
    }

    func testBaseRatingsClampWhenBloodPotencyDrops() {
        let character = Character()
        let strength = attribute(named: "Strength", in: character)
        let brawl = skill(named: "Brawl", in: character)

        character.bloodPotency = 10
        strength.rating = 10
        brawl.rating = 10
        character.bloodPotency = 5

        let expectation = expectation(description: "Blood Potency observer clamps base ratings")
        DispatchQueue.main.async {
            XCTAssertEqual(strength.rating, 5)
            XCTAssertEqual(brawl.rating, 5)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testVigorAddsToStrengthTotalAndStrengthDerivedValues() {
        let character = Character()
        let strength = attribute(named: "Strength", in: character)
        let brawl = skill(named: "Brawl", in: character)

        strength.rating = 10
        brawl.rating = 2
        character.disciplines = [Discipline(name: "Vigor", rating: 5)]

        XCTAssertEqual(character.totalAttributeRating(for: strength), 15)
        XCTAssertEqual(character.speed, 21)
        XCTAssertEqual(character.brawlDicePool, 17)
    }

    func testResilienceAddsToStaminaTotalAndHealth() {
        let character = Character()
        let stamina = attribute(named: "Stamina", in: character)

        stamina.rating = 4
        character.disciplines = [Discipline(name: "Resilience", rating: 3)]

        XCTAssertEqual(character.totalAttributeRating(for: stamina), 7)
        XCTAssertEqual(character.adjustedStamina, 7)
        XCTAssertEqual(character.health, 12)
    }

    func testPraestantiaAddsToDexterityTotalAndDexterityDerivedValues() {
        let character = Character()
        let dexterity = attribute(named: "Dexterity", in: character)
        let composure = attribute(named: "Composure", in: character)
        let firearms = skill(named: "Firearms", in: character)

        dexterity.rating = 4
        composure.rating = 3
        firearms.rating = 2
        character.disciplines = [Discipline(name: "Praestantia", rating: 5)]

        XCTAssertEqual(character.totalAttributeRating(for: dexterity), 9)
        XCTAssertEqual(character.speed, 15)
        XCTAssertEqual(character.initiativeMod, 12)
        XCTAssertEqual(character.firearmsDicePool, 11)
    }

    func testCombatDicePoolsSubtractOneForZeroRatingSkills() {
        let character = Character()
        let strength = attribute(named: "Strength", in: character)
        let dexterity = attribute(named: "Dexterity", in: character)

        strength.rating = 3
        dexterity.rating = 4

        XCTAssertEqual(character.brawlDicePool, 2)
        XCTAssertEqual(character.firearmsDicePool, 3)
        XCTAssertEqual(character.weaponryDicePool, 2)
    }

    func testCombatDicePoolsUseSkillRatingWhenSkillIsTrained() {
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

        XCTAssertEqual(character.brawlDicePool, 5)
        XCTAssertEqual(character.firearmsDicePool, 5)
        XCTAssertEqual(character.weaponryDicePool, 6)
    }

    private func attribute(named name: String, in character: Character) -> Attribute {
        guard let attribute = character.attributes.first(where: { $0.name == name }) else {
            XCTFail("Missing attribute named \(name)")
            return Attribute(name: name, rating: 1)
        }

        return attribute
    }

    private func skill(named name: String, in character: Character) -> Skill {
        guard let skill = character.skills.first(where: { $0.name == name }) else {
            XCTFail("Missing skill named \(name)")
            return Skill(name: name)
        }

        return skill
    }
}
