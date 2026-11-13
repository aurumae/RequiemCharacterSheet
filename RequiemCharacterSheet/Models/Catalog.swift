//
//  Catalog.swift
//  RequiemCharacterSheet
//

import Foundation
#if SWIFT_PACKAGE
import ChroniclesCore
#endif

/// Reference data for Disciplines, Merits, Banes, Clans, Bloodlines, Covenants, rituals, Devotions, Mysteries, Scales,
/// archetypes, Conditions and elder clan banes, merged from every catalog file.
struct Catalog {
    let books: [Book]
    let disciplines: CatalogIndex<DisciplineEntry>
    let merits: CatalogIndex<MeritEntry>
    let banes: CatalogIndex<BaneEntry>
    let clans: CatalogIndex<ClanEntry>
    let bloodlines: CatalogIndex<BloodlineEntry>
    let covenants: CatalogIndex<CovenantEntry>
    let rituals: CatalogIndex<RitualEntry>
    let devotions: CatalogIndex<DevotionEntry>
    let mysteries: CatalogIndex<MysteryEntry>
    let scales: CatalogIndex<ScaleEntry>
    let archetypes: CatalogIndex<ArchetypeEntry>
    let conditions: CatalogIndex<ConditionEntry>
    let elderBanes: CatalogIndex<ElderBaneEntry>

    /// Merges files in order; if two files use the same id for the same kind of entry, the first wins.
    init(files: [CatalogFile]) {
        books = files.map(\.book)
        disciplines = CatalogIndex(files.flatMap(\.disciplines))
        merits = CatalogIndex(files.flatMap(\.merits))
        banes = CatalogIndex(files.flatMap(\.banes))
        clans = CatalogIndex(files.flatMap(\.clans))
        bloodlines = CatalogIndex(files.flatMap(\.bloodlines))
        covenants = CatalogIndex(files.flatMap(\.covenants))
        rituals = CatalogIndex(files.flatMap(\.rituals))
        devotions = CatalogIndex(files.flatMap(\.devotions))
        mysteries = CatalogIndex(files.flatMap(\.mysteries))
        scales = CatalogIndex(files.flatMap(\.scales))
        archetypes = CatalogIndex(files.flatMap(\.archetypes))
        conditions = CatalogIndex(files.flatMap(\.conditions))
        elderBanes = CatalogIndex(files.flatMap(\.elderBanes))
    }

    func book(_ id: String) -> Book? {
        books.first { $0.id == id }
    }

    /// The catalogs bundled with the app.
    #if SWIFT_PACKAGE
    static let bundled = Catalog(files: bundledFiles(in: .module))
    #else
    static let bundled = Catalog(files: bundledFiles(in: .main))
    #endif

    /// Every catalog file in the app bundle. The core rulebook comes first so its entries take precedence.
    private static func bundledFiles(in bundle: Bundle) -> [CatalogFile] {
        let urls = (bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .map { $0 as URL }
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

