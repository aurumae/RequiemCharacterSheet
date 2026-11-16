//
//  WerewolfTraits.swift
//  ForsakenCharacterSheet
//
//  The traits only werewolves have: forms, Primal Urge, Kuruth triggers, and the Gift Facets, Rites and fetishes
//  a character knows or carries.
//

import Foundation
import Observation

/// Forsaken's kinds of trait in the change log, alongside the shared Attributes, Skills, Specialties, Merits and
/// Conditions.
extension TraitKind {
    static let renown = TraitKind("renown")
    static let facet = TraitKind("facet")
    static let rite = TraitKind("rite")
    static let primalUrge = TraitKind("primalUrge")
}

// MARK: - Forms

/// The five forms (pp. 96–98).
enum Form: String, Codable, CaseIterable, Identifiable {
    case hishu, dalu, gauru, urshul, urhan

    var id: Self { self }

    var name: String {
        rawValue.capitalized
    }

    /// e.g. "Human", "Near-Human".
    var description: String {
        switch self {
        case .hishu: "Human"
        case .dalu: "Near-Human"
        case .gauru: "Wolf-Man"
        case .urshul: "Near-Wolf"
        case .urhan: "Wolf"
        }
    }

    /// Changes to Attributes in this form.
    var attributeModifiers: [AttributeKind: Int] {
        switch self {
        case .hishu: [:]
        case .dalu: [.strength: 1, .stamina: 1, .manipulation: -1]
        case .gauru: [.strength: 3, .dexterity: 1, .stamina: 2]
        case .urshul: [.strength: 2, .dexterity: 2, .stamina: 2, .manipulation: -1]
        case .urhan: [.dexterity: 2, .stamina: 1, .manipulation: -1]
        }
    }

    var sizeModifier: Int {
        switch self {
        case .hishu: 0
        case .dalu: 1
        case .gauru: 2
        case .urshul: 1
        case .urhan: -1
        }
    }

    /// The species' Speed factor added to Speed: wolves are faster than people.
    var speciesSpeedBonus: Int {
        switch self {
        case .urshul, .urhan: 3
        default: 0
        }
    }

    /// Dice added to Perception rolls in this form.
    var perceptionBonus: Int {
        switch self {
        case .hishu: 1
        case .dalu: 2
        case .gauru, .urshul: 3
        case .urhan: 4
        }
    }

    /// What else the form brings, in brief.
    var notes: String {
        switch self {
        case .hishu: "Perception bonus only with wolf senses. Sheep's Clothing."
        case .dalu: "Lunacy (witnesses +2). Claws do lethal damage; Defense applies against Firearms."
        case .gauru: "Lunacy (witnesses −2). Claws and bite +2L; Initiative +3 with teeth or claws; regenerates bashing and lethal damage each turn; Primal Fear. Fails Social rolls except Intimidation and Mental rolls except Perception and resistance. Held for Stamina + Primal Urge turns, once per scene."
        case .urshul: "Lunacy. Claws +1L, bite +2L; Weaken the Prey."
        case .urhan: "Bite +1L; Chase Down."
        }
    }

    /// The book's page.
    var page: Int {
        switch self {
        case .hishu, .dalu: 96
        case .gauru, .urshul: 97
        case .urhan: 97
        }
    }
}

// MARK: - Primal Urge

/// One row of the Primal Urge table (p. 93).
struct PrimalUrgeLevel {
    /// The highest an Attribute or Skill can go.
    let traitMaximum: Int
    let essenceMaximum: Int
    let essencePerTurn: Int
    /// Bashing damage healed per turn.
    let regeneration: Int
    let feeding: String
    let lunacyPenalty: Int
    let trackingBonus: Int

