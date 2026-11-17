//
//  CharacterFileStore.swift
//  ChroniclesCore
//
//  Saves each game's characters as JSON files, one per character. Each game's character type says how it's
//  summarised in the list and which game its files belong to.
//

import Foundation
import Observation

/// A character type that can be saved to and read from the store.
package protocol StoredCharacter: AnyObject, Codable {
    associatedtype Summary: StoredCharacterSummary

    var id: UUID { get }
    var name: String { get }
    var modifiedAt: Date { get set }

    /// The newest save format this version of the app reads and writes.
    static var currentSchemaVersion: Int { get }
    /// The game written in the file's `game` key, e.g. "forsaken". Files without one are Requiem's, the first game.
    static var game: String { get }

    /// How the character is listed.
    func summary() -> Summary
    /// The listing for a file that couldn't be read.
    static func unreadableSummary(id: UUID) -> Summary
}

/// A saved character as shown in the character list.
package protocol StoredCharacterSummary: Identifiable, Equatable where ID == UUID {
    var name: String { get }
    /// `nil` when the file couldn't be read.
    var modifiedAt: Date? { get }
    /// False when the file couldn't be read. The file is left untouched so nothing is lost.
    var isReadable: Bool { get }
    /// Short facts shown under the name, e.g. clan and covenant. Empty ones are left out.
    var listDetails: [String] { get }
}

package enum CharacterStoreError: Error, Equatable {
    /// The file was saved by a newer version of the app. Opening it here could drop fields this version doesn't know about.
    case newerFormat(version: Int)
    /// The file isn't a character file, or it's damaged.
    case unreadable
    /// The file is a character from another game's app, e.g. a Forsaken character opened in Requiem.
    case otherGame(String)
}

extension CharacterStoreError: LocalizedError {
    package var errorDescription: String? {
        switch self {
        case .newerFormat:
            "This character was saved by a newer version of the app. Update the app to open it."
        case .unreadable:
            "The file isn't a character file, or it's damaged."
        case .otherGame:
            "This character is from another game. Open it in that game's app."
        }
    }
}

/// A character file that has been read and checked, waiting to be added to the store.
package struct PendingImport<C: StoredCharacter> {
    /// The file exactly as it was received.
    package let data: Data
    package let character: C
    /// The character on this device with the same identity, if there is one.
    package let existing: C.Summary?
    /// The character on this device is the same as the file, apart from perhaps its edited date.
    package let isAlreadyHere: Bool
}

