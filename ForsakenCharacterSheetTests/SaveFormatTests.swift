//
//  SaveFormatTests.swift
//  ForsakenCharacterSheetTests
//
//  Pins the save format (docs/forsaken-save-format.md) with two saved characters in Fixtures/.
//

import Foundation
import Testing
@testable import ForsakenCharacterSheet

/// Finds the test bundle, where the fixtures are.
private final class FixtureBundle {}

@MainActor
struct SaveFormatTests {
    /// A Cahalith well into play, and a Predator King part-way through guided creation. Between them they use every
    /// key the format has.
    private nonisolated static let fixtures = ["forsaken-v1-play", "forsaken-v1-creation"]

    private func data(_ name: String) throws -> Data {
        let url = try #require(Bundle(for: FixtureBundle.self).url(forResource: name, withExtension: "json"), "\(name)")
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
}