    static let table: [PrimalUrgeLevel] = [
        PrimalUrgeLevel(traitMaximum: 5, essenceMaximum: 10, essencePerTurn: 1, regeneration: 1, feeding: "None", lunacyPenalty: 0, trackingBonus: 0),
        PrimalUrgeLevel(traitMaximum: 5, essenceMaximum: 11, essencePerTurn: 2, regeneration: 1, feeding: "Meat", lunacyPenalty: 0, trackingBonus: 0),
        PrimalUrgeLevel(traitMaximum: 5, essenceMaximum: 12, essencePerTurn: 3, regeneration: 1, feeding: "Meat", lunacyPenalty: 0, trackingBonus: 0),
        PrimalUrgeLevel(traitMaximum: 5, essenceMaximum: 13, essencePerTurn: 4, regeneration: 2, feeding: "Raw meat", lunacyPenalty: -2, trackingBonus: 1),
        PrimalUrgeLevel(traitMaximum: 5, essenceMaximum: 15, essencePerTurn: 5, regeneration: 2, feeding: "Raw meat", lunacyPenalty: -2, trackingBonus: 1),
        PrimalUrgeLevel(traitMaximum: 6, essenceMaximum: 20, essencePerTurn: 6, regeneration: 3, feeding: "Carnivore", lunacyPenalty: -2, trackingBonus: 2),
        PrimalUrgeLevel(traitMaximum: 7, essenceMaximum: 25, essencePerTurn: 7, regeneration: 3, feeding: "Carnivore", lunacyPenalty: -2, trackingBonus: 2),
        PrimalUrgeLevel(traitMaximum: 8, essenceMaximum: 30, essencePerTurn: 8, regeneration: 4, feeding: "Essence", lunacyPenalty: -3, trackingBonus: 3),
        PrimalUrgeLevel(traitMaximum: 9, essenceMaximum: 50, essencePerTurn: 10, regeneration: 5, feeding: "Essence", lunacyPenalty: -4, trackingBonus: 3),
        PrimalUrgeLevel(traitMaximum: 10, essenceMaximum: 75, essencePerTurn: 15, regeneration: 6, feeding: "Essence", lunacyPenalty: -5, trackingBonus: 4),
    ]

    /// The row for a Primal Urge rating, 1–10.
    static func level(_ primalUrge: Int) -> PrimalUrgeLevel {
        table[min(max(primalUrge, 1), table.count) - 1]
    }
}

// MARK: - Kuruth

/// The things that can drive the character into Death Rage (p. 103): one set's passive, common and specific
/// triggers. A set from the book comes from the catalog; these are the player's own words for a custom set.
struct KuruthTriggers: Codable, Equatable {
    var passive = ""
    var common = ""
    var specific = ""

    /// The kinds of personal trigger, from the most to the least easily set off.
    enum Kind: String, CaseIterable, Identifiable {
        case passive, common, specific

        var id: Self { self }

        var name: String {
            rawValue.capitalized
        }

        /// Whether triggers of this kind send a werewolf into Kuruth at a level of Harmony (p. 105): every kind at 0
        /// and 10, common and specific at 1, 2, 8 and 9, only specific at 3, 4, 6 and 7, and none at 5.
        func applies(atHarmony harmony: Int) -> Bool {
            let distance = abs(harmony - 5)
            switch self {
            case .passive: return distance == 5
            case .common: return distance >= 3
            case .specific: return distance >= 1
            }
        }
    }

    /// What sets off every werewolf, whatever their Harmony and as often as it happens (p. 103).
    static let general = [
        "Spending too long in Gauru",
        "Taking Gauru outside of combat",
        "Taking damage from silver",
        "Being forced into Kuruth by an Elodoth",
    ]
}

// MARK: - Gifts, Rites and fetishes

/// A Gift Facet the character knows: a catalog Facet, or the player's own with its Gift's name.
@Observable
final class OwnedFacet: Identifiable, Codable {
    let id: UUID
    var source: TraitSource
    /// For a custom Facet, the Gift it belongs to and whether it's a Shadow or Wolf Gift.
    var customGift: String
    var customKind: GiftEntry.Kind
    /// Switched on while it's in use, for a Facet whose effects change the sheet, e.g. Primal Strength.
    var isActive: Bool
    /// Learned free with a new dot of its Renown (p. 115), so it cost no Experiences.
    var learnedWithRenown: Bool

    init(id: UUID = UUID(), source: TraitSource, customGift: String = "", customKind: GiftEntry.Kind = .shadow,
         learnedWithRenown: Bool = false) {
        self.id = id
        self.source = source
        self.customGift = customGift
        self.customKind = customKind
        self.isActive = false
        self.learnedWithRenown = learnedWithRenown
    }

    enum CodingKeys: CodingKey {
        case id, source, customGift, customKind, active, withRenown
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(source, forKey: .source)
        if source.catalogID == nil {
            try container.encode(customGift, forKey: .customGift)
            try container.encode(customKind, forKey: .customKind)
        }
        if isActive {
            try container.encode(true, forKey: .active)
        }
        if learnedWithRenown {
            try container.encode(true, forKey: .withRenown)
        }
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: UUID())
        source = try container.decode(TraitSource.self, forKey: .source)
        customGift = try container.decode(.customGift, default: "")
        customKind = try container.decode(.customKind, default: .shadow)
        isActive = try container.decode(.active, default: false)
        learnedWithRenown = try container.decode(.withRenown, default: false)
    }
}

/// A Rite the character knows: a catalog Rite, or the player's own with its rating.
@Observable
final class OwnedRite: Identifiable, Codable {
    let id: UUID
    var source: TraitSource
    /// For a custom Rite, its dots.
    var customRating: Int
    /// Switched on while it lasts, for a Rite whose effects change the sheet, e.g. Totemic Empowerment.
    var isActive = false

