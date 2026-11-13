//
//  CatalogCore.swift
//  ChroniclesCore
//
//  Catalog types every game shares: entries, books, the lookup index, Merits, Conditions and their effects.
//  Each game's app owns its bundled catalog and passes it in where these need one.
//

import Foundation

/// Identifies a catalog entry within its kind, e.g. "vigor" or "defensive-combat". Stable across versions.
package typealias CatalogEntryID = String

/// Anything listed in a catalog: a Discipline, Merit, Bane, Clan, Covenant, ritual, Devotion, Mystery or Scale.
package protocol CatalogEntry: Identifiable, Decodable where ID == CatalogEntryID {
    var name: String { get }
    var source: SourceReference { get }
    /// Our own one-line description. Never book text.
    var summary: String { get }
}

package struct Book: Codable, Hashable {
    package let id: String
    package let name: String
}

/// Where an entry is described: a book, and the page if known.
package struct SourceReference: Codable, Hashable {
    package let book: String
    package let page: Int?
}

/// The entries of one kind, looked up by id or by name.
package struct CatalogIndex<Entry: CatalogEntry> {
    /// In catalog order.
    package let all: [Entry]
    private let byID: [CatalogEntryID: Entry]
    private let byName: [String: Entry]

    package init(_ entries: [Entry]) {
        var seen = Set<CatalogEntryID>()
        all = entries.filter { seen.insert($0.id).inserted }
        byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        byName = Dictionary(all.map { (Self.matchKey($0.name), $0) }, uniquingKeysWith: { first, _ in first })
    }

    package func entry(_ id: CatalogEntryID) -> Entry? {
        byID[id]
    }

    /// The entry with this name, ignoring case, accents, curly apostrophes and a leading "The", but not spaces,
    /// so a partly typed "Vigor B…" doesn't match Vigor.
    package func entry(named name: String) -> Entry? {
        byName[Self.matchKey(name)]
    }

    /// Links a name to its catalog entry if there is one, otherwise keeps it as custom text.
    package func source(named name: String) -> TraitSource {
        entry(named: name).map { .catalog($0.id) } ?? .custom(name)
    }

    /// The name to show for a source. Unknown catalog ids (e.g. from a catalog that's since been removed) show the id.
    package func name(of source: TraitSource) -> String {
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

// MARK: - Merits

package struct MeritEntry: CatalogEntry {
    package let id: CatalogEntryID
    package let name: String
    package let category: Category
    package let source: SourceReference
    /// Every rating the Merit can be bought at.
    package let ratings: [Int]
    /// What the Merit is taken for, e.g. the language in Language (French).
    package let qualifier: QualifierRule?
    package let repeatable: Bool
    package let prerequisites: [Prerequisite]
    /// Alternative sets of prerequisites, any one of which is enough.
    package let prerequisitesAnyOf: [[Prerequisite]]
    /// For Fighting Styles: the maneuver each dot grants.
    package let styleManeuvers: [StyleManeuver]
    package let summary: String
    /// Always-on effects on the sheet, e.g. Fleet of Foot adding to Speed.
    package let effects: [Effect]
    /// Kindred can't take it: the Supernatural Merits, and Vice-Ridden and Virtuous, since vampires
    /// have no Virtue or Vice (Vampire: The Requiem p. 81).
    package let unavailableToKindred: Bool
    /// A family of Merits another covenant may also take, e.g. "carthian-law" for the Carthian Laws.
    package let group: String?

    /// Where the Merit is listed, e.g. "mental" or "vampire". Each game adds its own, so any name is accepted.
    package struct Category: RawRepresentable, Hashable, Decodable {
        package let rawValue: String
        package init(rawValue: String) { self.rawValue = rawValue }
        package init(from decoder: Decoder) throws {
            rawValue = try decoder.singleValueContainer().decode(String.self)
        }

        package static let mental = Category(rawValue: "mental")
        package static let physical = Category(rawValue: "physical")
        package static let social = Category(rawValue: "social")
        package static let fighting = Category(rawValue: "fighting")
        package static let supernatural = Category(rawValue: "supernatural")
        package static let other = Category(rawValue: "other")
    }

    package enum CodingKeys: CodingKey {
        case id, name, category, source, ratings, qualifier, repeatable
        case prerequisites, prerequisitesAnyOf, styleManeuvers, summary, effects, unavailableToKindred, group
    }

    package init(from decoder: Decoder) throws {
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
        effects = try container.decodeEffects(.effects)
        unavailableToKindred = try container.decode(.unavailableToKindred, default: false)
        group = try container.decodeIfPresent(String.self, forKey: .group)
    }
}

package struct QualifierRule: Decodable {
    /// What the player is asked for, e.g. "Skill" or "Language".
    package let prompt: String
    /// The allowed choices, if limited.
    package let options: [String]?
    /// The choices are the character's Skill Specialties, e.g. for Area of Expertise.
    package let fromSpecialties: Bool?
    /// The choices are every covenant in the catalogs, e.g. for Covenant Status.
    package let fromCovenants: Bool?
}

package struct Prerequisite: Decodable {
    package let kind: Kind
    /// The attribute, skill, merit, discipline, clan or covenant id.
    package let id: String?
    package let minimum: Int?
    /// For prerequisites that can't be checked automatically.
    package let text: String?

    /// What's required. These are the kinds every game shares; each game adds its own, e.g. "clan" or "discipline",
    /// so any name is accepted, and one a game doesn't know is shown as text.
    package struct Kind: RawRepresentable, Hashable, Decodable {
        package let rawValue: String
        package init(rawValue: String) { self.rawValue = rawValue }
        package init(from decoder: Decoder) throws {
            rawValue = try decoder.singleValueContainer().decode(String.self)
        }

        package static let attribute = Kind(rawValue: "attribute")
        package static let skill = Kind(rawValue: "skill")
        package static let merit = Kind(rawValue: "merit")
        /// Willpower dots (Resolve + Composure), e.g. Mobilize Outrage.
        package static let willpower = Kind(rawValue: "willpower")
        package static let other = Kind(rawValue: "other")
    }
}

package struct StyleManeuver: Decodable {
    package let dots: Int
    package let name: String
    package let summary: String
}

// MARK: - Conditions

/// A Condition, e.g. Swooning: what it does, how it's resolved, and what earns a Beat while it lasts.
package struct ConditionEntry: CatalogEntry {
    package let id: CatalogEntryID
    package let name: String
    package let source: SourceReference
    /// Lasts until resolved, and usually earns Beats along the way.
    package let persistent: Bool
    /// What it does, in our own words.
    package let summary: String
    package let resolution: String
    /// How it earns a Beat while it lasts; `nil` when it doesn't.
    package let beat: String?
    package let possibleSources: String?
    /// Resolving it earns a Beat. A few say they don't, e.g. Distracted.
    package let beatOnResolve: Bool
    /// A character can have it more than once, e.g. Swooning for two people.
    package let repeatable: Bool
    /// What the note on the sheet is for, e.g. "For" (whom) or "Addicted to"; `nil` if it has none.
    package let notePrompt: String?
    /// It has a growing penalty, shown as "Tempted −3".
    package let counter: Bool
    /// The traits it clearly affects, marked on the sheet. Situational effects aren't listed.
    package let affects: [ConditionEffect]

    package enum CodingKeys: CodingKey {
        case id, name, source, persistent, summary, resolution, beat, possibleSources, beatOnResolve, repeatable
        case notePrompt, counter, affects
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        source = try container.decode(SourceReference.self, forKey: .source)
        persistent = try container.decode(.persistent, default: false)
        summary = try container.decode(String.self, forKey: .summary)
        resolution = try container.decode(.resolution, default: "")
        beat = try container.decodeIfPresent(String.self, forKey: .beat)
        possibleSources = try container.decodeIfPresent(String.self, forKey: .possibleSources)
        beatOnResolve = try container.decode(.beatOnResolve, default: true)
        repeatable = try container.decode(.repeatable, default: false)
        notePrompt = try container.decodeIfPresent(String.self, forKey: .notePrompt)
        counter = try container.decode(.counter, default: false)
        affects = try container.decode(.affects, default: [])
    }
}

/// Traits a Condition affects, and how, e.g. Deprived: "−1 to dice pools using Stamina, Resolve or Composure".
package struct ConditionEffect: Decodable, Equatable {
    package let targets: [ConditionTarget]
    package let text: String

    package enum CodingKeys: CodingKey {
        case targets, text
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Targets this version doesn't know are skipped, so a newer catalog still loads
        targets = try container.decode([String].self, forKey: .targets).compactMap(ConditionTarget.init)
        text = try container.decode(String.self, forKey: .text)
    }
}

/// A trait or group of traits a Condition affects. Saved as "attribute:stamina", "skill:intimidation",
/// "attributeCategory:social", "skillCategory:physical" or "defense".
package enum ConditionTarget: Equatable, Hashable {
    case attribute(AttributeKind)
    case skill(SkillID)
    case attributeCategory(TraitCategory)
    case skillCategory(TraitCategory)
    case defense

    package init?(_ text: String) {
        let parts = text.split(separator: ":", maxSplits: 1).map(String.init)
        switch (parts.first, parts.count == 2 ? parts[1] : nil) {
        case ("attribute", let id?):
            guard let kind = AttributeKind(rawValue: id) else { return nil }
            self = .attribute(kind)
        case ("skill", let id?):
            self = .skill(SkillID(id))
        case ("attributeCategory", let id?):
            guard let category = TraitCategory(rawValue: id) else { return nil }
            self = .attributeCategory(category)
        case ("skillCategory", let id?):
            guard let category = TraitCategory(rawValue: id) else { return nil }
            self = .skillCategory(category)
        case ("defense", nil):
            self = .defense
        default:
            return nil
        }
    }
}

// MARK: - Effects

/// A rules effect a Discipline or Merit has on the sheet. The character's rules add these up
/// instead of recognising Disciplines and Merits by name.
package enum Effect: Decodable, Equatable {
    /// Raises the Attribute itself, so everything derived from it (Speed, Defense, Health) and every roll includes it.
    /// Vigor (Strength), Resilience (Stamina).
    case attribute(AttributeKind, Amount)
    /// Adds to the Attribute only when it's rolled, not to traits derived from it. Praestantia (Dexterity).
    case attributeRolls(AttributeKind, Amount)
    /// Celerity.
    case defense(Amount)
    /// Praestantia, Fast Reflexes.
    case initiative(Amount)
    /// Fleet of Foot.
    case speed(Amount)
    /// Changes Size, and so Health. Giant, Small-Framed.
    case size(Amount)
    /// Defense may use the Skill named by the Merit's qualifier instead of Athletics. Defensive Combat.
    case defenseSkillFromQualifier
    /// Adds dots to another Merit, which may go above five. Flock (Herd).
    case merit(CatalogEntryID, Amount)

    private enum CodingKeys: CodingKey {
        case type, attribute, merit, amount
    }

    /// Saved as e.g. {"type": "attribute", "attribute": "strength", "amount": "rating"}.
    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "attribute":
            self = .attribute(try container.decode(AttributeKind.self, forKey: .attribute), try container.decode(Amount.self, forKey: .amount))
        case "attributeRolls":
            self = .attributeRolls(try container.decode(AttributeKind.self, forKey: .attribute), try container.decode(Amount.self, forKey: .amount))
        case "defense":
            self = .defense(try container.decode(Amount.self, forKey: .amount))
        case "initiative":
            self = .initiative(try container.decode(Amount.self, forKey: .amount))
        case "speed":
            self = .speed(try container.decode(Amount.self, forKey: .amount))
        case "size":
            self = .size(try container.decode(Amount.self, forKey: .amount))
        case "defenseSkillFromQualifier":
            self = .defenseSkillFromQualifier
        case "merit":
            self = .merit(try container.decode(String.self, forKey: .merit), try container.decode(Amount.self, forKey: .amount))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown effect \(type)")
        }
    }
}

