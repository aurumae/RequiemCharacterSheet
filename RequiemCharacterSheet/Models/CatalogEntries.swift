//
//  CatalogEntries.swift
//  RequiemCharacterSheet
//

import Foundation
#if SWIFT_PACKAGE
import ChroniclesCore
#endif

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
    let bloodlines: [BloodlineEntry]
    let covenants: [CovenantEntry]
    let rituals: [RitualEntry]
    let devotions: [DevotionEntry]
    let mysteries: [MysteryEntry]
    let scales: [ScaleEntry]
    let archetypes: [ArchetypeEntry]
    let conditions: [ConditionEntry]
    let elderBanes: [ElderBaneEntry]

    enum CodingKeys: CodingKey {
        case format, version, book, disciplines, merits, banes, clans, bloodlines, covenants
        case rituals, devotions, mysteries, scales, archetypes, conditions, elderBanes
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
        bloodlines = try container.decode(.bloodlines, default: [])
        covenants = try container.decode(.covenants, default: [])
        rituals = try container.decode(.rituals, default: [])
        devotions = try container.decode(.devotions, default: [])
        mysteries = try container.decode(.mysteries, default: [])
        scales = try container.decode(.scales, default: [])
        archetypes = try container.decode(.archetypes, default: [])
        conditions = try container.decode(.conditions, default: [])
        elderBanes = try container.decode(.elderBanes, default: [])
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
    /// Always-on effects on the sheet, e.g. Vigor adding its dots to Strength.
    let effects: [Effect]
    /// For Ritual Disciplines (Crúac, Theban Sorcery): who may learn it and how its rituals work.
    let ritualRules: RitualRules?
    /// The bloodline it belongs to, for a Discipline only that bloodline can learn, e.g. Cachexy for the Morbus.
    let bloodline: CatalogEntryID?

    enum CodingKeys: CodingKey {
        case id, name, kind, source, summary, powers, effects, ritualRules, bloodline
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        kind = try container.decode(Kind.self, forKey: .kind)
        source = try container.decode(SourceReference.self, forKey: .source)
        summary = try container.decode(String.self, forKey: .summary)
        powers = try container.decode(.powers, default: [])
        effects = try container.decodeEffects(.effects)
        ritualRules = try container.decodeIfPresent(RitualRules.self, forKey: .ritualRules)
        bloodline = try container.decodeIfPresent(CatalogEntryID.self, forKey: .bloodline)
    }

    enum Kind: String, Decodable {
        /// One named power per dot, e.g. Dominate.
        case powers
        /// One entry whose effect grows with dots, e.g. Vigor.
        case scaling
        /// No powers of its own; its dots let the vampire learn and cast rituals. Crúac, Theban Sorcery.
        case ritual
    }
}

/// How a Ritual Discipline is learned and cast (Vampire: The Requiem pp. 150–152).
struct RitualRules: Decodable {
    /// The covenant that teaches it.
    let covenant: CatalogEntryID
    /// The Status in that covenant needed to learn new rituals.
    let covenantStatusMinimum: Int
    /// How the Discipline limits Humanity.
    let humanity: HumanityRule
    /// What casting a ritual costs.
    let castingCost: Cost
    let castingPool: DicePool

    enum HumanityRule: String, Decodable {
        /// Humanity can't rise above 10 minus the Discipline's dots, and learning a dot is a breaking point
        /// at Humanity 4 or higher. Crúac.
        case capAtTenMinusDots
        /// Casting a ritual needs Humanity at least equal to its dots. Theban Sorcery.
        case atLeastRitualDots
        /// No Humanity limit. Kimiya.
        case none
        /// Casting a ritual is a breaking point at Humanity 6 minus its dots or higher. Therion.
        case breakingPointAtSixMinusDots
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

