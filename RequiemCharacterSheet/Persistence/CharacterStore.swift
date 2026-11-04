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
    let covenant: String
    /// `nil` when the file couldn't be read.
    let modifiedAt: Date?
    /// False when the file couldn't be read. The file is left untouched so nothing is lost.
    let isReadable: Bool
}

enum CharacterStoreError: Error, Equatable {
    /// The file was saved by a newer version of the app. Opening it here could drop fields this version doesn't know about.
    case newerFormat(version: Int)
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
