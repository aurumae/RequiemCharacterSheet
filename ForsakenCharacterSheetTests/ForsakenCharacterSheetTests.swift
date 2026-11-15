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
        #expect(Catalog.bundled.books.first?.id == "cofd-core")
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