    enum CodingKeys: CodingKey {
        case vitae, willpower, optional, note
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vitae = try container.decodeIfPresent(CostAmount.self, forKey: .vitae)
        willpower = try container.decodeIfPresent(CostAmount.self, forKey: .willpower)
        optional = try container.decode(.optional, default: false)
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }
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
    /// Adds the dots of the Discipline the power belongs to.
    let includesDiscipline: Bool
    /// Adds the dots of this Discipline, for powers that don't belong to one, e.g. a Devotion.
    let discipline: CatalogEntryID?
    /// How the target resists, as the book states it.
    let resistance: String?
    /// For pools that don't fit the usual shape.
    let text: String?

    enum CodingKeys: CodingKey {
        case attribute, skill, includesDiscipline, discipline, resistance, text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attribute = try container.decodeIfPresent(AttributeKind.self, forKey: .attribute)
        skill = try container.decodeIfPresent(SkillID.self, forKey: .skill)
        includesDiscipline = try container.decode(.includesDiscipline, default: false)
        discipline = try container.decodeIfPresent(CatalogEntryID.self, forKey: .discipline)
        resistance = try container.decodeIfPresent(String.self, forKey: .resistance)
        text = try container.decodeIfPresent(String.self, forKey: .text)
    }
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
    /// Another clan's Merits its members may take.
    let meritAccess: [ClanMeritAccess]

    enum CodingKeys: CodingKey {
        case id, name, nickname, source, favoredAttributes, disciplines, bane, summary, meritAccess
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        source = try container.decode(SourceReference.self, forKey: .source)
        favoredAttributes = try container.decode([AttributeKind].self, forKey: .favoredAttributes)
        disciplines = try container.decode([CatalogEntryID].self, forKey: .disciplines)
        bane = try container.decode(ClanBane.self, forKey: .bane)
        summary = try container.decode(String.self, forKey: .summary)
        meritAccess = try container.decode(.meritAccess, default: [])
    }
}

struct ClanBane: Decodable {
    let name: String
    let summary: String
    /// Takes effect when Humanity first falls to this, if the book gives one.
    let humanityThreshold: Int?
    let page: Int?
    /// The bane gives the vampire an extra Bane from the list, which counts toward the limit of three (Mekhet).
    let grantsExtraBane: Bool
    /// The Humanity dot the first Touchstone goes on: 7 for the Ventrue, whose bane moves it, otherwise 6.
    let firstTouchstoneHumanity: Int

    enum CodingKeys: CodingKey {
        case name, summary, humanityThreshold, page, grantsExtraBane, firstTouchstoneHumanity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        summary = try container.decode(String.self, forKey: .summary)
        humanityThreshold = try container.decodeIfPresent(Int.self, forKey: .humanityThreshold)
        page = try container.decodeIfPresent(Int.self, forKey: .page)
        grantsExtraBane = try container.decode(.grantsExtraBane, default: false)
        firstTouchstoneHumanity = try container.decode(.firstTouchstoneHumanity, default: 6)
    }
}

/// How a clan's bane deepens in an elder (A Thousand Years of Night p. 23): it takes hold when Humanity first falls
/// to the threshold, and regaining Humanity doesn't undo it.
struct ElderBaneEntry: CatalogEntry {
    let id: CatalogEntryID
    let name: String
    /// The clan whose bane this deepens.
    let clan: CatalogEntryID
    let source: SourceReference
    let summary: String
    let humanityThreshold: Int
}

/// A bloodline: a lineage within a clan, with its own Disciplines and bane.
struct BloodlineEntry: CatalogEntry {
    let id: CatalogEntryID
    let name: String
    let nickname: String?
    /// The clans it descends from.
    let parentClans: [CatalogEntryID]
    let source: SourceReference
    let summary: String
    /// In-clan Disciplines for its members, in place of the parent clan's.
    let disciplines: [CatalogEntryID]
    /// Suffered as well as the parent clan's bane.
    let bane: BloodlineBane
    /// Its own favoured Attributes, if the book gives them, e.g. the Bron's. Empty if it uses the clan's.
    let favoredAttributes: [AttributeKind]
    /// The covenant its members must belong to, if any, e.g. the Penumbrae's Circle of the Crone.
    let requiredCovenant: CatalogEntryID?
    /// Another clan's Merits its members may take, e.g. the Icelus with Dream Visions as though Mekhet.
    let meritAccess: [ClanMeritAccess]