    init(id: UUID = UUID(), source: TraitSource, customRating: Int = 1) {
        self.id = id
        self.source = source
        self.customRating = customRating
    }

    enum CodingKeys: CodingKey {
        case id, source, customRating, active
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(source, forKey: .source)
        if source.catalogID == nil {
            try container.encode(customRating, forKey: .customRating)
        }
        if isActive {
            try container.encode(true, forKey: .active)
        }
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: UUID())
        source = try container.decode(TraitSource.self, forKey: .source)
        customRating = try container.decode(.customRating, default: 1)
        isActive = try container.decode(.active, default: false)
    }
}

/// A fetish or talen the character carries: a catalog one, or the player's own, with notes.
@Observable
final class OwnedFetish: Identifiable, Codable {
    let id: UUID
    var source: TraitSource
    /// For a custom fetish, its rating.
    var customRating: Int
    /// e.g. the spirit bound in it, or charges left in a talen.
    var note: String

    init(id: UUID = UUID(), source: TraitSource, customRating: Int = 1, note: String = "") {
        self.id = id
        self.source = source
        self.customRating = customRating
        self.note = note
    }

    enum CodingKeys: CodingKey {
        case id, source, customRating, note
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(source, forKey: .source)
        if source.catalogID == nil {
            try container.encode(customRating, forKey: .customRating)
        }
        if !note.isEmpty {
            try container.encode(note, forKey: .note)
        }
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: UUID())
        source = try container.decode(TraitSource.self, forKey: .source)
        customRating = try container.decode(.customRating, default: 1)
        note = try container.decode(.note, default: "")
    }
}

// MARK: - Totem

/// The pack's totem (pp. 92–93): a spirit whose Aspiration every pack member shares and whose ban they all keep. The
/// pack's combined Totem points buy advantages every member gains, which can break the usual rules.
struct Totem: Codable, Equatable {
    var name = ""
    var aspiration = ""
    var ban = ""
    /// Every pack member's Totem dots added up. Players enter it, as only their own character is on the sheet.
    var packPoints = 0
    var advantages: [TotemAdvantage] = []

    /// The Experiences the pack has to buy advantages with (p. 92).
    var experienceBudget: Int {
        switch packPoints {
        case ..<1: 0
        case 1...8: 1
        case 9...14: 3
        case 15...20: 5
        default: 10
        }
    }

    /// The Experiences the advantages cost, as if bought by a werewolf (p. 84).
    var experiencesSpent: Int {
        advantages.reduce(0) { $0 + $1.cost }
    }

    /// Dots the advantages add to an Attribute or Skill.
    func dots(for kind: TotemAdvantage.Kind, _ target: String) -> Int {
        advantages.filter { $0.kind == kind && $0.target == target }.reduce(0) { $0 + $1.dots }
    }

    init() {}

    enum CodingKeys: CodingKey {
        case name, aspiration, ban, packPoints, advantages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(.name, default: "")
        aspiration = try container.decode(.aspiration, default: "")
        ban = try container.decode(.ban, default: "")
        packPoints = try container.decode(.packPoints, default: 0)
        advantages = try container.decode(.advantages, default: [])
    }
}

/// A trait the totem grants every pack member: Attribute or Skill dots, a Skill Specialty, or a Merit, whether or not
/// they meet its prerequisites.
struct TotemAdvantage: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case attribute, skill, specialty, merit
    }

    var id = UUID()
    var kind: Kind
    /// The Attribute (e.g. "strength"), the Skill's id (also for a Specialty), or the Merit's catalog id or, for a
    /// Merit not in the catalog, its name.
    var target: String
    /// The Specialty's name, or the Merit's qualifier.
    var detail = ""
    var dots = 1

    /// As a werewolf buys it: 4 per Attribute dot, 2 per Skill dot, 1 per Specialty or Merit dot.
    var cost: Int {
        switch kind {
        case .attribute: 4 * dots
        case .skill: 2 * dots
        case .specialty: 1
        case .merit: dots
        }
    }

    enum CodingKeys: CodingKey {
        case id, kind, target, detail, dots
    }

    init(kind: Kind, target: String, detail: String = "", dots: Int = 1) {
        self.kind = kind
        self.target = target
        self.detail = detail
        self.dots = dots
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: UUID())
        kind = try container.decode(Kind.self, forKey: .kind)
        target = try container.decode(String.self, forKey: .target)
        detail = try container.decode(.detail, default: "")
        dots = try container.decode(.dots, default: 1)
    }
}
