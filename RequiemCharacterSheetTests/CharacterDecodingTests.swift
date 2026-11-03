//
//  CharacterDecodingTests.swift
//  RequiemCharacterSheetTests
//

import Foundation
import Testing
@testable import RequiemCharacterSheet

@MainActor
struct CharacterDecodingTests {

    @Test func version1SaveLoadsWithAllValues() throws {
        let character = try decode(Self.version1Save)

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
        #expect(character.disciplines.count == 1)
        #expect(character.merits.count == 1)
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

    @Test func saveRecordsCurrentSchemaVersion() throws {
        let data = try JSONEncoder().encode(Character())
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["schemaVersion"] as? Int == Character.currentSchemaVersion)
    }

    // MARK: - Helpers

    private func decode(_ json: String) throws -> Character {
        try JSONDecoder().decode(Character.self, from: Data(json.utf8))
    }

    private func attributeRating(_ name: String, in character: Character) -> Int? {
        character.attributes.first { $0.name == name }?.rating
    }

    /// A save exactly as written by the app before schema versioning (version 1).
    /// It has no id or timestamps, and includes the since-removed healthDamage and willpowerSpent keys.
    private static let version1Save = """
    {
      "attributes": [
        {"id": "00000000-0000-0000-0000-000000000001", "name": "Intelligence", "rating": 1},
        {"id": "00000000-0000-0000-0000-000000000002", "name": "Wits", "rating": 1},
        {"id": "00000000-0000-0000-0000-000000000003", "name": "Resolve", "rating": 2},
        {"id": "00000000-0000-0000-0000-000000000004", "name": "Strength", "rating": 3},
        {"id": "00000000-0000-0000-0000-000000000005", "name": "Dexterity", "rating": 2},
        {"id": "00000000-0000-0000-0000-000000000006", "name": "Stamina", "rating": 2},
        {"id": "00000000-0000-0000-0000-000000000007", "name": "Presence", "rating": 1},
        {"id": "00000000-0000-0000-0000-000000000008", "name": "Manipulation", "rating": 1},
        {"id": "00000000-0000-0000-0000-000000000009", "name": "Composure", "rating": 3}
      ],
      "healthDamage": 0,
      "willpowerSpent": 0,
      "healthBoxes": [
        {"id": "00000000-0000-0000-0000-000000000010", "damageType": "bashing"},
        {"id": "00000000-0000-0000-0000-000000000011", "damageType": "none"},
        {"id": "00000000-0000-0000-0000-000000000012", "damageType": "none"},
        {"id": "00000000-0000-0000-0000-000000000013", "damageType": "none"},
        {"id": "00000000-0000-0000-0000-000000000014", "damageType": "none"},
        {"id": "00000000-0000-0000-0000-000000000015", "damageType": "none"},
        {"id": "00000000-0000-0000-0000-000000000016", "damageType": "none"}
      ],
      "willpowerBoxes": [
        {"id": "00000000-0000-0000-0000-000000000017", "state": "spent"},
        {"id": "00000000-0000-0000-0000-000000000018", "state": "none"},
        {"id": "00000000-0000-0000-0000-000000000019", "state": "none"},
        {"id": "00000000-0000-0000-0000-000000000020", "state": "none"},
        {"id": "00000000-0000-0000-0000-000000000021", "state": "none"}
      ],
      "skills": [
        {"id": "00000000-0000-0000-0000-000000000022", "name": "Academics", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000023", "name": "Computer", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000024", "name": "Crafts", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000025", "name": "Investigation", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000026", "name": "Medicine", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000027", "name": "Occult", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000028", "name": "Politics", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000029", "name": "Science", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000030", "name": "Athletics", "rating": 1, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000031", "name": "Brawl", "rating": 2, "specialty": "Grappling"},
        {"id": "00000000-0000-0000-0000-000000000032", "name": "Drive", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000033", "name": "Firearms", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000034", "name": "Larceny", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000035", "name": "Stealth", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000036", "name": "Survival", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000037", "name": "Weaponry", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000038", "name": "Animal Ken", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000039", "name": "Empathy", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000040", "name": "Expression", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000041", "name": "Intimidation", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000042", "name": "Persuasion", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000043", "name": "Socialize", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000044", "name": "Streetwise", "rating": 0, "specialty": ""},
        {"id": "00000000-0000-0000-0000-000000000045", "name": "Subterfuge", "rating": 0, "specialty": ""}
      ],
      "name": "Marcus Vale",
      "player": "Sam",
      "chronicle": "Dublin by Night",
      "mask": "Authoritarian",
      "dirge": "Survivor",
      "concept": "Fixer",
      "clan": "Daeva",
      "bloodline": "",
      "covenant": "Invictus",
      "bloodPotency": 2,
      "maxVitae": 11,
      "vitaePerTurn": 2,
      "currentVitae": 8,
      "humanity": 6,
      "touchstones": [
        {"id": "00000000-0000-0000-0000-000000000046", "level": 1, "text": ""},
        {"id": "00000000-0000-0000-0000-000000000047", "level": 2, "text": ""},
        {"id": "00000000-0000-0000-0000-000000000048", "level": 3, "text": ""},
        {"id": "00000000-0000-0000-0000-000000000049", "level": 4, "text": ""},
        {"id": "00000000-0000-0000-0000-000000000050", "level": 5, "text": ""},
        {"id": "00000000-0000-0000-0000-000000000051", "level": 6, "text": "His sister, Ana"},
        {"id": "00000000-0000-0000-0000-000000000052", "level": 7, "text": ""},
        {"id": "00000000-0000-0000-0000-000000000053", "level": 8, "text": ""},
        {"id": "00000000-0000-0000-0000-000000000054", "level": 9, "text": ""},
        {"id": "00000000-0000-0000-0000-000000000055", "level": 10, "text": ""}
      ],
      "disciplines": [
        {"id": "00000000-0000-0000-0000-000000000056", "name": "Vigor", "rating": 2}
      ],
      "merits": [
        {"id": "00000000-0000-0000-0000-000000000057", "name": "Defensive Combat (Brawl)", "rating": 1}
      ],
      "aspirations": [
        {"id": "00000000-0000-0000-0000-000000000058", "text": "Win a seat on the Prince's council"}
      ],
      "banes": [
        {"id": "00000000-0000-0000-0000-000000000059", "text": "Cannot cross running water"}
      ],
      "size": 5,
      "armor": 1,
      "beats": 3,
      "experiences": 4
    }
    """
}