/// How much an effect adds.
package enum Amount: Decodable, Equatable {
    /// The Discipline's or Merit's dots.
    case rating
    case fixed(Int)

    private enum CodingKeys: CodingKey {
        case fixed
    }

    /// Saved as "rating" or {"fixed": 1}.
    package init(from decoder: Decoder) throws {
        if let text = try? decoder.singleValueContainer().decode(String.self), text == "rating" {
            self = .rating
        } else {
            self = .fixed(try decoder.container(keyedBy: CodingKeys.self).decode(Int.self, forKey: .fixed))
        }
    }

    package func value(forRating rating: Int) -> Int {
        switch self {
        case .rating:
            return rating
        case .fixed(let amount):
            return amount
        }
    }
}

extension KeyedDecodingContainer {
    /// Decodes a list of effects, skipping any this version doesn't understand
    /// (e.g. from a newer or imported catalog) rather than failing the whole entry.
    package func decodeEffects(_ key: Key) throws -> [Effect] {
        try decode(key, default: [Lossy<Effect>]()).compactMap(\.value)
    }
}

/// Decodes a value if it can, or `nil` if it can't, without failing the surrounding list.
private struct Lossy<Value: Decodable>: Decodable {
    package let value: Value?

    package init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

// MARK: - Grouping by book

/// A book's entries in one group, for pickers that lay out their own rows.
package struct CatalogBookSection<Entry: CatalogEntry>: Identifiable {
    package var id: String { book.id + "/" + title }
    package let book: Book
    package let title: String
    package let entries: [Entry]
    /// Whether it's the first section of its book, which carries the book's heading.
    package let startsBook: Bool

    /// Every book in catalog order, and within each the groups that have entries from it, in the order given.
    package static func sections(_ groups: [CatalogPickerGroup<Entry>], books: [Book]) -> [CatalogBookSection] {
        books.flatMap { book in
            let inBook = groups.map { group in (group, group.entries.filter { $0.source.book == book.id }) }
                .filter { !$0.1.isEmpty }
            return inBook.enumerated().map { index, pair in
                CatalogBookSection(
                    book: book,
                    title: pair.0.title,
                    entries: pair.1,
                    startsBook: index == 0
                )
            }
        }
    }
}

/// Entries that share a heading within each book, e.g. a clan's in-clan Disciplines. An empty title shows just the
/// book's heading.
package struct CatalogPickerGroup<Entry: CatalogEntry> {
    package let title: String
    package let entries: [Entry]

    package init(_ title: String, _ entries: [Entry]) {
        self.title = title
        self.entries = entries
    }
}

