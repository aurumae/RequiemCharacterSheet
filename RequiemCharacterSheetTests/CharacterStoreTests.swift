//
//  CharacterStoreTests.swift
//  RequiemCharacterSheetTests
//

import Foundation
import Testing
@testable import RequiemCharacterSheet
#if SWIFT_PACKAGE
@testable import ChroniclesCore
#endif

/// Each test gets its own temporary directory and UserDefaults suite, removed afterwards.
@MainActor
final class CharacterStoreTests {
    private let directory: URL
    private let suiteName: String
    private let defaults: UserDefaults

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "CharacterStoreTests-\(UUID().uuidString)")
        suiteName = "CharacterStoreTests-\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    private func makeStore() -> CharacterStore {
        CharacterStore(directory: directory, legacyDefaults: defaults)
    }

    // MARK: - Saving and loading

    @Test func emptyStoreHasNoCharacters() {
        #expect(makeStore().summaries.isEmpty)
    }

    @Test func savedCharacterLoadsBack() throws {
        let store = makeStore()
        let character = Character()
        character.name = "Marcus Vale"
        character.attributes.first { $0.name == "Strength" }?.rating = 4

        try store.save(character)
        let loaded = try store.load(character.id)

        #expect(loaded.id == character.id)
        #expect(loaded.name == "Marcus Vale")
        #expect(loaded.attributes.first { $0.name == "Strength" }?.rating == 4)
    }

    @Test func saveUpdatesModifiedDate() throws {
        let store = makeStore()
        let character = Character()
        let saveDate = Date(timeIntervalSinceReferenceDate: 1_000_000)

        try store.save(character, at: saveDate)

        #expect(character.modifiedAt == saveDate)
        #expect(store.summaries.first?.modifiedAt == saveDate)
    }

    @Test func summariesListCharactersNewestFirst() throws {
        let store = makeStore()
        let older = Character()
        older.name = "Older"
        older.clan = "Daeva"
        older.covenant = "Invictus"
        let newer = Character()
        newer.name = "Newer"

        try store.save(older, at: Date(timeIntervalSinceReferenceDate: 1_000))
        try store.save(newer, at: Date(timeIntervalSinceReferenceDate: 2_000))

        #expect(store.summaries.map(\.name) == ["Newer", "Older"])
        #expect(store.summaries.last == CharacterSummary(
            id: older.id,
            name: "Older",
            clan: "Daeva",
            covenant: "Invictus",
            modifiedAt: Date(timeIntervalSinceReferenceDate: 1_000),
            isReadable: true
        ))
    }

    @Test func summaryShowsTheBloodlineAfterTheClan() {
        func lineage(_ clan: String, _ bloodline: String) -> String {
            CharacterSummary(id: UUID(), name: "", clan: clan, bloodline: bloodline, covenant: "", modifiedAt: nil, isReadable: true).lineage
        }
        #expect(lineage("Ventrue", "Bron") == "Ventrue (Bron)")
        #expect(lineage("Ventrue", "") == "Ventrue")
        #expect(lineage("", "Bron") == "Bron")
    }

    @Test func savingAgainReplacesTheSameEntry() throws {
        let store = makeStore()
        let character = Character()

        try store.save(character)
        character.name = "Renamed"
        try store.save(character)

        #expect(store.summaries.map(\.name) == ["Renamed"])
    }

    @Test func openingAndSavingWithoutChangesKeepsEditedDate() throws {
        let store = makeStore()
        let firstSave = Date(timeIntervalSinceReferenceDate: 1_000)
        let character = Character()
        character.name = "Marcus Vale"
        try store.save(character, at: firstSave)

        let reopened = try store.load(character.id)
        let didWrite = try store.save(reopened, at: Date(timeIntervalSinceReferenceDate: 2_000))

        #expect(!didWrite)
        #expect(reopened.modifiedAt == firstSave)
        #expect(store.summaries.first?.modifiedAt == firstSave)
    }

    @Test func olderFormatFileIsNotTreatedAsEdited() throws {
        // Turn a current save into a version 2 file: boxes saved as objects with ids,
        // plus the stored Vitae values
        let character = Character()
        character.name = "Marcus Vale"
        let firstSave = Date(timeIntervalSinceReferenceDate: 1_000)
        character.modifiedAt = firstSave
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(character)) as? [String: Any])
        json["schemaVersion"] = 2
        json["healthTrack"] = nil
        json["willpowerTrack"] = nil
        json["maxVitae"] = 10
        json["vitaePerTurn"] = 1
        json["healthBoxes"] = ["lethal", "none", "none", "none", "none", "none"].map { ["id": UUID().uuidString, "damageType": $0] }
        json["willpowerBoxes"] = ["spent", "none"].map { ["id": UUID().uuidString, "state": $0] }

        let id = character.id
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: json).write(to: directory.appending(path: "\(id.uuidString).json"))
        let store = makeStore()

        let reopened = try store.load(id)
        let didWrite = try store.save(reopened, at: Date(timeIntervalSinceReferenceDate: 2_000))

        #expect(reopened.healthBoxes.prefix(2) == [.lethal, .none])
        #expect(reopened.willpowerBoxes.first == .spent)
        #expect(!didWrite)
        #expect(store.summaries.first?.modifiedAt == firstSave)
    }

    @Test func changedCharacterGetsNewEditedDate() throws {
        let store = makeStore()
        let character = Character()
        try store.save(character, at: Date(timeIntervalSinceReferenceDate: 1_000))

        let reopened = try store.load(character.id)
        reopened.name = "Marcus Vale"
        let secondSave = Date(timeIntervalSinceReferenceDate: 2_000)
        let didWrite = try store.save(reopened, at: secondSave)

        #expect(didWrite)
        #expect(store.summaries.first?.modifiedAt == secondSave)
        #expect(store.summaries.first?.name == "Marcus Vale")
    }

    @Test func damageMarkCountsAsChange() throws {
        let store = makeStore()
        let character = Character()
        try store.save(character, at: Date(timeIntervalSinceReferenceDate: 1_000))

        let reopened = try store.load(character.id)
        reopened.setHealthBox(at: 0, to: .lethal)
        let didWrite = try store.save(reopened, at: Date(timeIntervalSinceReferenceDate: 2_000))

        #expect(didWrite)
        #expect(try store.load(character.id).healthBoxes.first == .lethal)
    }

    @Test func newStoreSeesPreviouslySavedCharacters() throws {
        let character = Character()
        character.name = "Persisted"
        try makeStore().save(character)

        #expect(makeStore().summaries.map(\.name) == ["Persisted"])
    }

    @Test func deleteRemovesCharacter() throws {
        let store = makeStore()
        let kept = Character()
        let deleted = Character()
        try store.save(kept)
        try store.save(deleted)

        try store.delete(deleted.id)

        #expect(store.summaries.map(\.id) == [kept.id])
        #expect(throws: (any Error).self) { try store.load(deleted.id) }
    }

    // MARK: - Files that can't be opened

    @Test func unreadableFileIsListedLastAndLeftUntouched() throws {
        let store = makeStore()
        let readable = Character()
        try store.save(readable)

        let brokenID = UUID()
        let brokenURL = directory.appending(path: "\(brokenID.uuidString).json")
        let brokenData = Data("not a character".utf8)
        try brokenData.write(to: brokenURL)
        store.reload()

        #expect(store.summaries.map(\.id) == [readable.id, brokenID])
        #expect(store.summaries.last?.isReadable == false)
        #expect(throws: (any Error).self) { try store.load(brokenID) }
        #expect(try Data(contentsOf: brokenURL) == brokenData)
    }

    @Test func fileFromNewerVersionIsNotOpened() throws {
        let id = UUID()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"schemaVersion": 99, "name": "From the future"}"#.utf8)
            .write(to: directory.appending(path: "\(id.uuidString).json"))

        let store = makeStore()

        #expect(store.summaries.first?.isReadable == false)
        #expect(throws: CharacterStoreError.newerFormat(version: 99)) { try store.load(id) }
    }

    @Test func unrelatedFilesAreIgnored() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: directory.appending(path: "notes.json"))
        try Data("{}".utf8).write(to: directory.appending(path: "\(UUID().uuidString).txt"))

        #expect(makeStore().summaries.isEmpty)
    }

    // MARK: - Export and import

    private func savedFile(_ id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).json")
    }

    @Test func exportIsTheSavedFile() throws {
        let store = makeStore()
        let character = Character()
        character.name = "Marcus Vale"
        try store.save(character)

        #expect(try store.exportData(for: character.id) == Data(contentsOf: savedFile(character.id)))
    }

    @Test func importedCharacterIsStoredUnchanged() throws {
        let source = Character()
        source.name = "Marcus Vale"
        source.modifiedAt = Date(timeIntervalSinceReferenceDate: 1000)
        let data = try JSONEncoder().encode(source)
        let store = makeStore()

        let pending = try store.prepareImport(of: data)
        #expect(pending.existing == nil)
        let id = try store.importCharacter(pending)

        #expect(id == source.id)
        #expect(try Data(contentsOf: savedFile(id)) == data)
        #expect(store.summaries.map(\.name) == ["Marcus Vale"])
        #expect(store.summaries.first?.modifiedAt == source.modifiedAt)
    }

    @Test func importWithLowercaseIDIsStoredUnchanged() throws {
        // Another platform may write the same UUID in lowercase
        let id = UUID()
        let data = Data(#"{"schemaVersion": 10, "id": "\#(id.uuidString.lowercased())", "name": "Marcus Vale"}"#.utf8)
        let store = makeStore()

        try store.importCharacter(store.prepareImport(of: data))

        #expect(try Data(contentsOf: savedFile(id)) == data)
    }

    @Test func importingACharacterAlreadyHereFindsIt() throws {
        let store = makeStore()
        let character = Character()
        character.name = "Marcus Vale"
        try store.save(character)

        let pending = try store.prepareImport(of: store.exportData(for: character.id))

        #expect(pending.existing?.id == character.id)
        #expect(pending.isAlreadyHere)
    }

    @Test func changedCopyIsNotAlreadyHere() throws {
        let store = makeStore()
        let character = Character()
        try store.save(character)
        character.name = "Marcus Vale"

        let pending = try store.prepareImport(of: JSONEncoder().encode(character))

        #expect(pending.existing?.id == character.id)
        #expect(!pending.isAlreadyHere)
    }

    @Test func replacingOverwritesTheCharacterHere() throws {
        let store = makeStore()
        let character = Character()
        character.name = "Marcus Vale"
        try store.save(character)
        character.name = "Marcus Vale, Elder"
        let newer = try JSONEncoder().encode(character)

        try store.importCharacter(store.prepareImport(of: newer))

        #expect(store.summaries.count == 1)
        #expect(try store.load(character.id).name == "Marcus Vale, Elder")
    }

    @Test func keepingBothAddsACopyWithANewIdentity() throws {
        let store = makeStore()
        let character = Character()
        character.name = "Marcus Vale"
        character.attributes.first { $0.name == "Strength" }?.rating = 4
        try store.save(character)

        let copyID = try store.importCharacter(store.prepareImport(of: store.exportData(for: character.id)), keepingBoth: true)

        #expect(copyID != character.id)
        #expect(Set(store.summaries.map(\.id)) == [character.id, copyID])
        let copy = try store.load(copyID)
        #expect(copy.name == "Marcus Vale (1)")
        #expect(copy.attributes.first { $0.name == "Strength" }?.rating == 4)
        #expect(copy.modifiedAt == character.modifiedAt)
    }

    @Test func copiesAreNumberedLikeFiles() throws {
        let store = makeStore()
        let character = Character()
        character.name = "Lucius Avelorn"
        try store.save(character)
        let data = try store.exportData(for: character.id)

        let first = try store.importCharacter(store.prepareImport(of: data), keepingBoth: true)
        let second = try store.importCharacter(store.prepareImport(of: data), keepingBoth: true)

        #expect(try store.load(first).name == "Lucius Avelorn (1)")
        #expect(try store.load(second).name == "Lucius Avelorn (2)")
    }

    @Test func copyNameUsesTheFirstFreeNumber() {
        #expect(CharacterStore.copyName(for: "Lucius", taken: ["Lucius"]) == "Lucius (1)")
        #expect(CharacterStore.copyName(for: "Lucius", taken: ["Lucius", "Lucius (2)"]) == "Lucius (1)")
        #expect(CharacterStore.copyName(for: "Lucius (1)", taken: ["Lucius", "Lucius (1)"]) == "Lucius (2)")
        #expect(CharacterStore.copyName(for: "", taken: [""]) == "Unnamed Character (1)")
        #expect(CharacterStore.copyName(for: "Year (1999) Lucius", taken: []) == "Year (1999) Lucius (1)")
    }

    @Test func importFromBeforeCharactersHadIDsKeepsItsNewID() throws {
        let store = makeStore()

        let id = try store.importCharacter(store.prepareImport(of: Data(#"{"name": "Marcus Vale"}"#.utf8)))

        #expect(store.summaries.map(\.id) == [id])
        #expect(try store.load(id).name == "Marcus Vale")
    }

    @Test func importFromNewerVersionIsRefused() throws {
        let store = makeStore()
        let data = Data(#"{"schemaVersion": 99, "id": "\#(UUID().uuidString)", "name": "Marcus Vale"}"#.utf8)

        #expect(throws: CharacterStoreError.newerFormat(version: 99)) { try store.prepareImport(of: data) }
        #expect(store.summaries.isEmpty)
    }

    @Test func importOfSomethingElseIsRefused() throws {
        let store = makeStore()

        #expect(throws: CharacterStoreError.unreadable) { try store.prepareImport(of: Data("not a character".utf8)) }
        #expect(throws: CharacterStoreError.unreadable) { try store.prepareImport(of: Data("[1, 2]".utf8)) }
        // Other JSON decodes as a blank character, as every field has a default
        #expect(throws: CharacterStoreError.unreadable) { try store.prepareImport(of: Data(#"{"v1-unversioned": {}}"#.utf8)) }
        #expect(store.summaries.isEmpty)
    }

    // MARK: - Moving the single-character save

    @Test func legacySaveIsMovedIntoStore() throws {
        // Version 1 saves have no id or timestamps
        defaults.set(Data(#"{"name": "Marcus Vale", "clan": "Daeva"}"#.utf8), forKey: CharacterStore.legacySaveKey)
        let store = makeStore()

        try store.migrateLegacySaveIfNeeded()

        #expect(store.summaries.map(\.name) == ["Marcus Vale"])
        #expect(store.summaries.first?.clan == "Daeva")
        #expect(defaults.data(forKey: CharacterStore.legacySaveKey) == nil)
    }

    @Test func migrationIsHarmlessWhenRunAgain() throws {
        defaults.set(Data(#"{"name": "Marcus Vale"}"#.utf8), forKey: CharacterStore.legacySaveKey)
        let store = makeStore()

        try store.migrateLegacySaveIfNeeded()
        try store.migrateLegacySaveIfNeeded()

        #expect(store.summaries.count == 1)
    }

    @Test func unreadableLegacySaveIsKeptForLater() throws {
        let legacyData = Data("not a character".utf8)
        defaults.set(legacyData, forKey: CharacterStore.legacySaveKey)
        let store = makeStore()

        #expect(throws: (any Error).self) { try store.migrateLegacySaveIfNeeded() }

        #expect(store.summaries.isEmpty)
        #expect(defaults.data(forKey: CharacterStore.legacySaveKey) == legacyData)
    }

    @Test func migrationWithoutLegacySaveDoesNothing() throws {
        let store = makeStore()

        try store.migrateLegacySaveIfNeeded()

        #expect(store.summaries.isEmpty)
    }
}
