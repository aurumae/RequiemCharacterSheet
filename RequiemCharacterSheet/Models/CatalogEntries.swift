//
//  CatalogEntries.swift
//  RequiemCharacterSheet
//

import Foundation

/// Identifies a catalog entry within its kind, e.g. "vigor" or "defensive-combat". Stable across versions.
typealias CatalogEntryID = String

/// Anything listed in a catalog: a Discipline, Merit, Bane, Clan or Covenant.
protocol CatalogEntry: Identifiable, Decodable where ID == CatalogEntryID {
    var name: String { get }
    var source: SourceReference { get }
    /// Our own one-line description. Never book text.
    var summary: String { get }
}

struct Book: Codable, Hashable {
    let id: String
    let name: String
}

/// Where an entry is described: a book, and the page if known.
struct SourceReference: Codable, Hashable {
    let book: String
    let page: Int?
}

/// One catalog file, bundled with the app (and later, imported).
struct CatalogFile: Decodable {
    static let format = "requiem-catalog"
    static let supportedVersion = 1

    let format: String
    let version: Int
    let book: Book
    let disciplines: [DisciplineEntry]
    let merits: [MeritEntry]
    let banes: [BaneEntry]
    let clans: [ClanEntry]
    let covenants: [CovenantEntry]

    enum CodingKeys: CodingKey {
        case format, version, book, disciplines, merits, banes, clans, covenants
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        format = try container.decode(String.self, forKey: .format)
        version = try container.decode(Int.self, forKey: .version)
        book = try container.decode(Book.self, forKey: .book)
        // A book only lists the kinds of entry it has
        disciplines = try container.decode(.disciplines, default: [])
        merits = try container.decode(.merits, default: [])
        banes = try container.decode(.banes, default: [])
        clans = try container.decode(.clans, default: [])
        covenants = try container.decode(.covenants, default: [])
    }
}

// MARK: - Disciplines

struct DisciplineEntry: CatalogEntry {
    let id: CatalogEntryID
    let name: String
    let kind: Kind
    let source: SourceReference
    let summary: String
    let powers: [DisciplinePower]

    enum Kind: String, Decodable {
        /// One named power per dot, e.g. Dominate.
        case powers
        /// One entry whose effect grows with dots, e.g. Vigor.
        case scaling
    }
}

struct DisciplinePower: Decodable, Identifiable {
    let id: CatalogEntryID
    let name: String
    /// The dots this power covers: a single dot, or 1–5 for a scaling Discipline.
    let dots: ClosedRange<Int>
    let cost: Cost
    let action: String?
    let duration: String?
    /// A Condition the target must already have, e.g. "Mesmerized".
    let targetCondition: String?
    let dicePool: DicePool?
    let summary: String
    let page: Int?

    enum CodingKeys: CodingKey {
        case id, name, dots, cost, action, duration, targetCondition, dicePool, summary, page
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        // Saved as [lowest, highest]
        let bounds = try container.decode([Int].self, forKey: .dots)
        guard let lowest = bounds.first, let highest = bounds.last, lowest <= highest else {
            throw DecodingError.dataCorruptedError(forKey: .dots, in: container, debugDescription: "Expected [lowest, highest]")
        }
        dots = lowest...highest
        cost = try container.decode(.cost, default: Cost())
        action = try container.decodeIfPresent(String.self, forKey: .action)
        duration = try container.decodeIfPresent(String.self, forKey: .duration)
        targetCondition = try container.decodeIfPresent(String.self, forKey: .targetCondition)
        dicePool = try container.decodeIfPresent(DicePool.self, forKey: .dicePool)
        summary = try container.decode(String.self, forKey: .summary)
        page = try container.decodeIfPresent(Int.self, forKey: .page)
    }
}

/// What using a power costs.
struct Cost: Decodable {
    var vitae: CostAmount?
    var willpower: CostAmount?
    /// Paying is optional, e.g. to boost a scaling Discipline.
    var optional: Bool = false
    var note: String?
}

enum CostAmount: Decodable, Equatable {
    case fixed(Int)
    case range(ClosedRange<Int>)
    case varies

    private enum CodingKeys: CodingKey {
        case fixed, range
    }

