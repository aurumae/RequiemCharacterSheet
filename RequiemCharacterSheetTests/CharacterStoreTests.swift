//
//  CharacterStoreTests.swift
//  RequiemCharacterSheetTests
//

import Foundation
import Testing
@testable import RequiemCharacterSheet

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

    @Test func savingAgainReplacesTheSameEntry() throws {
        let store = makeStore()
        let character = Character()

        try store.save(character)
        character.name = "Renamed"
        try store.save(character)

        #expect(store.summaries.map(\.name) == ["Renamed"])
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
