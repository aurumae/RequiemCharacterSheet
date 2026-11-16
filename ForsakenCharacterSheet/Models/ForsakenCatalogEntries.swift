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
    /// The power every member of the auspice has, e.g. the Cahalith's Prophetic Dreams.
    let benefit: Benefit?

    struct Benefit: Decodable {
        let name: String
        let summary: String
        let page: Int?
    }
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
    /// `nil` for Ghost Wolves.
    let renown: Renown?
    /// For the Pure, the Renowns their second starting dot can go to as well as `renown`.
    let secondaryRenown: [Renown]?
    /// For the Pure, the tribe Skills, in place of an auspice's.
    let skills: [SkillID]?
    /// For the Pure, the two Hunter's Aspects a member chooses between, in place of an auspice's.
    let huntersAspects: [AuspiceEntry.HuntersAspect]?
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
    enum Kind: String, Codable {
        case moon, shadow, wolf
    }

    struct Facet: CatalogEntry {
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
        /// What it does to the sheet's traits, with "rating" meaning dots of its Renown, e.g. Primal Strength
        /// adding Purity to Strength. See `PowerEffects`.
        let effects: [Effect]?
        /// The effects always apply, e.g. Warrior's Hide; otherwise the player switches them on while it's in use.
        let passive: Bool?
        /// The forms the effects apply in; `nil` for every form.
        let effectForms: [Form]?
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
    /// What it does to the sheet's traits while it lasts, switched on by the player; "rating" is the rite's dots.
    let effects: [Effect]?
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

/// One of the book's sets of Kuruth triggers (p. 103), each with what sets it off at each level of Harmony.
struct KuruthTriggerSetEntry: CatalogEntry {
    let id: CatalogEntryID
    let name: String
    let source: SourceReference
    let summary: String
    let passive: String
    let common: String
    let specific: String
}

/// A Tilt (pp. 312–313): a passing effect in a fight, on one character or on the whole scene. The sheet doesn't
/// track Tilts yet; the catalog holds them for the combat tools to come.
struct TiltEntry: CatalogEntry {
    enum Kind: String, Decodable {
        case personal, environmental
    }

    let id: CatalogEntryID
    let name: String
    let source: SourceReference
    /// What the Tilt does.
    let summary: String
    let kind: Kind
    /// How it's inflicted.
    let cause: String
    /// How it ends.
    let ending: String
}

/// Forsaken's own kinds of Merit and Merit prerequisite.
extension MeritEntry.Category {
    static let werewolf = MeritEntry.Category(rawValue: "werewolf")
    /// Merits only humans can take, e.g. the Church of the Wolf's.
    static let human = MeritEntry.Category(rawValue: "human")
}

extension Prerequisite.Kind {
    static let renown = Prerequisite.Kind(rawValue: "renown")
    static let primalUrge = Prerequisite.Kind(rawValue: "primalUrge")
    static let harmony = Prerequisite.Kind(rawValue: "harmony")
    static let tribe = Prerequisite.Kind(rawValue: "tribe")
    static let notTribe = Prerequisite.Kind(rawValue: "notTribe")
    static let auspice = Prerequisite.Kind(rawValue: "auspice")
}