    /// Saved as {"fixed": 2}, {"range": [3, 9]} or "varies".
    init(from decoder: Decoder) throws {
        if let text = try? decoder.singleValueContainer().decode(String.self), text == "varies" {
            self = .varies
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let amount = try container.decodeIfPresent(Int.self, forKey: .fixed) {
            self = .fixed(amount)
        } else {
            let bounds = try container.decode([Int].self, forKey: .range)
            guard let lowest = bounds.first, let highest = bounds.last, lowest <= highest else {
                throw DecodingError.dataCorruptedError(forKey: .range, in: container, debugDescription: "Expected [lowest, highest]")
            }
            self = .range(lowest...highest)
        }
    }
}

/// A power's dice pool, e.g. Intelligence + Expression + Dominate vs. Resolve + Blood Potency.
struct DicePool: Decodable {
    let attribute: AttributeKind?
    let skill: SkillID?
    let includesDiscipline: Bool
    /// How the target resists, as the book states it.
    let resistance: String?
    /// For pools that don't fit the usual shape.
    let text: String?
}

// MARK: - Merits

struct MeritEntry: CatalogEntry {
    let id: CatalogEntryID
    let name: String
    let category: Category
    let source: SourceReference
    /// Every rating the Merit can be bought at.
    let ratings: [Int]
    /// What the Merit is taken for, e.g. the language in Language (French).
    let qualifier: QualifierRule?
    let repeatable: Bool
    let prerequisites: [Prerequisite]
    /// Alternative sets of prerequisites, any one of which is enough.
    let prerequisitesAnyOf: [[Prerequisite]]
    /// For Fighting Styles: the maneuver each dot grants.
    let styleManeuvers: [StyleManeuver]
    let summary: String

    enum Category: String, Decodable {
        case mental, physical, social, fighting, vampire, covenant, other
    }

    enum CodingKeys: CodingKey {
        case id, name, category, source, ratings, qualifier, repeatable
        case prerequisites, prerequisitesAnyOf, styleManeuvers, summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(.category, default: .other)
        source = try container.decode(SourceReference.self, forKey: .source)
        ratings = try container.decode([Int].self, forKey: .ratings)
        qualifier = try container.decodeIfPresent(QualifierRule.self, forKey: .qualifier)
        repeatable = try container.decode(.repeatable, default: false)
        prerequisites = try container.decode(.prerequisites, default: [])
        prerequisitesAnyOf = try container.decode(.prerequisitesAnyOf, default: [])
        styleManeuvers = try container.decode(.styleManeuvers, default: [])
        summary = try container.decode(String.self, forKey: .summary)
    }
}

struct QualifierRule: Decodable {
    /// What the player is asked for, e.g. "Skill" or "Language".
    let prompt: String
    /// The allowed choices, if limited.
    let options: [String]?
}

struct Prerequisite: Decodable {
    let kind: Kind
    /// The attribute, skill, merit, discipline, clan or covenant id.
    let id: String?
    let minimum: Int?
    /// For prerequisites that can't be checked automatically.
    let text: String?

    enum Kind: String, Decodable {
        case attribute, skill, merit, discipline, bloodPotency, clan, covenant, other
    }
}

struct StyleManeuver: Decodable {
    let dots: Int
    let name: String
    let summary: String
}

// MARK: - Banes, Clans and Covenants

struct BaneEntry: CatalogEntry {
    let id: CatalogEntryID
    let name: String
    let source: SourceReference
    let summary: String
}

struct ClanEntry: CatalogEntry {
    let id: CatalogEntryID
    let name: String
    let nickname: String?
    let source: SourceReference
    /// The two Attributes the clan favours; one is chosen at the Embrace.
    let favoredAttributes: [AttributeKind]
    /// In-clan Disciplines.
    let disciplines: [CatalogEntryID]
    let bane: ClanBane
    let summary: String
}

struct ClanBane: Decodable {
    let name: String
    let summary: String
    /// Takes effect when Humanity first falls to this, if the book gives one.
    let humanityThreshold: Int?
    let page: Int?
}

struct CovenantEntry: CatalogEntry {
    let id: CatalogEntryID
    let name: String
    let source: SourceReference
    let summary: String
}