/// Saves each character as its own JSON file in the app's private Application Support directory.
@MainActor
@Observable
package final class CharacterFileStore<C: StoredCharacter> {
    /// UserDefaults key used by versions that saved a single character.
    package static var legacySaveKey: String { "SavedCharacter" }

    package nonisolated static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Characters", isDirectory: true)
    }

    /// Newest first; unreadable files are listed last.
    package private(set) var summaries: [C.Summary] = []

    private let directory: URL
    private let legacyDefaults: UserDefaults

    package init(directory: URL = defaultDirectory, legacyDefaults: UserDefaults = .standard) {
        self.directory = directory
        self.legacyDefaults = legacyDefaults
        reload()
    }

    /// Re-reads the list of saved characters from disk.
    package func reload() {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        summaries = urls.compactMap { url -> C.Summary? in
            // Ignore anything that isn't one of our "<id>.json" files
            guard url.pathExtension == "json",
                  let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else {
                return nil
            }
            guard let data = try? Data(contentsOf: url),
                  let character = try? decodeCharacter(from: data) else {
                return C.unreadableSummary(id: id)
            }
            return character.summary()
        }
        .sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
    }

    package func load(_ id: UUID) throws -> C {
        let data = try Data(contentsOf: fileURL(for: id))
        return try decodeCharacter(from: data)
    }

    /// Writes the character to disk and stamps it as edited at `date`, unless nothing has changed
    /// since it was last saved, in which case the file and its edited date are left as they are.
    /// Returns whether the file was written.
    @discardableResult
    package func save(_ character: C, at date: Date = .now) throws -> Bool {
        let url = fileURL(for: character.id)
        // The saved file is loaded and re-encoded before comparing, so a file in an older format
        // isn't mistaken for a change just because the format differs.
        if let savedData = try? Data(contentsOf: url),
           let savedCharacter = try? decodeCharacter(from: savedData),
           let savedContent = try? Self.comparableContent(of: savedCharacter),
           let currentContent = try? Self.comparableContent(of: character),
           savedContent == currentContent {
            return false
        }

        character.modifiedAt = date
        let data = try JSONEncoder().encode(character)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        reload()
        return true
    }

    package func delete(_ id: UUID) throws {
        try FileManager.default.removeItem(at: fileURL(for: id))
        reload()
    }

    /// Moves the single character saved by earlier versions into the store.
    /// The old save is only removed once the new file has been written, so a failure leaves it in place to retry.
    package func migrateLegacySaveIfNeeded() throws {
        guard let data = legacyDefaults.data(forKey: Self.legacySaveKey) else { return }
        let character = try decodeCharacter(from: data)
        try save(character, at: character.modifiedAt)
        legacyDefaults.removeObject(forKey: Self.legacySaveKey)
    }

    // MARK: - Export and import

    /// The character's saved file, exactly as stored, for sharing with another device.
    package func exportData(for id: UUID) throws -> Data {
        try Data(contentsOf: exportURL(for: id))
    }

    /// Where the character's saved file is, for sharing it without reading it first.
    package func exportURL(for id: UUID) -> URL {
        fileURL(for: id)
    }

    /// Reads a received character file and checks it can be opened, without changing the store.
    package func prepareImport(of data: Data) throws -> PendingImport<C> {
        let character: C
        do {
            character = try decodeCharacter(from: data)
        } catch let error as CharacterStoreError {
            throw error
        } catch {
            throw CharacterStoreError.unreadable
        }
        // Missing fields fall back to defaults, so any JSON object would decode as a blank character.
        // Every character file ever saved has a name, even if it's empty.
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], object["name"] is String else {
            throw CharacterStoreError.unreadable
        }
        let existing = summaries.first { $0.id == character.id }
        let isAlreadyHere = existing != nil
            && (try? Self.comparableContent(of: load(character.id))) == (try? Self.comparableContent(of: character))
        return PendingImport(data: data, character: character, existing: existing, isAlreadyHere: isAlreadyHere)
    }

    /// Adds an imported character, replacing the one with the same identity unless `keepingBoth`,
    /// in which case the copy gets a new identity and a numbered name, e.g. "Lucius Avelorn (1)".
    /// Returns the imported character's ID.
    @discardableResult
    package func importCharacter(_ pending: PendingImport<C>, keepingBoth: Bool = false) throws -> UUID {
        var data = pending.data
        var id = pending.character.id
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        if keepingBoth && pending.existing != nil {
            // Only the identity and name change; everything else in the file is kept as it was
            guard var object else { throw CharacterStoreError.unreadable }
            id = UUID()
            object["id"] = id.uuidString
            object["name"] = Self.copyName(for: pending.character.name, taken: Set(summaries.map(\.name)))
            data = try JSONSerialization.data(withJSONObject: object)
        } else if (object?["id"] as? String).flatMap(UUID.init(uuidString:)) != id {
            // A file from before characters had IDs gets one when it's read, so it's saved with it
            data = try JSONEncoder().encode(pending.character)
        }
        // Otherwise the file is stored byte for byte, so its format and edited date stay as they were
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL(for: id), options: .atomic)
        reload()
        return id
    }

    /// The name for a copy, numbered like copied files: "Name (1)", then "Name (2)" and so on, using the
    /// first number no other character has. A copy of "Name (1)" is numbered from "Name" too.
    package nonisolated static func copyName(for name: String, taken: Set<String>) -> String {
        var base = name.isEmpty ? "Unnamed Character" : name
        if let suffix = base.range(of: #" \(\d+\)$"#, options: .regularExpression) {
            base.removeSubrange(suffix)
        }
        var number = 1
        while taken.contains("\(base) (\(number))") {
            number += 1
        }
        return "\(base) (\(number))"
    }

    // MARK: - Private

    private func fileURL(for id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).json", directoryHint: .notDirectory)
    }

    private func decodeCharacter(from data: Data) throws -> C {
        let probe = try JSONDecoder().decode(FormatProbe.self, from: data)
        // Only Requiem, the first game, wrote files without a game
        let game = probe.game ?? "requiem"
        guard game == C.game else {
            throw CharacterStoreError.otherGame(game)
        }
        // Version 1 saves have no schemaVersion key
        let version = probe.schemaVersion ?? 1
        guard version <= C.currentSchemaVersion else {
            throw CharacterStoreError.newerFormat(version: version)
        }
        return try JSONDecoder().decode(C.self, from: data)
    }

    /// The character's saved content, minus the edited date, for deciding whether anything has changed.
    private static func comparableContent(of character: C) throws -> Data {
        let data = try JSONEncoder().encode(character)
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return data
        }
        object["modifiedAt"] = nil
        return try JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
    }

    private struct FormatProbe: Decodable {
        let schemaVersion: Int?
        let game: String?
    }
}
