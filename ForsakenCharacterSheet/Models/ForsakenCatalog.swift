//
//  ForsakenCatalog.swift
//  ForsakenCharacterSheet
//
//  Forsaken's catalog: the Werewolf books' entries, and the Chronicles of Darkness core Merits and Conditions shared
//  with Requiem. The shared sheet sections look entries up through `Catalog.bundled`,
//  `merit.entry` and `merit.name`, the Condition conveniences below and `citation()`, which each app defines for its
//  own catalog.
//

import Foundation
#if SWIFT_PACKAGE
import ChroniclesCore
#endif

/// Reference data for auspices, tribes, lodges, Blood and Bone, Gifts, Rites, Merits, Conditions, fetishes and Tilts,
/// merged from every catalog file bundled with the app.
struct Catalog {
    let books: [Book]
    let auspices: CatalogIndex<AuspiceEntry>
    let tribes: CatalogIndex<TribeEntry>
    let lodges: CatalogIndex<LodgeEntry>
    let archetypes: CatalogIndex<ArchetypeEntry>
    let gifts: CatalogIndex<GiftEntry>
    let rites: CatalogIndex<RiteEntry>
    let merits: CatalogIndex<MeritEntry>
    let conditions: CatalogIndex<ConditionEntry>
    let fetishes: CatalogIndex<FetishEntry>
    let kuruthTriggers: CatalogIndex<KuruthTriggerSetEntry>
    let tilts: CatalogIndex<TiltEntry>

    /// Merges files in order; if two files use the same id for the same kind of entry, the first wins.
    init(files: [File]) {
        books = files.map(\.book)
        auspices = CatalogIndex(files.flatMap(\.auspices))
        tribes = CatalogIndex(files.flatMap(\.tribes))
        lodges = CatalogIndex(files.flatMap(\.lodges))
        archetypes = CatalogIndex(files.flatMap(\.archetypes))
        gifts = CatalogIndex(files.flatMap(\.gifts))
        rites = CatalogIndex(files.flatMap(\.rites))
        merits = CatalogIndex(files.flatMap(\.merits))
        conditions = CatalogIndex(files.flatMap(\.conditions))
        fetishes = CatalogIndex(files.flatMap(\.fetishes))
        kuruthTriggers = CatalogIndex(files.flatMap(\.kuruthTriggers))
        tilts = CatalogIndex(files.flatMap(\.tilts))
    }

    func book(_ id: String) -> Book? {
        books.first { $0.id == id }
    }

    /// The lodges that teach a Merit to their adherents; none for a Merit open to anyone.
    func lodges(teachingMerit id: CatalogEntryID) -> [LodgeEntry] {
        lodges.all.filter { $0.merits?.contains(id) ?? false }
    }

    func lodges(teachingRite id: CatalogEntryID) -> [LodgeEntry] {
        lodges.all.filter { $0.rites?.contains(id) ?? false }
    }

    /// A Gift Facet by its id, with its Gift.
    func facet(_ id: CatalogEntryID) -> (gift: GiftEntry, facet: GiftEntry.Facet)? {
        for gift in gifts.all {
            if let facet = gift.facets.first(where: { $0.id == id }) {
                return (gift, facet)
            }
        }
        return nil
    }

    #if SWIFT_PACKAGE
    // The host package can't bundle a file from another target's folder, so its tests read the shared Chronicles of
    // Darkness core where it is in the checkout
    static let bundled = Catalog(files: bundledFiles(in: .module, with: [
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RequiemCharacterSheet/Catalogs/cofd-core.json"),
    ]))
    #else
    static let bundled = Catalog(files: bundledFiles(in: .main))
    #endif

