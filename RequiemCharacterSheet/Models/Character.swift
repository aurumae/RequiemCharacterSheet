//
//  Character.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//


import Foundation
import Observation

@Observable
final class Character: Codable {
    /// Version of the saved format.
    /// - 1: no `schemaVersion`, `id` or timestamps.
    /// - 2: adds `id`, `createdAt`, `modifiedAt`.
    /// - 3: health and willpower marks saved as `healthTrack`/`willpowerTrack` instead of box objects.
    /// - 4: attributes and skills saved by id instead of display name; skills have a list of specialties;
    ///   adds `skillList`.
    /// - 5: Disciplines, Merits, Banes, clan and covenant saved as a catalog id or custom text (`TraitSource`)
    ///   instead of a name; Merits gain a qualifier.
    /// - 6: adds `clanBaneActive`.
    static let currentSchemaVersion = 6

    /// A vampire can have at most three Banes (Vampire: The Requiem p. 108).
    static let maxBanes = 3

    let id: UUID
    let createdAt: Date
    var modifiedAt: Date

    var attributes: [Attribute]
    /// The skills this character has a record for: every skill in their skill list,
    /// plus any others they've been given dots or specialties in.
    var skills: [Skill]
    /// The `SkillList` whose skills the sheet shows.
    var skillListID: String

    /// Damage marked in each health box, in order. Boxes past the end are unmarked.
    /// Read `healthBoxes` for the boxes currently on the sheet.
    var healthTrack: [HealthBoxFillType]
    /// Spent marks in each willpower box, in order. Boxes past the end are unmarked.
    /// Read `willpowerBoxes` for the boxes currently on the sheet.
    var willpowerTrack: [WillpowerBoxFillType]

    // New character detail properties
    var name: String
    var player: String
    var chronicle: String
    var mask: String
    var dirge: String
    var concept: String
    /// The clan: a catalog entry or custom text.
    var clanSource: TraitSource {
        didSet {
            // Choosing a clan when Humanity is already at or below the threshold puts its bane in effect
            if clanSource != oldValue, clanEntry != nil, humanity <= clanBaneThreshold {
                clanBaneActive = true
            }
        }
    }
    var bloodline: String
    /// The covenant: a catalog entry or custom text.
    var covenantSource: TraitSource

    var bloodPotency: Int {
        didSet {
            // Blood Potency caps base ratings and Vitae
            clampBaseRatings()
            currentVitae = min(currentVitae, maxVitae)
        }
    }
    var currentVitae: Int

    var humanity: Int {
        didSet {
            // A known clan's bane takes hold when Humanity first falls to its threshold, and stays even if Humanity rises again
            if clanEntry != nil, humanity <= clanBaneThreshold, oldValue > clanBaneThreshold {
                clanBaneActive = true
            }
        }
    }
    /// Whether the clan bane is in effect. Set automatically when Humanity falls to the threshold;
    /// the player can switch it off, e.g. if that happened while trying out changes.
    var clanBaneActive: Bool
    var touchstones: [Touchstone]

    var disciplines: [Discipline]
    var merits: [Merit]

    var aspirations: [Aspiration]
    var banes: [Bane]

    var size: Int
    var armor: Int

    var beats: Int
    var experiences: Int

    enum CodingKeys: CodingKey {
        case schemaVersion, id, createdAt, modifiedAt,
             attributes, bloodPotency, healthTrack, willpowerTrack, skills, skillList,
             name, player, chronicle, mask, dirge, concept, clan, bloodline, covenant,
             currentVitae, humanity, clanBaneActive, touchstones, disciplines, merits,
             aspirations, banes, size, armor, beats, experiences
        // Read from saves before version 3 only
        case healthBoxes, willpowerBoxes
    }

    // Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Character.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)

        try container.encode(attributes, forKey: .attributes)
        // Only the boxes on the sheet are saved
        try container.encode(healthBoxes, forKey: .healthTrack)
        try container.encode(willpowerBoxes, forKey: .willpowerTrack)
        try container.encode(skills, forKey: .skills)
        try container.encode(skillListID, forKey: .skillList)

