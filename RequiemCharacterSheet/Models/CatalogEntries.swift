//
//  CatalogEntries.swift
//  RequiemCharacterSheet
//

import Foundation

/// Identifies a catalog entry within its kind, e.g. "vigor" or "defensive-combat". Stable across versions.
typealias CatalogEntryID = String

/// Anything listed in a catalog: a Discipline, Merit, Bane, Clan, Covenant, ritual, Devotion, Mystery or Scale.
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
    /// Always-on effects on the sheet, e.g. Fleet of Foot adding to Speed.
    let effects: [Effect]
    /// Kindred can't take it: the Supernatural Merits, and Vice-Ridden and Virtuous, since vampires
    /// have no Virtue or Vice (Vampire: The Requiem p. 81).
    let unavailableToKindred: Bool

    enum Category: String, Decodable {
        case mental, physical, social, fighting, vampire, covenant, supernatural, other
    }

    enum CodingKeys: CodingKey {
        case id, name, category, source, ratings, qualifier, repeatable
        case prerequisites, prerequisitesAnyOf, styleManeuvers, summary, effects, unavailableToKindred
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
        effects = try container.decodeEffects(.effects)
        unavailableToKindred = try container.decode(.unavailableToKindred, default: false)
    }
}

struct QualifierRule: Decodable {
    /// What the player is asked for, e.g. "Skill" or "Language".
    let prompt: String
    /// The allowed choices, if limited.
    let options: [String]?
    /// The choices are the character's Skill Specialties, e.g. for Area of Expertise.
    let fromSpecialties: Bool?
}

struct Prerequisite: Decodable {
    let kind: Kind
    /// The attribute, skill, merit, discipline, clan or covenant id.
    let id: String?
    let minimum: Int?
    /// For prerequisites that can't be checked automatically.
    let text: String?

    enum Kind: String, Decodable {
        /// `notCovenant`: not a member of the covenant, e.g. Casual User for non-Carthians.
        /// `willpower`: Willpower dots (Resolve + Composure), e.g. Mobilize Outrage.
        case attribute, skill, merit, discipline, bloodPotency, clan, covenant, notCovenant, willpower, other
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
    let cost: Cost
    let dicePool: DicePool?
    let action: String?
    let duration: String?
    let summary: String

    enum CodingKeys: CodingKey {
        case id, name, mystery, source, prerequisiteCoils, cost, dicePool, action, duration, summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        mystery = try container.decode(String.self, forKey: .mystery)
        source = try container.decode(SourceReference.self, forKey: .source)
        prerequisiteCoils = try container.decode(.prerequisiteCoils, default: [])
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

// MARK: - Conditions

/// A Condition, e.g. Swooning: what it does, how it's resolved, and what earns a Beat while it lasts.
struct ConditionEntry: CatalogEntry {
    let id: CatalogEntryID
    let name: String
    let source: SourceReference
    /// Lasts until resolved, and usually earns Beats along the way.
    let persistent: Bool
    /// What it does, in our own words.
    let summary: String
    let resolution: String
    /// How it earns a Beat while it lasts; `nil` when it doesn't.
    let beat: String?
    let possibleSources: String?
    /// Resolving it earns a Beat. A few say they don't, e.g. Distracted.
    let beatOnResolve: Bool
    /// A character can have it more than once, e.g. Swooning for two people.
    let repeatable: Bool
    /// What the note on the sheet is for, e.g. "For" (whom) or "Addicted to"; `nil` if it has none.
    let notePrompt: String?
    /// It has a growing penalty, shown as "Tempted −3".
    let counter: Bool
    /// The traits it clearly affects, marked on the sheet. Situational effects aren't listed.
    let affects: [ConditionEffect]

    enum CodingKeys: CodingKey {
        case id, name, source, persistent, summary, resolution, beat, possibleSources, beatOnResolve, repeatable
        case notePrompt, counter, affects
    }

    init(from decoder: Decoder) throws {
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
struct ConditionEffect: Decodable, Equatable {
    let targets: [ConditionTarget]
    let text: String

    enum CodingKeys: CodingKey {
        case targets, text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Targets this version doesn't know are skipped, so a newer catalog still loads
        targets = try container.decode([String].self, forKey: .targets).compactMap(ConditionTarget.init)
        text = try container.decode(String.self, forKey: .text)
    }
}

/// A trait or group of traits a Condition affects. Saved as "attribute:stamina", "skill:intimidation",
/// "attributeCategory:social", "skillCategory:physical" or "defense".
enum ConditionTarget: Equatable, Hashable {
    case attribute(AttributeKind)
    case skill(SkillID)
    case attributeCategory(TraitCategory)
    case skillCategory(TraitCategory)
    case defense

    init?(_ text: String) {
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
enum Effect: Decodable, Equatable {
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
    init(from decoder: Decoder) throws {
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
enum Amount: Decodable, Equatable {
    /// The Discipline's or Merit's dots.
    case rating
    case fixed(Int)

    private enum CodingKeys: CodingKey {
        case fixed
    }

    /// Saved as "rating" or {"fixed": 1}.
    init(from decoder: Decoder) throws {
        if let text = try? decoder.singleValueContainer().decode(String.self), text == "rating" {
            self = .rating
        } else {
            self = .fixed(try decoder.container(keyedBy: CodingKeys.self).decode(Int.self, forKey: .fixed))
        }
    }

    func value(forRating rating: Int) -> Int {
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
    func decodeEffects(_ key: Key) throws -> [Effect] {
        try decode(key, default: [Lossy<Effect>]()).compactMap(\.value)
    }
}

/// Decodes a value if it can, or `nil` if it can't, without failing the surrounding list.
private struct Lossy<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}