    enum CodingKeys: CodingKey {
        case id, name, nickname, parentClans, source, summary, disciplines, bane, favoredAttributes, requiredCovenant, meritAccess
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        parentClans = try container.decode([CatalogEntryID].self, forKey: .parentClans)
        source = try container.decode(SourceReference.self, forKey: .source)
        summary = try container.decode(String.self, forKey: .summary)
        disciplines = try container.decode([CatalogEntryID].self, forKey: .disciplines)
        bane = try container.decode(BloodlineBane.self, forKey: .bane)
        favoredAttributes = try container.decode(.favoredAttributes, default: [])
        requiredCovenant = try container.decodeIfPresent(CatalogEntryID.self, forKey: .requiredCovenant)
        meritAccess = try container.decode(.meritAccess, default: [])
    }
}

struct BloodlineBane: Decodable {
    let name: String
    let summary: String
    let page: Int?
}

struct CovenantEntry: CatalogEntry {
    let id: CatalogEntryID
    let name: String
    let nickname: String?
    let source: SourceReference
    let summary: String
    /// Families of another covenant's Merits its members may take, e.g. the Gallows Post's use of Carthian Laws.
    let meritGroups: [CovenantMeritGroup]
    /// Another covenant whose Status this covenant's Status counts as, for everything that asks for it, e.g. the
    /// Legion of the Green's for the Invictus (Dark Eras 2 p. 108).
    let statusCountsAs: CatalogEntryID?
    /// Ritual Disciplines it teaches besides the one whose `ritualRules` names it, with the same Status, e.g. the Ahl
    /// al-Mumit's Karamat, which is Theban Sorcery (Dark Eras 2 p. 139).
    let teaches: [CatalogEntryID]

    enum CodingKeys: CodingKey {
        case id, name, nickname, source, summary, meritGroups, statusCountsAs, teaches
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        source = try container.decode(SourceReference.self, forKey: .source)
        summary = try container.decode(String.self, forKey: .summary)
        meritGroups = try container.decode(.meritGroups, default: [])
        statusCountsAs = try container.decodeIfPresent(CatalogEntryID.self, forKey: .statusCountsAs)
        teaches = try container.decode(.teaches, default: [])
    }
}

/// Members may take the Merits in `group`, or those listed in `merits`, with their own Covenant Status standing in
/// for Status in `inPlaceOf`, e.g. Gallows Post Status for the Carthian Laws' Carthian Status (Dark Eras Companion
/// p. 93), or the Fir'awn's for Altar (Dark Eras 2 p. 142).
struct CovenantMeritGroup: Decodable, Equatable {
    let group: String?
    let merits: [CatalogEntryID]
    let inPlaceOf: CatalogEntryID

    enum CodingKeys: CodingKey {
        case group, merits, inPlaceOf
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        group = try container.decodeIfPresent(String.self, forKey: .group)
        merits = try container.decode(.merits, default: [])
        inPlaceOf = try container.decode(CatalogEntryID.self, forKey: .inPlaceOf)
    }

