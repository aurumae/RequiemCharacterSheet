//
//  ForsakenCatalogEntries.swift
//  ForsakenCharacterSheet
//
//  The kinds of entry in a Forsaken catalog file; see docs/forsaken-catalog-format.md.
//

import Foundation

/// The five Renowns, in the book's order.
enum Renown: String, Codable, CaseIterable, Identifiable {
    case cunning, glory, honor, purity, wisdom

    var id: Self { self }

    var name: String {
        rawValue.capitalized
    }
}

struct AuspiceEntry: CatalogEntry {
    struct HuntersAspect: Decodable {
        let name: String
        /// The Condition it inflicts.
        let condition: CatalogEntryID
    }

    let id: CatalogEntryID
    let name: String
    let source: SourceReference
    let summary: String
    /// e.g. "crescent".
    let moon: String
    let renown: Renown
    let skills: [SkillID]
    let huntersAspect: HuntersAspect
    let moonGift: CatalogEntryID
    let giftAffinities: [CatalogEntryID]
}

struct TribeEntry: CatalogEntry {
    enum Kind: String, Decodable {
        case forsaken
        case ghostWolf = "ghost-wolf"
        case pure
    }

    struct Oath: Decodable {
        let name: String
        let summary: String
    }

    let id: CatalogEntryID
    let name: String
    let source: SourceReference
    let summary: String
    let kind: Kind
    /// `nil` for Ghost Wolves and the Pure.
    let renown: Renown?
    let giftAffinities: [CatalogEntryID]
    let oath: Oath?
    let firstTongueName: String?
}

struct LodgeEntry: CatalogEntry {
    let id: CatalogEntryID
    let name: String
    let source: SourceReference
    let summary: String
    /// The tribes and auspices it admits; `nil` or empty for any.
    let tribes: [CatalogEntryID]?
    let auspices: [CatalogEntryID]?
    let requirements: String?
    let benefit: String?
}

/// A Blood or Bone archetype.
struct ArchetypeEntry: CatalogEntry {
    enum Kind: String, Decodable {
        case blood, bone
    }

    let id: CatalogEntryID
    let name: String
    let source: SourceReference
    let summary: String
    let kind: Kind
}

struct GiftEntry: CatalogEntry {
    enum Kind: String, Decodable {
        case moon, shadow, wolf
    }

    struct Facet: Decodable, Identifiable {
        let id: CatalogEntryID
        let name: String
        let source: SourceReference
        let summary: String
        /// The Renown it's learned with (Shadow and Wolf Gifts).
        let renown: Renown?
        /// Its place in a Moon Gift, 1–5.
        let dots: Int?
        let cost: String?
        let action: String?
        let dicePool: String?
        let duration: String?
    }

    let id: CatalogEntryID
    let name: String
    let source: SourceReference
    let summary: String
    let kind: Kind
    /// The auspice whose Moon Gift it is.
    let auspice: CatalogEntryID?
    let facets: [Facet]
}

struct RiteEntry: CatalogEntry {
    enum Kind: String, Decodable {
        case wolf, pack
    }

    let id: CatalogEntryID
    let name: String
    let source: SourceReference
    let summary: String
    let kind: Kind
    let rating: Int
    let action: String?
    let dicePool: String?
    let targetSuccesses: Int?
    let duration: String?
}

struct FetishEntry: CatalogEntry {
    enum Kind: String, Decodable {
        case fetish, talen
    }

    let id: CatalogEntryID
    let name: String
    let source: SourceReference
    let summary: String
    let kind: Kind
    let rating: Int
    let spirit: String?
    let activation: String?
    let effect: String?
}

/// Forsaken's own kinds of Merit and Merit prerequisite.
extension MeritEntry.Category {
    static let werewolf = MeritEntry.Category(rawValue: "werewolf")
}

extension Prerequisite.Kind {
    static let renown = Prerequisite.Kind(rawValue: "renown")
    static let primalUrge = Prerequisite.Kind(rawValue: "primalUrge")
    static let harmony = Prerequisite.Kind(rawValue: "harmony")
    static let tribe = Prerequisite.Kind(rawValue: "tribe")
    static let notTribe = Prerequisite.Kind(rawValue: "notTribe")
    static let auspice = Prerequisite.Kind(rawValue: "auspice")
}
