//
//  CharacterDecodingTests.swift
//  RequiemCharacterSheetTests
//

import Foundation
import Testing
@testable import RequiemCharacterSheet
#if SWIFT_PACKAGE
@testable import ChroniclesCore
#endif

@MainActor
struct CharacterDecodingTests {

    @Test func version1SaveLoadsWithAllValues() throws {
        let character = try JSONDecoder().decode(Character.self, from: SaveFixtures.data("v1-unversioned"))

        #expect(character.name == "Marcus Vale")
        #expect(character.player == "Sam")
        #expect(character.chronicle == "Dublin by Night")
        #expect(character.clan == "Daeva")
        #expect(character.covenant == "Invictus")

        #expect(attributeRating("Strength", in: character) == 3)
        #expect(attributeRating("Composure", in: character) == 3)
        #expect(character.attributes.map(\.name) == Character.defaultAttributes().map(\.name))

        let brawl = character.skills.first { $0.name == "Brawl" }
        #expect(brawl?.rating == 2)
        #expect(brawl?.specialties == ["Grappling"])
        #expect(character.skills.count == 24)

        #expect(character.bloodPotency == 2)
        #expect(character.maxVitae == 11)
        #expect(character.vitaePerTurn == 2)
        #expect(character.currentVitae == 8)

        #expect(character.humanity == 6)
        #expect(character.touchstones.first { $0.level == 6 }?.text == "His sister, Ana")

        #expect(character.disciplines.map(\.name) == ["Vigor"])
        #expect(character.disciplines.first?.rating == 2)
        #expect(character.hasDefensiveCombatBrawl)
        #expect(character.aspirations.map(\.text) == ["Win a seat on the Prince's council"])
        #expect(character.banes.map(\.text) == ["Cannot cross running water"])

        #expect(character.armor == 1)
        #expect(character.beats == 3)
        #expect(character.experiences == 4)

        // Health = Stamina 2 + Size 5; Willpower = Resolve 2 + Composure 3
        #expect(character.healthBoxes == [.bashing, .none, .none, .none, .none, .none, .none])
        #expect(character.willpowerBoxes == [.spent, .none, .none, .none, .none])
    }

    @Test func emptySaveLoadsAsDefaultCharacter() throws {
        let character = try decode("{}")

        #expect(character.name.isEmpty)
        #expect(character.attributes.map(\.name) == Character.defaultAttributes().map(\.name))
        #expect(character.attributes.allSatisfy { $0.rating == 1 })
        #expect(character.skills.map(\.name) == Character.defaultSkills().map(\.name))
        #expect(character.skills.allSatisfy { $0.rating == 0 })
        #expect(character.touchstones.map(\.level) == Array(1...10))
        #expect(character.humanity == 7)
        #expect(character.bloodPotency == 1)
        #expect(character.maxVitae == 10)
        #expect(character.healthBoxes.count == 6)
        #expect(character.willpowerBoxes.count == 2)
        #expect(character.disciplines.isEmpty)
        #expect(character.merits.isEmpty)
    }

    @Test func missingEntriesAreFilledInAroundSavedOnes() throws {
        // Child entries without ids also exercise the per-model defaults
        let character = try decode("""
        {
          "attributes": [{"name": "Strength", "rating": 4}],
          "skills": [{"name": "Brawl", "rating": 3}],
          "touchstones": [{"level": 3, "text": "The old parish priest"}]
        }
        """)

        #expect(character.attributes.map(\.name) == Character.defaultAttributes().map(\.name))
        #expect(attributeRating("Strength", in: character) == 4)
        #expect(attributeRating("Wits", in: character) == 1)

        #expect(character.skills.map(\.name) == Character.defaultSkills().map(\.name))
        #expect(character.skills.first { $0.name == "Brawl" }?.rating == 3)
        #expect(character.skills.first { $0.name == "Brawl" }?.specialties == [])

        #expect(character.touchstones.map(\.level) == Array(1...10))
        #expect(character.touchstones.first { $0.level == 3 }?.text == "The old parish priest")
    }

    @Test func saveRoundTripPreservesIdentityAndValues() throws {
        let original = Character()
        original.name = "Marcus Vale"
        original.attributes.first { $0.name == "Strength" }?.rating = 4

        let data = try JSONEncoder().encode(original)
        let reloaded = try JSONDecoder().decode(Character.self, from: data)

        #expect(reloaded.id == original.id)
        #expect(abs(reloaded.createdAt.timeIntervalSince(original.createdAt)) < 0.001)
        #expect(reloaded.name == "Marcus Vale")
        #expect(attributeRating("Strength", in: reloaded) == 4)
    }

    @Test func saveWithoutConditionsStaysAtVersion10() throws {
        let data = try JSONEncoder().encode(Character())
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        // So apps that can't read Conditions can still open it
        #expect(json["schemaVersion"] as? Int == 10)
        #expect(json["conditions"] == nil)
    }

    @Test func saveWithConditionsIsVersionEleven() throws {
        let character = Character()
        character.addCondition(CharacterCondition(source: .catalog("swooning"), note: "Marcus Vale"))
        let data = try JSONEncoder().encode(character)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["schemaVersion"] as? Int == 11)
        #expect((json["conditions"] as? [Any])?.count == 1)
    }

    // MARK: - Helpers

    private func decode(_ json: String) throws -> Character {
        try JSONDecoder().decode(Character.self, from: Data(json.utf8))
    }

    private func attributeRating(_ name: String, in character: Character) -> Int? {
        character.attributes.first { $0.name == name }?.rating
    }
}
