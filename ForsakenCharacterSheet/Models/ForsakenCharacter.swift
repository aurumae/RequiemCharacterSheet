//
//  ForsakenCharacter.swift
//  ForsakenCharacterSheet
//
//  A Werewolf: The Forsaken character and its save format.
//

import Foundation
import Observation

@Observable
final class ForsakenCharacter: Codable {
    /// The version of the save format this app writes.
    /// - 1: the first Forsaken format. Every file has `"game": "forsaken"`.
    static let currentSchemaVersion = 1

    let id: UUID
    let createdAt: Date
    var modifiedAt: Date

    // Character details
    var name: String
    var player: String
    var chronicle: String
    var concept: String
    /// The character's Blood and Bone archetypes: the Wolf and the Man in them, in place of Requiem's Mask and Dirge.
    var bloodSource: TraitSource
    var boneSource: TraitSource
    var auspiceSource: TraitSource
    var tribeSource: TraitSource
    var lodgeSource: TraitSource

    var attributes: [Attribute]
    var skills: [Skill]
    var merits: [Merit]
    var aspirations: [Aspiration]
    /// Active Conditions, in the order they were added.
    var conditions: [CharacterCondition]

    // Werewolf traits
    var renown: [Renown: Int]
    var primalUrge: Int
    /// Essence in the pool now. The Primal Urge table sets the most it can hold.
    var essence: Int
    var harmony: Int
    var fleshTouchstone: String
    var spiritTouchstone: String
    var kuruthTriggers: KuruthTriggers
    /// The form the character is in, which changes their Attributes, Size and Speed.
    var form: Form
    var facets: [OwnedFacet]
    var rites: [OwnedRite]
    var fetishes: [OwnedFetish]
    /// Size in Hishu form.
    var size: Int

    var healthTrack: [HealthBoxFillType]
    var willpowerTrack: [WillpowerBoxFillType]

    var beats: Int
    var experiences: Int
    var xpMode: Bool
    var changeLog: [TraitChange]
    /// The Experiences paid for each dot, so lowering a trait in XP Mode refunds them.
    var paidDots: [TraitKey: [Int: Int]]

    init() {
        id = UUID()
        createdAt = Date()
        modifiedAt = createdAt

        name = ""
        player = ""
        chronicle = ""
        concept = ""
        bloodSource = .custom("")
        boneSource = .custom("")
        auspiceSource = .custom("")
        tribeSource = .custom("")
        lodgeSource = .custom("")

        attributes = AttributeKind.allCases.map { Attribute($0) }
        // The Chronicles of Darkness core Skills, the same as Requiem's
        skills = SkillList.vampireCore.skills.map { Skill($0) }
        merits = []
        aspirations = [Aspiration()]
        conditions = []

        renown = [:]
        primalUrge = 1
        // A new character starts with 7 (p. 84); the Primal Urge table sets the maximum (p. 93)
        essence = 7
        harmony = 7
        fleshTouchstone = ""
        spiritTouchstone = ""
        kuruthTriggers = KuruthTriggers()
        form = .hishu
        facets = []
        rites = []
        fetishes = []
        size = 5

        healthTrack = []
        willpowerTrack = []

        beats = 0
        experiences = 0
        xpMode = false
        changeLog = []
        paidDots = [:]
    }

    // MARK: - Saving