    /// Whether it covers this Merit.
    func covers(_ merit: MeritEntry) -> Bool {
        (group != nil && group == merit.group) || merits.contains(merit.id)
    }
}

/// Members of a clan may take these Merits as though they were of the clan `inPlaceOf`, e.g. the Dukhan with Dream
/// Visions as though Mekhet (Dark Eras 2 p. 142).
struct ClanMeritAccess: Decodable, Equatable {
    let merits: [CatalogEntryID]
    let inPlaceOf: CatalogEntryID
}

// MARK: - Blood sorcery, Devotions, Coils and Scales

/// A Crúac rite or Theban miracle.
struct RitualEntry: CatalogEntry {
    let id: CatalogEntryID
    let name: String
    /// The Ritual Discipline that casts it, e.g. "cruac".
    let discipline: CatalogEntryID
    let dots: Int
    let source: SourceReference
    let targetSuccesses: Int
    /// The victim's contesting pool, if the ritual is contested.
    let contestedBy: String?
    /// The victim's resistance, if the ritual is resisted.
    let resistedBy: String?
    /// The object a Theban miracle consumes.
    let sacrament: String?
    let summary: String
}

/// A power that combines Disciplines, learned for a set number of Experiences.
struct DevotionEntry: CatalogEntry {
    let id: CatalogEntryID
    let name: String
    let source: SourceReference
    /// The Discipline dots needed to learn it.
    let prerequisites: [Prerequisite]
    /// Alternative sets of prerequisites, any one of which is enough.
    let prerequisitesAnyOf: [[Prerequisite]]
    let cost: Cost
    let dicePool: DicePool?
    let action: String?
    let duration: String?
    /// Anything else needed to use it, in brief.
    let requirement: String?
    let experienceCost: Int
    let summary: String

    enum CodingKeys: CodingKey {
        case id, name, source, prerequisites, prerequisitesAnyOf, cost, dicePool
        case action, duration, requirement, experienceCost, summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        source = try container.decode(SourceReference.self, forKey: .source)
        prerequisites = try container.decode(.prerequisites, default: [])
        prerequisitesAnyOf = try container.decode(.prerequisitesAnyOf, default: [])
        cost = try container.decode(.cost, default: Cost())
        dicePool = try container.decodeIfPresent(DicePool.self, forKey: .dicePool)
        action = try container.decodeIfPresent(String.self, forKey: .action)
        duration = try container.decodeIfPresent(String.self, forKey: .duration)
        requirement = try container.decodeIfPresent(String.self, forKey: .requirement)
        experienceCost = try container.decode(Int.self, forKey: .experienceCost)
        summary = try container.decode(String.self, forKey: .summary)
    }
}

/// An Ordo Dracul Mystery and its Coil, a ladder of five tiers.
struct MysteryEntry: CatalogEntry {
    let id: CatalogEntryID
    let name: String
    let source: SourceReference
    let summary: String
    let coil: CoilInfo
    /// One per dot, in order.
    let tiers: [CoilTier]
    /// A Coil without a Mystery to follow, e.g. the Coil of Zirnitra: it can be learned as a Coil, with its
    /// Scales, but isn't offered as the character's Mystery.
    let coilOnly: Bool
    /// The Mystery this Coil counts as part of, for Experience costs and the Status limit, e.g. the Coil of the
    /// Quintessence is part of the Mystery of the Voivode.
    let partOfMystery: CatalogEntryID?

    enum CodingKeys: CodingKey {
        case id, name, source, summary, coil, tiers, coilOnly, partOfMystery
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        source = try container.decode(SourceReference.self, forKey: .source)
        summary = try container.decode(String.self, forKey: .summary)
        coil = try container.decode(CoilInfo.self, forKey: .coil)
        tiers = try container.decode([CoilTier].self, forKey: .tiers)
        coilOnly = try container.decode(.coilOnly, default: false)
        partOfMystery = try container.decodeIfPresent(CatalogEntryID.self, forKey: .partOfMystery)
    }

