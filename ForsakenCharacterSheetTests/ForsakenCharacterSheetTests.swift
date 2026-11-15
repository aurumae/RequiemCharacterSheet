//
//  ForsakenCharacterSheetTests.swift
//  ForsakenCharacterSheetTests
//

import Foundation
import Testing
@testable import ForsakenCharacterSheet

@MainActor
struct ForsakenSaveTests {
    private func makeStore() -> CharacterFileStore<ForsakenCharacter> {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        return CharacterFileStore(directory: directory, legacyDefaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    @Test func savesSayTheyAreForsaken() throws {
        let character = ForsakenCharacter()
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(character)) as? [String: Any])
        #expect(object["game"] as? String == "forsaken")
        #expect(object["schemaVersion"] as? Int == ForsakenCharacter.currentSchemaVersion)
    }

    @Test func characterLoadsBackAsSaved() throws {
        let store = makeStore()
        let character = ForsakenCharacter()
        character.name = "Mara Greyfoot"
        character.blood = "The Guardian"
        character.bone = "The Survivor"
        character.auspice = "Irraka"
        character.tribe = "Hunters in Darkness"
        character.attributes.first { $0.kind == .wits }?.rating = 3
        character.skills.first { $0.skillID == .investigation }?.specialties = ["Tracking"]
        character.merits.append(Merit(source: .catalog("fast-reflexes"), rating: 2))
        try store.save(character)

        let loaded = try store.load(character.id)
        #expect(loaded.name == "Mara Greyfoot")
        #expect(loaded.blood == "The Guardian" && loaded.bone == "The Survivor")
        #expect(loaded.rating(of: .wits) == 3)
        #expect(loaded.skill(.investigation)?.specialties == ["Tracking"])
        #expect(loaded.merits.map(\.name) == ["Fast Reflexes"])
        #expect(store.summaries.first?.listDetails == ["Irraka", "Hunters in Darkness"])
    }

    @Test func requiemCharactersAreRefused() throws {
        let store = makeStore()
        // Requiem's files have no game key
        let requiem = Data(#"{"schemaVersion": 12, "name": "Marcus Vale", "clan": "Ventrue"}"#.utf8)
        #expect(throws: CharacterStoreError.otherGame("requiem")) { try store.prepareImport(of: requiem) }
    }

    @Test func newerFormatsAreRefused() throws {
        let store = makeStore()
        let data = Data(#"{"game": "forsaken", "schemaVersion": 99, "name": "Mara Greyfoot"}"#.utf8)
        #expect(throws: CharacterStoreError.newerFormat(version: 99)) { try store.prepareImport(of: data) }
    }
}

@MainActor
struct ForsakenRulesTests {
    @Test func catalogHasTheChroniclesCoreMeritsAndConditions() {
        #expect(Catalog.bundled.merits.entry("fast-reflexes") != nil)
        #expect(!Catalog.bundled.conditions.all.isEmpty)
        #expect(Catalog.bundled.books.map(\.id) == ["wtf2e-core", "cofd-core"])
    }

    @Test func werewolfCoreBookIsLoaded() {
        let catalog = Catalog.bundled
        #expect(catalog.auspices.all.count == 5)
        #expect(catalog.tribes.all.count == 9)
        #expect(catalog.tribes.all.filter { $0.kind == .pure }.count == 3)
        #expect(catalog.lodges.all.count == 8)
        #expect(catalog.archetypes.all.filter { $0.kind == .blood }.count == 6)
        #expect(catalog.archetypes.all.filter { $0.kind == .bone }.count == 6)
        #expect(catalog.gifts.all.count == 23)
        #expect(catalog.gifts.all.flatMap(\.facets).count == 115)
        #expect(catalog.rites.all.count == 23)
        #expect(catalog.fetishes.all.count == 18)
        // The human Merits the Werewolf book reprints, e.g. Language, are offered
        #expect(catalog.merits.entry("language")?.source.book == "wtf2e-core")
        #expect(catalog.merits.all.filter { $0.category == .werewolf }.count == 24)
    }

    @Test func catalogReferencesResolve() {
        let catalog = Catalog.bundled
        for auspice in catalog.auspices.all {
            #expect(catalog.gifts.entry(auspice.moonGift)?.kind == .moon)
            #expect(auspice.giftAffinities.allSatisfy { catalog.gifts.entry($0)?.kind == .shadow })
            #expect(catalog.conditions.entry(auspice.huntersAspect.condition) != nil)
        }
        for tribe in catalog.tribes.all {
            #expect(tribe.giftAffinities.allSatisfy { catalog.gifts.entry($0)?.kind == .shadow })
            #expect((tribe.renown == nil) == (tribe.kind != .forsaken))
        }
        for gift in catalog.gifts.all {
            // Moon Gifts go by dots; Shadow and Wolf Gifts have one Facet per Renown
            if gift.kind == .moon {
                #expect(gift.facets.compactMap(\.dots) == [1, 2, 3, 4, 5])
            } else {
                #expect(Set(gift.facets.compactMap(\.renown)) == Set(Renown.allCases))
            }
        }
        let knownKinds: Set<Prerequisite.Kind> = [.attribute, .skill, .merit, .willpower, .other, .renown, .primalUrge,
                                                  .harmony, .tribe, .notTribe, .auspice]
        for merit in catalog.merits.all {
            for prerequisite in merit.prerequisites + merit.prerequisitesAnyOf.flatMap({ $0 }) {
                #expect(knownKinds.contains(prerequisite.kind), "\(merit.id): \(prerequisite.kind.rawValue)")
                if prerequisite.kind == .merit {
                    #expect(catalog.merits.entry(prerequisite.id ?? "") != nil)
                }
                if prerequisite.kind == .tribe || prerequisite.kind == .notTribe {
                    #expect(catalog.tribes.entry(prerequisite.id ?? "") != nil)
                }
            }
        }
    }

    @Test func healthIsStaminaPlusSize() {
        let character = ForsakenCharacter()
        character.attributes.first { $0.kind == .stamina }?.rating = 3
        #expect(character.health == 8)
        #expect(character.healthBoxes.count == 8)
    }

    @Test func xpModeChargesAndRefunds() {
        let character = ForsakenCharacter()
        character.xpMode = true
        character.experiences = 10
        let strength = character.attributes.first { $0.kind == .strength }!

        var before = character.traitSnapshot
        strength.rating = 3
        character.recordChanges(since: before)
        #expect(character.experiencesSpent == 8)
        #expect(character.experiencesAvailable == 2)

        before = character.traitSnapshot
        strength.rating = 2
        character.recordChanges(since: before)
        #expect(character.experiencesSpent == 4)
        #expect(character.changeLog.map(\.costText) == ["Spent 8", "Refunded 4"])
    }

    @Test func resolvingAConditionGivesABeat() throws {
        let character = ForsakenCharacter()
        let entry = try #require(Catalog.bundled.conditions.all.first { $0.beatOnResolve })
        let condition = CharacterCondition(source: .catalog(entry.id))
        character.addCondition(condition)
        character.resolveCondition(condition)
        #expect(character.conditions.isEmpty)
        #expect(character.beats == 1)
    }
}