    enum CodingKeys: CodingKey {
        case game, schemaVersion, id, createdAt, modifiedAt,
             name, player, chronicle, concept, blood, bone, auspice, tribe, lodge,
             attributes, skills, merits, aspirations, conditions,
             renown, primalUrge, essence, harmony, fleshTouchstone, spiritTouchstone, kuruthTriggers, form,
             facets, rites, fetishes, size,
             healthTrack, willpowerTrack, beats, experiences, xpMode, changeLog, paidDots
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.game, forKey: .game)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)

        try container.encode(name, forKey: .name)
        try container.encode(player, forKey: .player)
        try container.encode(chronicle, forKey: .chronicle)
        try container.encode(concept, forKey: .concept)
        try container.encode(bloodSource, forKey: .blood)
        try container.encode(boneSource, forKey: .bone)
        try container.encode(auspiceSource, forKey: .auspice)
        try container.encode(tribeSource, forKey: .tribe)
        try container.encode(lodgeSource, forKey: .lodge)

        try container.encode(attributes, forKey: .attributes)
        try container.encode(skills, forKey: .skills)
        try container.encode(merits, forKey: .merits)
        try container.encode(aspirations, forKey: .aspirations)
        try container.encode(conditions, forKey: .conditions)

        // Renown by name, e.g. {"cunning": 2}, leaving out Renowns without dots
        let savedRenown = Dictionary(uniqueKeysWithValues: renown.filter { $0.value > 0 }.map { ($0.key.rawValue, $0.value) })
        try container.encode(savedRenown, forKey: .renown)
        try container.encode(primalUrge, forKey: .primalUrge)
        try container.encode(essence, forKey: .essence)
        try container.encode(harmony, forKey: .harmony)
        try container.encode(fleshTouchstone, forKey: .fleshTouchstone)
        try container.encode(spiritTouchstone, forKey: .spiritTouchstone)
        try container.encode(kuruthTriggers, forKey: .kuruthTriggers)
        try container.encode(form, forKey: .form)
        try container.encode(facets, forKey: .facets)
        try container.encode(rites, forKey: .rites)
        try container.encode(fetishes, forKey: .fetishes)
        try container.encode(size, forKey: .size)

        // Only the boxes on the sheet are saved
        try container.encode(healthBoxes, forKey: .healthTrack)
        try container.encode(willpowerBoxes, forKey: .willpowerTrack)
        try container.encode(beats, forKey: .beats)
        try container.encode(experiences, forKey: .experiences)
        try container.encode(xpMode, forKey: .xpMode)
        try container.encode(changeLog, forKey: .changeLog)
        try container.encode(paidDots, forKey: .paidDots)
    }

    /// Missing fields fall back to a new character's, so a file from an older version opens.
    required init(from decoder: Decoder) throws {
        let blank = ForsakenCharacter()
        let catalog = Catalog.bundled
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: blank.id)
        createdAt = try container.decode(.createdAt, default: blank.createdAt)
        modifiedAt = try container.decode(.modifiedAt, default: blank.modifiedAt)

        name = try container.decode(.name, default: "")
        player = try container.decode(.player, default: "")
        chronicle = try container.decode(.chronicle, default: "")
        concept = try container.decode(.concept, default: "")
        // Custom names that now match a catalog entry are linked to it
        bloodSource = try container.decodeTraitSource(.blood, in: catalog.archetypes)
        boneSource = try container.decodeTraitSource(.bone, in: catalog.archetypes)
        auspiceSource = try container.decodeTraitSource(.auspice, in: catalog.auspices)
        tribeSource = try container.decodeTraitSource(.tribe, in: catalog.tribes)
        lodgeSource = try container.decodeTraitSource(.lodge, in: catalog.lodges)

        attributes = try container.decode(.attributes, default: blank.attributes)
        skills = try container.decode(.skills, default: blank.skills)
        let savedMerits: [Merit] = try container.decode(.merits, default: [])
        savedMerits.forEach { $0.relink(in: catalog.merits) }
        merits = savedMerits
        aspirations = try container.decode(.aspirations, default: blank.aspirations)
        let savedConditions: [CharacterCondition] = try container.decode(.conditions, default: [])
        savedConditions.forEach { $0.relink(in: catalog.conditions) }
        conditions = savedConditions

        let savedRenown: [String: Int] = try container.decode(.renown, default: [:])
        renown = Dictionary(uniqueKeysWithValues: savedRenown.compactMap { key, value in Renown(rawValue: key).map { ($0, value) } })
        primalUrge = try container.decode(.primalUrge, default: 1)
        essence = try container.decode(.essence, default: 7)
        harmony = try container.decode(.harmony, default: 7)
        fleshTouchstone = try container.decode(.fleshTouchstone, default: "")
        spiritTouchstone = try container.decode(.spiritTouchstone, default: "")
        kuruthTriggers = try container.decode(.kuruthTriggers, default: KuruthTriggers())
        form = try container.decode(.form, default: .hishu)
        facets = try container.decode(.facets, default: [])
        rites = try container.decode(.rites, default: [])
        fetishes = try container.decode(.fetishes, default: [])
        size = try container.decode(.size, default: 5)

        healthTrack = try container.decode(.healthTrack, default: [])
        willpowerTrack = try container.decode(.willpowerTrack, default: [])
        beats = try container.decode(.beats, default: 0)
        experiences = try container.decode(.experiences, default: 0)
        xpMode = try container.decode(.xpMode, default: false)
        changeLog = try container.decode(.changeLog, default: [])
        paidDots = try container.decode(.paidDots, default: [:])
    }
}

