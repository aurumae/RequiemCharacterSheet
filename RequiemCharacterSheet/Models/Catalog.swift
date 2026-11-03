//
//  Catalog.swift
//  RequiemCharacterSheet
//

import Foundation

/// Reference data for Disciplines, Merits, Banes, Clans, Covenants, rituals, Devotions, Mysteries and Scales,
/// merged from every catalog file.
struct Catalog {
    let books: [Book]
    let disciplines: CatalogIndex<DisciplineEntry>
    let merits: CatalogIndex<MeritEntry>
    let banes: CatalogIndex<BaneEntry>
    let clans: CatalogIndex<ClanEntry>
    let covenants: CatalogIndex<CovenantEntry>
    let rituals: CatalogIndex<RitualEntry>
    let devotions: CatalogIndex<DevotionEntry>
    let mysteries: CatalogIndex<MysteryEntry>
    let scales: CatalogIndex<ScaleEntry>

    /// Merges files in order; if two files use the same id for the same kind of entry, the first wins.
    init(files: [CatalogFile]) {
        books = files.map(\.book)
        disciplines = CatalogIndex(files.flatMap(\.disciplines))
        merits = CatalogIndex(files.flatMap(\.merits))
        banes = CatalogIndex(files.flatMap(\.banes))
        clans = CatalogIndex(files.flatMap(\.clans))
        covenants = CatalogIndex(files.flatMap(\.covenants))
        rituals = CatalogIndex(files.flatMap(\.rituals))
        devotions = CatalogIndex(files.flatMap(\.devotions))
        mysteries = CatalogIndex(files.flatMap(\.mysteries))
        scales = CatalogIndex(files.flatMap(\.scales))
    }

    func book(_ id: String) -> Book? {
        books.first { $0.id == id }
    }

    /// The catalogs bundled with the app.
    static let bundled = Catalog(files: bundledFiles())

    /// Every catalog file in the app bundle. The core rulebook comes first so its entries take precedence.
    private static func bundledFiles(in bundle: Bundle = .main) -> [CatalogFile] {
        let urls = (bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .sorted { lhs, rhs in
                let isCore = { (url: URL) in url.deletingPathExtension().lastPathComponent == "vtr2e-core" }
                return isCore(lhs) != isCore(rhs) ? isCore(lhs) : lhs.lastPathComponent < rhs.lastPathComponent
            }
        return urls.compactMap { url in
            // Skip JSON resources that aren't catalogs
            guard let data = try? Data(contentsOf: url),
                  let probe = try? JSONDecoder().decode(FormatProbe.self, from: data),
                  probe.format == CatalogFile.format else {
                return nil
            }
            do {
                let file = try JSONDecoder().decode(CatalogFile.self, from: data)
                return file.version <= CatalogFile.supportedVersion ? file : nil
            } catch {
                // A bundled catalog that doesn't decode is a bug in the app's data
                assertionFailure("Couldn't load \(url.lastPathComponent): \(error)")
                return nil
            }
        }
    }

    private struct FormatProbe: Decodable {
        let format: String
    }
}

/// The entries of one kind, looked up by id or by name.
struct CatalogIndex<Entry: CatalogEntry> {
    /// In catalog order.
    let all: [Entry]
    private let byID: [CatalogEntryID: Entry]
    private let byName: [String: Entry]

    init(_ entries: [Entry]) {
        var seen = Set<CatalogEntryID>()
        all = entries.filter { seen.insert($0.id).inserted }
        byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        byName = Dictionary(all.map { (Self.matchKey($0.name), $0) }, uniquingKeysWith: { first, _ in first })
    }

    func entry(_ id: CatalogEntryID) -> Entry? {
        byID[id]
    }

    /// The entry with this name, ignoring case, accents, curly apostrophes and a leading "The", but not spaces,
    /// so a partly typed "Vigor B…" doesn't match Vigor.
    func entry(named name: String) -> Entry? {
        byName[Self.matchKey(name)]
    }

    /// Links a name to its catalog entry if there is one, otherwise keeps it as custom text.
    func source(named name: String) -> TraitSource {
        entry(named: name).map { .catalog($0.id) } ?? .custom(name)
    }

    /// The name to show for a source. Unknown catalog ids (e.g. from a catalog that's since been removed) show the id.
    func name(of source: TraitSource) -> String {
        switch source {
        case .catalog(let id):
            return entry(id)?.name ?? id
        case .custom(let name):
            return name
        }
    }

    private static func matchKey(_ name: String) -> String {
        let folded = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "\u{2019}", with: "'")
        return folded.hasPrefix("the ") ? String(folded.dropFirst(4)) : folded
    }
}