    func tier(_ dots: Int) -> CoilTier? {
        tiers.first { $0.dots == dots }
    }
}

struct CoilInfo: Decodable {
    /// e.g. "Coil of the Ascendant".
    let name: String
    let summary: String
}

struct CoilTier: Decodable, Identifiable {
    let id: CatalogEntryID
    let dots: Int
    let name: String
    let page: Int?
    let summary: String
}

/// An Ordo Dracul technique that shares a Coil's insight with others.
struct ScaleEntry: CatalogEntry {
    let id: CatalogEntryID
    let name: String
    /// The Mystery it belongs to.
    let mystery: CatalogEntryID
    let source: SourceReference
    /// The Coil tiers it resonates with. Learning it costs less with one of them.
    let prerequisiteCoils: [CoilPrerequisite]
    /// Resonates with any Coil at this many dots, for Scales outside the Mysteries, e.g. Spirit Tether.
    let anyCoil: Int?
    let cost: Cost
    let dicePool: DicePool?
    let action: String?
    let duration: String?
    let summary: String

    enum CodingKeys: CodingKey {
        case id, name, mystery, source, prerequisiteCoils, anyCoil, cost, dicePool, action, duration, summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        mystery = try container.decode(String.self, forKey: .mystery)
        source = try container.decode(SourceReference.self, forKey: .source)
        prerequisiteCoils = try container.decode(.prerequisiteCoils, default: [])
        anyCoil = try container.decodeIfPresent(Int.self, forKey: .anyCoil)
        cost = try container.decode(.cost, default: Cost())
        dicePool = try container.decodeIfPresent(DicePool.self, forKey: .dicePool)
        action = try container.decodeIfPresent(String.self, forKey: .action)
        duration = try container.decodeIfPresent(String.self, forKey: .duration)
        summary = try container.decode(String.self, forKey: .summary)
    }
}

/// A Coil tier, e.g. the Mystery of the Ascendant's first tier.
struct CoilPrerequisite: Decodable, Equatable {
    let mystery: CatalogEntryID
    /// The tier's id, for reference.
    let tier: CatalogEntryID
    let dots: Int
}

// MARK: - Masks and Dirges

/// A sample Mask or Dirge archetype, e.g. Authoritarian. Players may also write their own.
struct ArchetypeEntry: CatalogEntry {
    let id: CatalogEntryID
    let name: String
    let source: SourceReference
    /// Usually empty: the book's descriptions are too short to summarise, so the Willpower actions stand in.
    let summary: String
    /// A sample action that regains one Willpower.
    let singleWillpower: String?
    /// A sample action that regains all Willpower, once per chapter.
    let allWillpower: String?

    enum CodingKeys: CodingKey {
        case id, name, source, summary, singleWillpower, allWillpower
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        source = try container.decode(SourceReference.self, forKey: .source)
        summary = try container.decode(.summary, default: "")
        singleWillpower = try container.decodeIfPresent(String.self, forKey: .singleWillpower)
        allWillpower = try container.decodeIfPresent(String.self, forKey: .allWillpower)
    }

    /// The sample Willpower actions, e.g. "Single Willpower: Abandon a home."
    var willpowerFacts: [(label: String, value: String)] {
        [("Single Willpower", singleWillpower), ("All Willpower", allWillpower)].compactMap { label, value in
            value.map { (label, $0) }
        }
    }
}


// MARK: - Requiem's Merit categories and requirement kinds

extension MeritEntry.Category {
    static let vampire = MeritEntry.Category(rawValue: "vampire")
    static let covenant = MeritEntry.Category(rawValue: "covenant")
}

extension Prerequisite.Kind {
    static let discipline = Prerequisite.Kind(rawValue: "discipline")
    static let bloodPotency = Prerequisite.Kind(rawValue: "bloodPotency")
    static let clan = Prerequisite.Kind(rawValue: "clan")
    /// Being of that bloodline, e.g. the Lidérc's Devotions.
    static let bloodline = Prerequisite.Kind(rawValue: "bloodline")
    /// Covenant Status, or membership when no minimum is given.
    static let covenant = Prerequisite.Kind(rawValue: "covenant")
    /// Not a member of the covenant, e.g. Casual User for non-Carthians.
    static let notCovenant = Prerequisite.Kind(rawValue: "notCovenant")
}
