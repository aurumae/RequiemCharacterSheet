//
//  ForsakenCatalog.swift
//  ForsakenCharacterSheet
//
//  Forsaken's catalog: for now the Chronicles of Darkness core Merits and Conditions, shared with Requiem. The
//  Werewolf books' entries will join them. The shared sheet sections look entries up through `Catalog.bundled`,
//  `merit.entry` and `merit.name`, and `citation()`, which each app defines for its own catalog.
//

import Foundation

/// Reference data for Merits and Conditions, merged from every catalog file bundled with the app.
struct Catalog {
    let books: [Book]
    let merits: CatalogIndex<MeritEntry>
    let conditions: CatalogIndex<ConditionEntry>

    /// Merges files in order; if two files use the same id for the same kind of entry, the first wins.
    init(files: [File]) {
        books = files.map(\.book)
        merits = CatalogIndex(files.flatMap(\.merits))
        conditions = CatalogIndex(files.flatMap(\.conditions))
    }

    func book(_ id: String) -> Book? {
        books.first { $0.id == id }
    }

    static let bundled = Catalog(files: bundledFiles())

    /// Every catalog file in the app bundle, the Chronicles of Darkness core first.
    private static func bundledFiles() -> [File] {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .sorted { lhs, rhs in
                let isCore = { (url: URL) in url.deletingPathExtension().lastPathComponent == "cofd-core" }
                return isCore(lhs) != isCore(rhs) ? isCore(lhs) : lhs.lastPathComponent < rhs.lastPathComponent
            }
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            do {
                let file = try JSONDecoder().decode(File.self, from: data)
                return file.format == File.format && file.version <= File.supportedVersion ? file : nil
            } catch {
                // A bundled catalog that doesn't decode is a bug in the app's data
                assertionFailure("Couldn't load \(url.lastPathComponent): \(error)")
                return nil
            }
        }
    }

    /// The parts of a catalog file this app uses. The shared core's file is in Requiem's format; other kinds of
    /// entry in it are left out.
    struct File: Decodable {
        static let format = "requiem-catalog"
        static let supportedVersion = 1

        let format: String
        let version: Int
        let book: Book
        let merits: [MeritEntry]
        let conditions: [ConditionEntry]

        enum CodingKeys: CodingKey {
            case format, version, book, merits, conditions
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            format = try container.decode(String.self, forKey: .format)
            version = try container.decode(Int.self, forKey: .version)
            book = try container.decode(Book.self, forKey: .book)
            merits = try container.decode(.merits, default: [])
            conditions = try container.decode(.conditions, default: [])
        }
    }
}

extension Merit {
    /// The catalog entry, if this isn't a custom Merit.
    var entry: MeritEntry? {
        entry(in: Catalog.bundled.merits)
    }

    /// The name shown on the sheet, e.g. "Language (French)". Setting it links to the catalog entry with that name,
    /// reading a trailing "(…)" as the qualifier.
    var name: String {
        get { name(in: Catalog.bundled.merits) }
        set { (source, qualifier) = Self.parse(newValue, in: Catalog.bundled.merits) }
    }
}

extension SourceReference {
    /// "Chronicles of Darkness, p. 44".
    func citation() -> String {
        let book = Catalog.bundled.book(book)?.name ?? book
        return page.map { "\(book), p. \($0)" } ?? book
    }
}