// MARK: - Details by name

extension ForsakenCharacter {
    /// The names shown on the sheet. Setting one links to the catalog entry with that name, if there is one.
    var blood: String {
        get { Catalog.bundled.archetypes.name(of: bloodSource) }
        set { bloodSource = Catalog.bundled.archetypes.source(named: newValue) }
    }

    var bone: String {
        get { Catalog.bundled.archetypes.name(of: boneSource) }
        set { boneSource = Catalog.bundled.archetypes.source(named: newValue) }
    }

    var auspice: String {
        get { Catalog.bundled.auspices.name(of: auspiceSource) }
        set { auspiceSource = Catalog.bundled.auspices.source(named: newValue) }
    }

    var tribe: String {
        get { Catalog.bundled.tribes.name(of: tribeSource) }
        set { tribeSource = Catalog.bundled.tribes.source(named: newValue) }
    }

    var lodge: String {
        get { Catalog.bundled.lodges.name(of: lodgeSource) }
        set { lodgeSource = Catalog.bundled.lodges.source(named: newValue) }
    }

    var auspiceEntry: AuspiceEntry? {
        auspiceSource.catalogID.flatMap { Catalog.bundled.auspices.entry($0) }
    }

    var tribeEntry: TribeEntry? {
        tribeSource.catalogID.flatMap { Catalog.bundled.tribes.entry($0) }
    }

    func renown(_ kind: Renown) -> Int {
        renown[kind] ?? 0
    }

    func setRenown(_ kind: Renown, to rating: Int) {
        renown[kind] = rating > 0 ? rating : nil
    }

    /// The row of the Primal Urge table for the character's Primal Urge.
    var primalUrgeLevel: PrimalUrgeLevel {
        .level(primalUrge)
    }

    /// The Shadow Gifts the character's tribe and auspice favour, which cost less to learn.
    var affinityGifts: Set<CatalogEntryID> {
        Set((auspiceEntry?.giftAffinities ?? []) + (tribeEntry?.giftAffinities ?? []))
    }

    /// The Gift a known Facet belongs to.
    func gift(of facet: OwnedFacet) -> GiftEntry? {
        facet.source.catalogID.flatMap { Catalog.bundled.facet($0)?.gift }
    }

    /// Size in the current form.
    var effectiveSize: Int {
        size + form.sizeModifier
    }

    func facetName(_ facet: OwnedFacet) -> String {
        if let id = facet.source.catalogID {
            return Catalog.bundled.facet(id)?.facet.name ?? id
        }
        if case .custom(let name) = facet.source { return name }
        return ""
    }

    func riteName(_ rite: OwnedRite) -> String {
        Catalog.bundled.rites.name(of: rite.source)
    }

    func riteRating(_ rite: OwnedRite) -> Int {
        rite.source.catalogID.flatMap { Catalog.bundled.rites.entry($0)?.rating } ?? rite.customRating
    }
}

// MARK: - Shared sheet sections

