//
//  BloodlineTests.swift
//  RequiemCharacterSheetTests
//

import Foundation
import Testing
@testable import RequiemCharacterSheet

/// Bloodlines from the catalog, their Disciplines, and saving them.
@MainActor
struct BloodlineTests {
    private let catalog = Catalog.bundled

    @Test func theMorbusDescendFromTheMekhet() throws {
        let morbus = try #require(catalog.bloodlines.entry("morbus"))
        #expect(morbus.parentClans == ["mekhet"])
        #expect(morbus.nickname == "The Afflicted")
        #expect(morbus.disciplines == ["auspex", "celerity", "cachexy", "obfuscate"])
        #expect(morbus.bane.name == "The Unclean Curse")
        #expect(morbus.source == SourceReference(book: "dark-eras-companion", page: 95))
        for id in morbus.disciplines {
            #expect(catalog.disciplines.entry(id) != nil, "\(id)")
        }
        #expect(catalog.clans.entry("mekhet") != nil)
    }

    @Test func cachexyHasFivePowers() throws {
        let cachexy = try #require(catalog.disciplines.entry("cachexy"))
        #expect(cachexy.bloodline == "morbus")
        #expect(cachexy.powers.map(\.name) == ["Diagnose", "Contaminate", "Inflame", "Plague-Bearer", "Accelerate Disease"])
        #expect(cachexy.powers.map(\.dots) == (1...5).map { $0...$0 })
        #expect(cachexy.powers[4].cost.willpower == .fixed(1))
    }

    @Test func onlyTheMorbusCanLearnCachexy() throws {
        let cachexy = try #require(catalog.disciplines.entry("cachexy"))
        let mekhet = Character()
        mekhet.clan = "Mekhet"
        #expect(mekhet.reasonCantLearn(cachexy) == "Only the Morbus bloodline can learn Cachexy")

        mekhet.bloodline = "Morbus"
        #expect(mekhet.reasonCantLearn(cachexy) == nil)
        // Other Disciplines are open to anyone
        #expect(Character().reasonCantLearn(try #require(catalog.disciplines.entry("vigor"))) == nil)
    }

    @Test func aBloodlinesDisciplinesAreInClan() {
        let character = Character()
        character.clan = "Mekhet"
        #expect(!character.inClanDisciplines.contains("cachexy"))
        #expect(character.inClanGroupName == "Mekhet")

        character.bloodline = "Morbus"
        #expect(character.inClanDisciplines == ["auspex", "celerity", "cachexy", "obfuscate"])
        #expect(character.inClanGroupName == "Morbus")
    }

    @Test func cachexyCostsThreeExperiencesForTheMorbus() {
        let character = Character()
        character.clan = "Mekhet"
        character.bloodline = "Morbus"
        character.xpMode = true
        let before = character.traitSnapshot
        character.disciplines.append(Discipline(name: "Cachexy", rating: 1))
        character.recordChanges(since: before)
        #expect(character.experiencesSpent == 3)
    }

    @Test func bloodlinesAreSavedByID() throws {
        let character = Character()
        character.bloodline = "Morbus"
        let data = try JSONEncoder().encode(character)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect((json["bloodline"] as? [String: String]) == ["catalog": "morbus"])

        let reloaded = try JSONDecoder().decode(Character.self, from: data)
        #expect(reloaded.bloodlineEntry?.id == "morbus")
    }

    @Test func olderSavesKeepTheirTypedBloodline() throws {
        // Before version 10 the bloodline was a plain name
        let linked = try JSONDecoder().decode(Character.self, from: Data(#"{"schemaVersion": 9, "bloodline": "morbus"}"#.utf8))
        #expect(linked.bloodlineSource == .catalog("morbus"))

        let custom = try JSONDecoder().decode(Character.self, from: Data(#"{"schemaVersion": 9, "bloodline": "Khaibit"}"#.utf8))
        #expect(custom.bloodlineSource == .custom("Khaibit"))
        #expect(custom.bloodline == "Khaibit")

        let none = try JSONDecoder().decode(Character.self, from: Data(#"{"schemaVersion": 9}"#.utf8))
        #expect(none.bloodline.isEmpty)
    }
}