        try container.encode(name, forKey: .name)
        try container.encode(player, forKey: .player)
        try container.encode(chronicle, forKey: .chronicle)
        try container.encode(mask, forKey: .mask)
        try container.encode(dirge, forKey: .dirge)
        try container.encode(concept, forKey: .concept)
        try container.encode(clanSource, forKey: .clan)
        try container.encode(bloodline, forKey: .bloodline)
        try container.encode(covenantSource, forKey: .covenant)

        try container.encode(bloodPotency, forKey: .bloodPotency)
        try container.encode(currentVitae, forKey: .currentVitae)

        try container.encode(humanity, forKey: .humanity)
        try container.encode(clanBaneActive, forKey: .clanBaneActive)
        try container.encode(touchstones, forKey: .touchstones)

        try container.encode(disciplines, forKey: .disciplines)
        try container.encode(merits, forKey: .merits)

        try container.encode(aspirations, forKey: .aspirations)
        try container.encode(banes, forKey: .banes)

        try container.encode(size, forKey: .size)
        try container.encode(armor, forKey: .armor)

        try container.encode(beats, forKey: .beats)
        try container.encode(experiences, forKey: .experiences)
    }

    // Decoding. Every field falls back to its default when missing, so saves written
    // before a field existed still load instead of being replaced by a blank character.
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let now = Date()
        id = try container.decode(.id, default: UUID())
        createdAt = try container.decode(.createdAt, default: now)
        modifiedAt = try container.decode(.modifiedAt, default: now)

        // Unknown lists (e.g. from a newer version's content) fall back to the core list
        let savedSkillListID: String = try container.decode(.skillList, default: SkillList.vampireCore.id)
        let skillList = SkillList.withID(savedSkillListID) ?? .vampireCore
        skillListID = skillList.id

        let savedAttributes: [Attribute] = try container.decode(.attributes, default: [])
        let savedSkills: [Skill] = try container.decode(.skills, default: [])
        let savedTouchstones: [Touchstone] = try container.decode(.touchstones, default: [])
        attributes = Character.merge(saved: savedAttributes, into: Character.defaultAttributes(), by: \.kind)
        skills = Character.merge(saved: savedSkills, into: Character.defaultSkills(for: skillList), by: \.skillID)
        touchstones = Character.merge(saved: savedTouchstones, into: Character.defaultTouchstones(), by: \.level)

        if let track = try container.decodeIfPresent([HealthBoxFillType].self, forKey: .healthTrack) {
            healthTrack = track
        } else {
            // Before version 3 each box was saved as an object with an id
            healthTrack = try container.decode(.healthBoxes, default: [LegacyHealthBox]()).map { $0.damageType ?? .none }
        }
        if let track = try container.decodeIfPresent([WillpowerBoxFillType].self, forKey: .willpowerTrack) {
            willpowerTrack = track
        } else {
            willpowerTrack = try container.decode(.willpowerBoxes, default: [LegacyWillpowerBox]()).map { $0.state ?? .none }
        }

        name = try container.decode(.name, default: "")
        player = try container.decode(.player, default: "")
        chronicle = try container.decode(.chronicle, default: "")
        mask = try container.decode(.mask, default: "")
        dirge = try container.decode(.dirge, default: "")
        concept = try container.decode(.concept, default: "")
        clanSource = try container.decodeTraitSource(.clan, in: Catalog.bundled.clans)
        bloodline = try container.decode(.bloodline, default: "")
        covenantSource = try container.decodeTraitSource(.covenant, in: Catalog.bundled.covenants)

        bloodPotency = try container.decode(.bloodPotency, default: 1)
        currentVitae = try container.decode(.currentVitae, default: 0)

        humanity = try container.decode(.humanity, default: 7)
        let savedClanBaneActive = try container.decodeIfPresent(Bool.self, forKey: .clanBaneActive)
        clanBaneActive = false

        disciplines = try container.decode(.disciplines, default: [Discipline()])
        merits = try container.decode(.merits, default: [Merit()])

        aspirations = try container.decode(.aspirations, default: [Aspiration()])
        banes = try container.decode(.banes, default: [Bane()])

        size = try container.decode(.size, default: 5)
        armor = try container.decode(.armor, default: 0)

        beats = try container.decode(.beats, default: 0)
        experiences = try container.decode(.experiences, default: 0)

        // Bring loaded values within the limits set by Blood Potency
        clampBaseRatings()
        currentVitae = min(currentVitae, maxVitae)

        // Saves before version 6 didn't record it, so assume it from the current Humanity
        clanBaneActive = savedClanBaneActive ?? (humanity <= clanBaneThreshold)
    }

    init() {
        id = UUID()
        createdAt = Date()
        modifiedAt = createdAt

        attributes = Character.defaultAttributes()
        skillListID = SkillList.vampireCore.id
        skills = Character.defaultSkills(for: .vampireCore)

        healthTrack = []
        willpowerTrack = []

        name = ""
        player = ""
        chronicle = ""
        mask = ""
        dirge = ""
        concept = ""
        clanSource = .custom("")
        bloodline = ""
        covenantSource = .custom("")

        bloodPotency = 1
        currentVitae = 0

        humanity = 7
        clanBaneActive = false
        touchstones = Character.defaultTouchstones()

        disciplines = [Discipline()] // Start with one empty Discipline
        merits = [Merit()] // Start with one empty Merit

        aspirations = [Aspiration()] // Start with one empty Aspiration
        banes = [Bane()] // Start with one empty Bane

        size = 5
        armor = 0

        beats = 0
        experiences = 0
    }

    // MARK: - Defaults

    static func defaultAttributes() -> [Attribute] {
        AttributeKind.allCases.map { Attribute($0) }
    }

    static func defaultSkills(for skillList: SkillList = .vampireCore) -> [Skill] {
        skillList.skills.map { Skill($0) }
    }

    static func defaultTouchstones() -> [Touchstone] {
        (1...10).map { Touchstone(level: $0) }
    }

    /// Returns the default entries in their standard order, substituting the saved entry wherever
    /// one matches, so entries added since the save was written are filled in.
    /// Saved entries that don't match any default are kept at the end.
    private static func merge<T, Key: Hashable>(saved: [T], into defaults: [T], by key: KeyPath<T, Key>) -> [T] {
        let savedByKey = Dictionary(saved.map { ($0[keyPath: key], $0) }, uniquingKeysWith: { first, _ in first })
        let defaultKeys = Set(defaults.map { $0[keyPath: key] })
        return defaults.map { savedByKey[$0[keyPath: key]] ?? $0 }
            + saved.filter { !defaultKeys.contains($0[keyPath: key]) }
    }

    // MARK: - Health and Willpower boxes

    /// The health boxes on the sheet, one per point of Health.
    var healthBoxes: [HealthBoxFillType] {
        (0..<max(health, 0)).map { healthTrack.indices.contains($0) ? healthTrack[$0] : .none }
    }

    /// The willpower boxes on the sheet, one per point of Willpower.
    var willpowerBoxes: [WillpowerBoxFillType] {
        (0..<max(willpower, 0)).map { willpowerTrack.indices.contains($0) ? willpowerTrack[$0] : .none }
    }

    func setHealthBox(at index: Int, to damage: HealthBoxFillType) {
        if healthTrack.count <= index {
            healthTrack += Array(repeating: .none, count: index - healthTrack.count + 1)
        }
        healthTrack[index] = damage
    }

    func setWillpowerBox(at index: Int, to state: WillpowerBoxFillType) {
        if willpowerTrack.count <= index {
            willpowerTrack += Array(repeating: .none, count: index - willpowerTrack.count + 1)
        }
        willpowerTrack[index] = state
    }

    // MARK: - Clan and covenant

    /// The clan's name as shown on the sheet. Setting it links to the catalog clan with that name, if there is one.
    var clan: String {
        get { Catalog.bundled.clans.name(of: clanSource) }
        set { clanSource = Catalog.bundled.clans.source(named: newValue) }
    }

    /// The covenant's name as shown on the sheet. Setting it links to the catalog covenant with that name, if there is one.
    var covenant: String {
        get { Catalog.bundled.covenants.name(of: covenantSource) }
        set { covenantSource = Catalog.bundled.covenants.source(named: newValue) }
    }

    var clanEntry: ClanEntry? {
        clanSource.catalogID.flatMap { Catalog.bundled.clans.entry($0) }
    }

    /// The Humanity at which the clan bane takes effect: 6 for every clan unless its entry says otherwise.
    var clanBaneThreshold: Int {
        clanEntry?.bane.humanityThreshold ?? 6
    }

    var canAddBane: Bool {
        banes.count < Character.maxBanes
    }

    var covenantEntry: CovenantEntry? {
        covenantSource.catalogID.flatMap { Catalog.bundled.covenants.entry($0) }
    }

    // MARK: - Lookups

    func attribute(_ kind: AttributeKind) -> Attribute? {
        attributes.first { $0.kind == kind }
    }

    func skill(_ id: SkillID) -> Skill? {
        skills.first { $0.skillID == id }
    }

    var skillList: SkillList {
        SkillList.withID(skillListID) ?? .vampireCore
    }

    /// The skills to show in a category: those in the character's skill list, in list order,
    /// followed by any other skills the character has dots or specialties in.
    func skills(in category: TraitCategory) -> [Skill] {
        let listed = Set(skillList.skills)
        return skills.filter { skill in
            skill.category == category
                && (listed.contains(skill.skillID) || skill.rating > 0 || !skill.specialties.isEmpty)
        }
    }

    // MARK: - Effects

    /// A catalog effect from one of the character's Disciplines or Merits, with the dots and qualifier it applies at.
    struct AppliedEffect {
        let effect: Effect
        let rating: Int
        let qualifier: String?
    }

    /// Every effect from the character's catalog Disciplines and Merits that have at least one dot.
    var appliedEffects: [AppliedEffect] {
        let fromDisciplines = disciplines.filter { $0.rating > 0 }.flatMap { discipline in
            (discipline.entry?.effects ?? []).map { AppliedEffect(effect: $0, rating: discipline.rating, qualifier: nil) }
        }
        let fromMerits = merits.filter { $0.rating > 0 }.flatMap { merit in
            (merit.entry?.effects ?? []).map { AppliedEffect(effect: $0, rating: merit.rating, qualifier: merit.qualifier) }
        }
        return fromDisciplines + fromMerits
    }

    /// Adds up the amounts of the effects `select` picks out.
    private func effectTotal(_ select: (Effect) -> Amount?) -> Int {
        appliedEffects.reduce(0) { total, applied in
            total + (select(applied.effect)?.value(forRating: applied.rating) ?? 0)
        }
    }

    /// Bonuses that raise the Attribute itself, e.g. Vigor.
    func attributeBonus(for kind: AttributeKind) -> Int {
        effectTotal { effect in
            if case .attribute(let target, let amount) = effect, target == kind { return amount }
            return nil
        }
    }

    /// Bonuses that only apply when the Attribute is rolled, e.g. Praestantia.
    func rollBonus(for kind: AttributeKind) -> Int {
        effectTotal { effect in
            if case .attributeRolls(let target, let amount) = effect, target == kind { return amount }
            return nil
        }
    }

    /// Skills that may replace Athletics when calculating Defense, e.g. Brawl from Defensive Combat (Brawl).
    var alternativeDefenseSkills: [SkillID] {
        appliedEffects.compactMap { applied in
            guard applied.effect == .defenseSkillFromQualifier, let qualifier = applied.qualifier else { return nil }
            return SkillDefinition.named(qualifier)?.id
        }
    }

    // MARK: - Derived traits

    var health: Int {
        adjustedStamina + effectiveSize
    }

    var willpower: Int {
        rating(of: .resolve) + rating(of: .composure)
    }

    /// Size including Merits such as Giant.
    var effectiveSize: Int {
        size + effectTotal { effect in
            if case .size(let amount) = effect { return amount }
            return nil
        }
    }

    var maxVitae: Int {
        vitaeData(for: bloodPotency).max
    }

    var vitaePerTurn: Int {
        vitaeData(for: bloodPotency).perTurn
    }

    var baseRatingCap: Int {
        baseRatingCap(for: bloodPotency)
    }

    var attributeRatingRange: ClosedRange<Int> {
        1...baseRatingCap
    }

    var skillRatingRange: ClosedRange<Int> {
        0...baseRatingCap
    }

    var adjustedStamina: Int {
        totalRating(of: .stamina)
    }

    var defense: Int {
        defense(using: .athletics)
    }

    var defenseUsingBrawl: Int {
        defense(using: .brawl)
    }

    var defenseUsingWeaponry: Int {
        defense(using: .weaponry)
    }

    var hasDefensiveCombatBrawl: Bool {
        alternativeDefenseSkills.contains(.brawl)
    }

    var hasDefensiveCombatWeaponry: Bool {
        alternativeDefenseSkills.contains(.weaponry)
    }

    var speed: Int {
        let bonus = effectTotal { effect in
            if case .speed(let amount) = effect { return amount }
            return nil
        }
        return 5 + totalRating(of: .strength) + totalRating(of: .dexterity) + bonus
    }

    var initiativeMod: Int {
        let bonus = effectTotal { effect in
            if case .initiative(let amount) = effect { return amount }
            return nil
        }
        return totalRating(of: .dexterity) + totalRating(of: .composure) + bonus
    }

    var brawlDicePool: Int {
        rollRating(of: .strength) + skillDiceContribution(.brawl)
    }

    var firearmsDicePool: Int {
        rollRating(of: .dexterity) + skillDiceContribution(.firearms)
    }

    var weaponryDicePool: Int {
        rollRating(of: .strength) + skillDiceContribution(.weaponry)
    }

    /// The attribute's dots, without bonuses.
    func rating(of kind: AttributeKind) -> Int {
        attribute(kind)?.rating ?? 0
    }

    /// The skill's dots; 0 if the character has no record of it.
    func rating(of id: SkillID) -> Int {
        skill(id)?.rating ?? 0
    }

    /// The Attribute as a trait, including bonuses that raise it (e.g. Vigor). Used for Speed, Defense and Health.
    func totalRating(of kind: AttributeKind) -> Int {
        rating(of: kind) + attributeBonus(for: kind)
    }

    /// The Attribute when rolled, also including roll-only bonuses (e.g. Praestantia). Used for dice pools.
    func rollRating(of kind: AttributeKind) -> Int {
        totalRating(of: kind) + rollBonus(for: kind)
    }

    /// The rating shown on the sheet: the Attribute as rolled.
    func totalAttributeRating(for attribute: Attribute) -> Int {
        rollRating(of: attribute.kind)
    }

    /// The skill's contribution to a dice pool: its dots, or the unskilled penalty for its category.
    func skillDiceContribution(_ id: SkillID) -> Int {
        let rating = rating(of: id)
        guard rating == 0 else { return rating }
        return (SkillDefinition.withID(id)?.category ?? .mental).unskilledPenalty
    }

    func defense(using skillID: SkillID) -> Int {
        let bonus = effectTotal { effect in
            if case .defense(let amount) = effect { return amount }
            return nil
        }
        return min(totalRating(of: .dexterity), totalRating(of: .wits)) + rating(of: skillID) + bonus
    }

    private func baseRatingCap(for bloodPotency: Int) -> Int {
        max(5, min(bloodPotency, 10))
    }

    private func clampBaseRatings() {
        let cap = baseRatingCap

        for attribute in attributes {
            attribute.rating = min(max(attribute.rating, 1), cap)
        }

        for skill in skills {
            skill.rating = min(max(skill.rating, 0), cap)
        }
    }

    /// Max Vitae and Vitae per turn from the Blood Potency table.
    private func vitaeData(for bloodPotency: Int) -> (max: Int, perTurn: Int) {
        switch bloodPotency {
        case ...0:
            return (rating(of: .stamina), 1)
        case 1:
            return (10, 1)
        case 2:
            return (11, 2)
        case 3:
            return (12, 3)
        case 4:
            return (13, 4)
        case 5:
            return (15, 5)
        case 6:
            return (20, 6)
        case 7:
            return (25, 7)
        case 8:
            return (30, 8)
        case 9:
            return (50, 10)
        default:
            return (75, 15)
        }
    }

    // Methods to handle Beats and Experiences
    func incrementBeats() {
        beats += 1
        if beats >= 5 { // If beats reaches 5, set beats to 0 and increase exp by 1
            beats = 0
            experiences += 1
        }
    }

    func decrementBeats() {
        if beats > 0 {
            beats -= 1
        }
    }

    func incrementExperiences() {
        experiences += 1
    }

    func decrementExperiences() {
        if experiences > 0 {
            experiences -= 1
        }
    }
}

/// How health and willpower boxes were saved before version 3.
private struct LegacyHealthBox: Decodable {
    let damageType: HealthBoxFillType?
}

private struct LegacyWillpowerBox: Decodable {
    let state: WillpowerBoxFillType?
}