    /// Every catalog file in the app bundle: the Werewolf core book first, then the Chronicles of Darkness core, then
    /// the other books by file name (without ".json", so "dark-eras" comes before "dark-eras-2"), with unofficial
    /// sources after all the books.
    private static func bundledFiles(in bundle: Bundle, with others: [URL] = []) -> [File] {
        let order = ["wtf2e-core", "cofd-core"]
        let urls = ((bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []) + others)
            .sorted { lhs, rhs in
                let name = { (url: URL) in url.deletingPathExtension().lastPathComponent }
                let rank = { (url: URL) in order.firstIndex(of: name(url)) ?? order.count }
                return rank(lhs) != rank(rhs) ? rank(lhs) < rank(rhs) : name(lhs) < name(rhs)
            }
        let files: [File] = urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            do {
                let file = try JSONDecoder().decode(File.self, from: data)
                return File.formats.contains(file.format) && file.version <= File.supportedVersion ? file : nil
            } catch {
                // A bundled catalog that doesn't decode is a bug in the app's data
                assertionFailure("Couldn't load \(url.lastPathComponent): \(error)")
                return nil
            }
        }
        return files.filter(\.book.official) + files.filter { !$0.book.official }
    }

    /// A catalog file: Forsaken's own format, or the shared core's in Requiem's format, of which only the Merits and
    /// Conditions are used.
    struct File: Decodable {
        static let formats: Set<String> = ["forsaken-catalog", "requiem-catalog"]
        static let supportedVersion = 1

        let format: String
        let version: Int
        let book: Book
        let auspices: [AuspiceEntry]
        let tribes: [TribeEntry]
        let lodges: [LodgeEntry]
        let archetypes: [ArchetypeEntry]
        let gifts: [GiftEntry]
        let rites: [RiteEntry]
        let merits: [MeritEntry]
        let conditions: [ConditionEntry]
        let fetishes: [FetishEntry]
        let kuruthTriggers: [KuruthTriggerSetEntry]
        let tilts: [TiltEntry]

        enum CodingKeys: CodingKey {
            case format, version, book, auspices, tribes, lodges, archetypes, gifts, rites, merits, conditions, fetishes
            case kuruthTriggers, tilts
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            format = try container.decode(String.self, forKey: .format)
            version = try container.decode(Int.self, forKey: .version)
            book = try container.decode(Book.self, forKey: .book)
            // A book only lists the kinds of entry it has; Requiem's own kinds are ignored
            let isForsaken = format == "forsaken-catalog"
            auspices = isForsaken ? try container.decode(.auspices, default: []) : []
            tribes = isForsaken ? try container.decode(.tribes, default: []) : []
            lodges = isForsaken ? try container.decode(.lodges, default: []) : []
            archetypes = isForsaken ? try container.decode(.archetypes, default: []) : []
            gifts = isForsaken ? try container.decode(.gifts, default: []) : []
            rites = isForsaken ? try container.decode(.rites, default: []) : []
            merits = try container.decode(.merits, default: [])
            conditions = try container.decode(.conditions, default: [])
            fetishes = isForsaken ? try container.decode(.fetishes, default: []) : []
            kuruthTriggers = isForsaken ? try container.decode(.kuruthTriggers, default: []) : []
            tilts = isForsaken ? try container.decode(.tilts, default: []) : []
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
        // An article online is cited by its address
        if let url = Catalog.bundled.book(book)?.url {
            return url
        }
        let book = Catalog.bundled.book(book)?.name ?? book
        return page.map { "\(book), p. \($0)" } ?? book
    }
}

/// A Condition looked up in the bundled catalogs.
extension CharacterCondition {
    /// The catalog entry, if this isn't a custom Condition.
    var entry: ConditionEntry? {
        entry(in: Catalog.bundled.conditions)
    }

    var name: String {
        get { name(in: Catalog.bundled.conditions) }
        set { source = Catalog.bundled.conditions.source(named: newValue) }
    }

    var isPersistent: Bool { entry?.persistent ?? customPersistent }
    var effectText: String { entry?.summary ?? customEffect }
    var resolutionText: String { entry?.resolution ?? customResolution }

    /// How it earns a Beat while it lasts, or `nil` if it doesn't.
    var beatText: String? {
        if let entry { return entry.beat }
        let beat = customBeat.trimmingCharacters(in: .whitespacesAndNewlines)
        return beat.isEmpty ? nil : beat
    }

    var givesBeatOnResolve: Bool { givesBeatOnResolve(in: Catalog.bundled.conditions) }
    var hasCounter: Bool { hasCounter(in: Catalog.bundled.conditions) }
    /// e.g. "Tempted −3", or "Swooning".
    var titleWithCounter: String { titleWithCounter(in: Catalog.bundled.conditions) }
}