extension ForsakenCharacter: SheetCharacter {
    var conditionCatalog: CatalogIndex<ConditionEntry> {
        Catalog.bundled.conditions
    }

    var isInCreation: Bool { false }

    /// Attributes and Skills can go as high as Primal Urge allows (p. 93).
    var baseRatingCap: Int {
        primalUrgeLevel.traitMaximum
    }

    /// The Attribute in the current form, e.g. Strength +3 in Gauru.
    func totalAttributeRating(for attribute: Attribute) -> Int {
        max(attribute.rating + (form.attributeModifiers[attribute.kind] ?? 0), 0)
    }

    func attributeNote(for kind: AttributeKind) -> String? {
        guard let change = form.attributeModifiers[kind], change != 0 else { return nil }
        return "\(change > 0 ? "+" : "−")\(abs(change)) in \(form.name)"
    }

    var meritCategoryOrder: [MeritEntry.Category] {
        [.werewolf, .mental, .physical, .social, .fighting, .other, .supernatural]
    }

    func meritCategoryTitle(_ category: MeritEntry.Category) -> String {
        switch category {
        case .werewolf: "Werewolf"
        case .mental: "Mental"
        case .physical: "Physical"
        case .social: "Social"
        case .fighting: "Fighting"
        case .supernatural: "Supernatural"
        case .other: "Other"
        default: category.rawValue.capitalized
        }
    }

    /// The shared prerequisites, and Forsaken's: Renown, Primal Urge, Harmony, tribe and auspice.
    func prerequisiteChecks(for entry: MeritEntry) -> [PrerequisiteCheck] {
        let catalog = Catalog.bundled
        return prerequisiteChecks(entry.prerequisites, anyOf: entry.prerequisitesAnyOf) { prerequisite in
            if let common = commonCheck(prerequisite, merits: catalog.merits) {
                return common
            }
            let id = prerequisite.id ?? ""
            let minimum = prerequisite.minimum ?? 1
            switch prerequisite.kind {
            case .renown:
                guard let kind = Renown(rawValue: id) else { return unknownCheck(prerequisite) }
                return PrerequisiteCheck(description: "\(kind.name) \(minimum)", isMet: renown(kind) >= minimum)
            case .primalUrge:
                return PrerequisiteCheck(description: "Primal Urge \(minimum)", isMet: primalUrge >= minimum)
            case .harmony:
                return PrerequisiteCheck(description: "Harmony \(minimum)", isMet: harmony >= minimum)
            case .tribe:
                let name = catalog.tribes.entry(id)?.name ?? id
                return PrerequisiteCheck(description: "Tribe: \(name)", isMet: tribeSource == .catalog(id))
            case .notTribe:
                let name = catalog.tribes.entry(id)?.name ?? id
                return PrerequisiteCheck(description: prerequisite.text ?? "Not of the \(name)", isMet: tribeSource != .catalog(id))
            case .auspice:
                let name = catalog.auspices.entry(id)?.name ?? id
                return PrerequisiteCheck(description: "Auspice: \(name)", isMet: auspiceSource == .catalog(id))
            default:
                return unknownCheck(prerequisite)
            }
        }
    }
}

// MARK: - Experiences

extension ForsakenCharacter: ExperienceCharacter {
    var meritCatalog: CatalogIndex<MeritEntry> {
        Catalog.bundled.merits
    }

    /// Every trait that costs Experiences. Harmony can't be bought (p. 104), and fetishes are made, not bought.
    var traitSnapshot: TraitSnapshot {
        var snapshot = TraitSnapshot()
        addSharedTraits(to: &snapshot)
        for kind in Renown.allCases {
            snapshot.levels[TraitKey(.renown, kind.rawValue)] = renown(kind)
            snapshot.names[TraitKey(.renown, kind.rawValue)] = kind.name
        }
        for facet in facets {
            let key = TraitKey(.facet, facet.id.uuidString)
            snapshot.levels[key] = 1
            snapshot.names[key] = facetName(facet)
        }
        for rite in rites {
            let key = TraitKey(.rite, rite.id.uuidString)
            // A Rite costs 1 Experience per dot (p. 85)
            snapshot.levels[key] = riteRating(rite)
            snapshot.names[key] = riteName(rite)
        }
        snapshot.levels[TraitKey(.primalUrge, "primalUrge")] = primalUrge
        snapshot.names[TraitKey(.primalUrge, "primalUrge")] = "Primal Urge"
        return snapshot
    }

