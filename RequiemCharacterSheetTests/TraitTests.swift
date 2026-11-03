//
//  TraitTests.swift
//  RequiemCharacterSheetTests
//

import Foundation
import Testing
@testable import RequiemCharacterSheet

/// Attributes and skills are identified by stable ids, saved by id, and grouped by category.
@MainActor
struct TraitTests {

    // MARK: - Definitions

    @Test func coreSkillListHasEightSkillsPerCategory() {
        let definitions = SkillList.vampireCore.skills.compactMap(SkillDefinition.withID)

        #expect(definitions.count == 24)
        for category in TraitCategory.allCases {
            #expect(definitions.filter { $0.category == category }.count == 8)
        }
    }

    @Test func attributesHaveThreePerCategory() {
        for category in TraitCategory.allCases {
            #expect(AttributeKind.allCases.filter { $0.category == category }.count == 3)
        }
    }

    // MARK: - Rules

    @Test func unskilledPenaltyDependsOnCategory() {
        let character = Character()

        #expect(character.skillDiceContribution(.academics) == -3)
        #expect(character.skillDiceContribution(.brawl) == -1)
        #expect(character.skillDiceContribution(.persuasion) == -1)

        character.skill(.academics)?.rating = 2
        #expect(character.skillDiceContribution(.academics) == 2)
    }

    @Test func skillsAreGroupedByCategoryInListOrder() {
        let character = Character()

        #expect(character.skills(in: .physical).map(\.skillID) == [
            .athletics, .brawl, .drive, .firearms, .larceny, .stealth, .survival, .weaponry
        ])
    }

    // MARK: - Skills outside the character's list

    @Test func skillOutsideListIsShownOnlyWithDotsOrSpecialties() {
        let character = Character()
        let archery = Skill(SkillID("archery"))
        character.skills.append(archery)

        #expect(!character.skills(in: archery.category).contains { $0 === archery })

        archery.rating = 2
        #expect(character.skills(in: archery.category).contains { $0 === archery })

        archery.rating = 0
        archery.specialties = ["Longbow"]
        #expect(character.skills(in: archery.category).contains { $0 === archery })
    }

    @Test func skillOutsideListSurvivesSaving() throws {
        let character = Character()
        character.skills.append(Skill(SkillID("archery"), rating: 3, specialties: ["Longbow"]))
        character.skill(.firearms)?.rating = 1

        let reloaded = try roundTrip(character)

        #expect(reloaded.skill(SkillID("archery"))?.rating == 3)
        #expect(reloaded.skill(SkillID("archery"))?.specialties == ["Longbow"])
        #expect(reloaded.rating(of: .firearms) == 1)
        #expect(reloaded.skills.count == 25)
    }

    // MARK: - Saving

    @Test func traitsAreSavedByID() throws {
        let character = Character()
        character.attribute(.strength)?.rating = 3
        character.skill(.animalKen)?.rating = 2
        character.skill(.animalKen)?.specialties = ["Dogs", "Horses"]

        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(character)) as? [String: Any])
        let attributes = try #require(json["attributes"] as? [[String: Any]])
        let skills = try #require(json["skills"] as? [[String: Any]])

        #expect(json["skillList"] as? String == SkillList.vampireCore.id)
        #expect(attributes.contains { $0["attribute"] as? String == "strength" && $0["rating"] as? Int == 3 })
        #expect(skills.contains {
            $0["skill"] as? String == "animal-ken" && $0["specialties"] as? [String] == ["Dogs", "Horses"]
        })
        #expect(!attributes.contains { $0["name"] != nil })
        #expect(!skills.contains { $0["name"] != nil })
    }

    @Test func multipleSpecialtiesSurviveSaving() throws {
        let character = Character()
        character.skill(.brawl)?.specialties = ["Grappling", "Boxing"]

        let reloaded = try roundTrip(character)

        #expect(reloaded.skill(.brawl)?.specialties == ["Grappling", "Boxing"])
    }

    @Test func olderSavesLoadTraitsByName() throws {
        let character = try JSONDecoder().decode(Character.self, from: Data("""
        {
          "attributes": [{"id": "\(UUID().uuidString)", "name": "Manipulation", "rating": 3}],
          "skills": [
            {"id": "\(UUID().uuidString)", "name": "Animal Ken", "rating": 2, "specialty": "Dogs"},
            {"id": "\(UUID().uuidString)", "name": "Larceny", "rating": 1, "specialty": ""}
          ]
        }
        """.utf8))

        #expect(character.rating(of: .manipulation) == 3)
        #expect(character.skill(.animalKen)?.rating == 2)
        #expect(character.skill(.animalKen)?.specialties == ["Dogs"])
        #expect(character.skill(.larceny)?.specialties == [])
        #expect(character.skills.count == 24)
    }

    @Test func unknownSkillListFallsBackToCore() throws {
        let character = try JSONDecoder().decode(Character.self, from: Data(#"{"skillList": "some-future-list"}"#.utf8))

        #expect(character.skillListID == SkillList.vampireCore.id)
        #expect(character.skills.count == 24)
    }

    private func roundTrip(_ character: Character) throws -> Character {
        try JSONDecoder().decode(Character.self, from: JSONEncoder().encode(character))
    }
}
