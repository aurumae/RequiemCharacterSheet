//
//  CharacterStore.swift
//  RequiemCharacterSheet
//

import Foundation
import Observation

/// A saved character as shown in the character list.
struct CharacterSummary: Identifiable, Equatable {
    let id: UUID
    let name: String
    let clan: String
    /// Empty if the character has none.
    var bloodline = ""
    let covenant: String
    /// `nil` when the file couldn't be read.
    let modifiedAt: Date?
    /// False when the file couldn't be read. The file is left untouched so nothing is lost.
    let isReadable: Bool
}

extension CharacterSummary {
    /// The clan with any bloodline after it, e.g. "Ventrue (Bron)".
    var lineage: String {
        let bloodline = bloodline.trimmingCharacters(in: .whitespaces)
        guard !bloodline.isEmpty else { return clan }
        return clan.isEmpty ? bloodline : "\(clan) (\(bloodline))"
    }
}

enum CharacterStoreError: Error, Equatable {
    /// The file was saved by a newer version of the app. Opening it here could drop fields this version doesn't know about.
    case newerFormat(version: Int)
    /// The file isn't a character file, or it's damaged.
    case unreadable
}

extension CharacterStoreError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .newerFormat:
            "This character was saved by a newer version of the app. Update the app to open it."
        case .unreadable:
            "The file isn't a character file, or it's damaged."
        }
    }
}

/// A character file that has been read and checked, waiting to be added to the store.
struct CharacterImport {
    /// The file exactly as it was received.
    let data: Data
    let character: Character
    /// The character on this device with the same identity, if there is one.
    let existing: CharacterSummary?
    /// The character on this device is the same as the file, apart from perhaps its edited date.
    let isAlreadyHere: Bool
}

/// Saves each character as its own JSON file in the app's private Application Support directory.
@MainActor
@Observable
final class CharacterStore {
    /// UserDefaults key used by versions that saved a single character.
    static let legacySaveKey = "SavedCharacter"

    nonisolated static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Characters", isDirectory: true)
    }

    /// Newest first; unreadable files are listed last.
    private(set) var summaries: [CharacterSummary] = []

    private let directory: URL
    private let legacyDefaults: UserDefaults

    init(directory: URL = CharacterStore.defaultDirectory, legacyDefaults: UserDefaults = .standard) {
        self.directory = directory
        self.legacyDefaults = legacyDefaults
        reload()
    }

    /// Re-reads the list of saved characters from disk.
    func reload() {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        summaries = urls.compactMap { url -> CharacterSummary? in
            // Ignore anything that isn't one of our "<id>.json" files
            guard url.pathExtension == "json",
                  let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else {
                return nil
            }
            guard let data = try? Data(contentsOf: url),
                  let character = try? decodeCharacter(from: data) else {
                return CharacterSummary(id: id, name: "", clan: "", covenant: "", modifiedAt: nil, isReadable: false)
            }
            return CharacterSummary(
                id: id,
                name: character.name,
                clan: character.clan,
                bloodline: character.bloodline,
                covenant: character.covenant,
                modifiedAt: character.modifiedAt,
                isReadable: true
            )
        }
        .sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
    }

    func load(_ id: UUID) throws -> Character {
        let data = try Data(contentsOf: fileURL(for: id))
        return try decodeCharacter(from: data)
    }

    /// Writes the character to disk and stamps it as edited at `date`, unless nothing has changed
    /// since it was last saved, in which case the file and its edited date are left as they are.
    /// Returns whether the file was written.
    @discardableResult
    func save(_ character: Character, at date: Date = .now) throws -> Bool {
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

    func delete(_ id: UUID) throws {
        try FileManager.default.removeItem(at: fileURL(for: id))
        reload()
    }

    /// Moves the single character saved by earlier versions into the store.
    /// The old save is only removed once the new file has been written, so a failure leaves it in place to retry.
    func migrateLegacySaveIfNeeded() throws {
        guard let data = legacyDefaults.data(forKey: Self.legacySaveKey) else { return }
        let character = try decodeCharacter(from: data)
        try save(character, at: character.modifiedAt)
        legacyDefaults.removeObject(forKey: Self.legacySaveKey)
    }

    // MARK: - Export and import

    /// The character's saved file, exactly as stored, for sharing with another device.
    func exportData(for id: UUID) throws -> Data {
        try Data(contentsOf: exportURL(for: id))
    }

    /// Where the character's saved file is, for sharing it without reading it first.
    func exportURL(for id: UUID) -> URL {
        fileURL(for: id)
    }

    /// Reads a received character file and checks it can be opened, without changing the store.
    func prepareImport(of data: Data) throws -> CharacterImport {
        let character: Character
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
        return CharacterImport(data: data, character: character, existing: existing, isAlreadyHere: isAlreadyHere)
    }

    /// Adds an imported character, replacing the one with the same identity unless `keepingBoth`,
    /// in which case the copy gets a new identity and a numbered name, e.g. "Lucius Avelorn (1)".
    /// Returns the imported character's ID.
    @discardableResult
    func importCharacter(_ pending: CharacterImport, keepingBoth: Bool = false) throws -> UUID {
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
    nonisolated static func copyName(for name: String, taken: Set<String>) -> String {
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

    private func decodeCharacter(from data: Data) throws -> Character {
        // Version 1 saves have no schemaVersion key
        let version = try JSONDecoder().decode(SchemaVersionProbe.self, from: data).schemaVersion ?? 1
        guard version <= Character.currentSchemaVersion else {
            throw CharacterStoreError.newerFormat(version: version)
        }
        return try JSONDecoder().decode(Character.self, from: data)
    }

    /// The character's saved content, minus the edited date, for deciding whether anything has changed.
    private static func comparableContent(of character: Character) throws -> Data {
        let data = try JSONEncoder().encode(character)
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return data
        }
        object["modifiedAt"] = nil
        return try JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
    }

    private struct SchemaVersionProbe: Decodable {
        let schemaVersion: Int?
    }
}