    /// The book's Experience costs (pp. 84–85). A Wolf Gift Facet costs 1 (decided 2026-11-12).
    func experienceCost(of key: TraitKey, level: Int) -> Int {
        if let shared = sharedExperienceCost(of: key.kind) {
            return shared
        }
        switch key.kind {
        case .renown:
            return 3
        case .rite:
            return 1
        case .primalUrge:
            return 5
        case .facet:
            guard let facet = facets.first(where: { $0.id.uuidString == key.id }) else { return 2 }
            return facetCost(facet)
        default:
            return 0
        }
    }

    /// A Facet's cost: 1 for a Wolf Gift; free in the auspice's own Moon Gift, which comes with Renown; 2 for another
    /// Facet of a Gift already known; otherwise the Gift's first Facet, 3 for an affinity Gift and 5 for any other.
    private func facetCost(_ facet: OwnedFacet) -> Int {
        guard let gift = gift(of: facet) else { return 2 }
        if gift.kind == .wolf { return 1 }
        if gift.kind == .moon, gift.auspice == auspiceSource.catalogID { return 0 }
        let knowsGift = facets.contains { $0.id != facet.id && self.gift(of: $0)?.id == gift.id }
        if knowsGift { return 2 }
        return gift.kind == .shadow && affinityGifts.contains(gift.id) ? 3 : 5
    }

    func refundsWhenLowered(_ kind: TraitKind) -> Bool {
        true
    }

    var traitKindOrder: [TraitKind] {
        [.attribute, .skill, .specialty, .merit, .renown, .facet, .rite, .primalUrge, .condition]
    }

    func displayName(of kind: TraitKind) -> String {
        switch kind {
        case .attribute: "Attribute"
        case .skill: "Skill"
        case .specialty: "Specialty"
        case .merit: "Merit"
        case .renown: "Renown"
        case .facet: "Facet"
        case .rite: "Rite"
        case .primalUrge: "Primal Urge"
        case .condition: "Condition"
        default: kind.rawValue
        }
    }
}

extension ForsakenCharacter: ChroniclesCharacter {
    /// Stamina + Size in the current form (p. 96).
    var health: Int {
        (attribute(.stamina).map(totalAttributeRating) ?? 0) + effectiveSize
    }
}

// MARK: - Store and list

/// A saved Forsaken character as shown in the character list.
struct ForsakenCharacterSummary: StoredCharacterSummary {
    let id: UUID
    let name: String
    let auspice: String
    let tribe: String
    let modifiedAt: Date?
    let isReadable: Bool

    var listDetails: [String] {
        [auspice, tribe]
    }
}

extension ForsakenCharacter: StoredCharacter {
    static var game: String { "forsaken" }

    func summary() -> ForsakenCharacterSummary {
        ForsakenCharacterSummary(id: id, name: name, auspice: auspice, tribe: tribe, modifiedAt: modifiedAt, isReadable: true)
    }

    static func unreadableSummary(id: UUID) -> ForsakenCharacterSummary {
        ForsakenCharacterSummary(id: id, name: "", auspice: "", tribe: "", modifiedAt: nil, isReadable: false)
    }
}

extension ForsakenCharacter: ListedCharacter {
    /// Guided creation comes later; for now every character starts as a blank sheet.
    static var offersGuidedCreation: Bool { false }

    static func newCharacter(guided: Bool) -> ForsakenCharacter {
        ForsakenCharacter()
    }
}
