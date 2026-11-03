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
    static let currentSchemaVersion = 3

    let id: UUID
    let createdAt: Date
    var modifiedAt: Date

    var attributes: [Attribute]
    var skills: [Skill]

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
    var clan: String
    var bloodline: String
    var covenant: String

    var bloodPotency: Int {
        didSet {
            // Blood Potency caps base ratings and Vitae
            clampBaseRatings()
            currentVitae = min(currentVitae, maxVitae)
        }
    }
    var currentVitae: Int

    var humanity: Int
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
             attributes, bloodPotency, healthTrack, willpowerTrack, skills,
             name, player, chronicle, mask, dirge, concept, clan, bloodline, covenant,
             currentVitae, humanity, touchstones, disciplines, merits,
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

        try container.encode(name, forKey: .name)
        try container.encode(player, forKey: .player)
        try container.encode(chronicle, forKey: .chronicle)
        try container.encode(mask, forKey: .mask)
        try container.encode(dirge, forKey: .dirge)
        try container.encode(concept, forKey: .concept)
        try container.encode(clan, forKey: .clan)
        try container.encode(bloodline, forKey: .bloodline)
        try container.encode(covenant, forKey: .covenant)

        try container.encode(bloodPotency, forKey: .bloodPotency)
        try container.encode(currentVitae, forKey: .currentVitae)

        try container.encode(humanity, forKey: .humanity)
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

        let savedAttributes: [Attribute] = try container.decode(.attributes, default: [])
        let savedSkills: [Skill] = try container.decode(.skills, default: [])
        let savedTouchstones: [Touchstone] = try container.decode(.touchstones, default: [])
        attributes = Character.merge(saved: savedAttributes, into: Character.defaultAttributes(), by: \.name)
        skills = Character.merge(saved: savedSkills, into: Character.defaultSkills(), by: \.name)
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
        clan = try container.decode(.clan, default: "")
        bloodline = try container.decode(.bloodline, default: "")
        covenant = try container.decode(.covenant, default: "")

        bloodPotency = try container.decode(.bloodPotency, default: 1)
        currentVitae = try container.decode(.currentVitae, default: 0)

        humanity = try container.decode(.humanity, default: 7)

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
    }

    init() {
        id = UUID()
        createdAt = Date()
        modifiedAt = createdAt

        attributes = Character.defaultAttributes()
        skills = Character.defaultSkills()

        healthTrack = []
        willpowerTrack = []

        name = ""
        player = ""
        chronicle = ""
        mask = ""
        dirge = ""
        concept = ""
        clan = ""
        bloodline = ""
        covenant = ""

        bloodPotency = 1
        currentVitae = 0

        humanity = 7
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
        [
            "Intelligence", "Wits", "Resolve",
            "Strength", "Dexterity", "Stamina",
            "Presence", "Manipulation", "Composure"
        ].map { Attribute(name: $0, rating: 1) }
    }

    static func defaultSkills() -> [Skill] {
        let mentalSkills = [
            "Academics", "Computer", "Crafts", "Investigation", "Medicine", "Occult", "Politics", "Science"
        ]
        let physicalSkills = [
            "Athletics", "Brawl", "Drive", "Firearms", "Larceny", "Stealth", "Survival", "Weaponry"
        ]
        let socialSkills = [
            "Animal Ken", "Empathy", "Expression", "Intimidation", "Persuasion", "Socialize", "Streetwise", "Subterfuge"
        ]
        return (mentalSkills + physicalSkills + socialSkills).map { Skill(name: $0) }
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

    // Derived attributes
    var health: Int {
        return adjustedStamina + size
    }

    var willpower: Int {
        let resolve = attributes.first { $0.name == "Resolve" }?.rating ?? 0
        let composure = attributes.first { $0.name == "Composure" }?.rating ?? 0
        return resolve + composure
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

    // Computed properties for derived attributes
    var adjustedStamina: Int {
        totalAttributeRating(named: "Stamina")
    }

    var defense: Int {
        defense(usingSkillNamed: "Athletics")
    }

    var defenseUsingBrawl: Int {
        defense(usingSkillNamed: "Brawl")
    }

    var defenseUsingWeaponry: Int {
        defense(usingSkillNamed: "Weaponry")
    }

    var hasDefensiveCombatBrawl: Bool {
        hasDefensiveCombatMerit(for: "brawl")
    }

    var hasDefensiveCombatWeaponry: Bool {
        hasDefensiveCombatMerit(for: "weaponry")
    }

    var speed: Int {
        let strength = totalAttributeRating(named: "Strength")
        let dexterity = totalAttributeRating(named: "Dexterity")
        return 5 + strength + dexterity
    }

    var initiativeMod: Int {
        let dexterity = totalAttributeRating(named: "Dexterity")
        let composure = totalAttributeRating(named: "Composure")
        return dexterity + composure
    }

    var brawlDicePool: Int {
        let strength = totalAttributeRating(named: "Strength")
        let brawl = skillDiceContribution(named: "Brawl")
        return strength + brawl
    }

    var firearmsDicePool: Int {
        let dexterity = totalAttributeRating(named: "Dexterity")
        let firearms = skillDiceContribution(named: "Firearms")
        return dexterity + firearms
    }

    var weaponryDicePool: Int {
        let strength = totalAttributeRating(named: "Strength")
        let weaponry = skillDiceContribution(named: "Weaponry")
        return strength + weaponry
    }

    func totalAttributeRating(for attribute: Attribute) -> Int {
        attribute.rating + disciplineBonus(forAttributeName: attribute.name)
    }

    func totalAttributeRating(named name: String) -> Int {
        let baseRating = attributes.first { $0.name == name }?.rating ?? 0
        return baseRating + disciplineBonus(forAttributeName: name)
    }

    func disciplineBonus(forAttributeName name: String) -> Int {
        switch name {
        case "Strength":
            return disciplineRating(named: "vigor")
        case "Stamina":
            return disciplineRating(named: "resilience")
        case "Dexterity":
            return disciplineRating(named: "praestantia")
        default:
            return 0
        }
    }

    func disciplineRating(named name: String) -> Int {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return disciplines.first {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedName
        }?.rating ?? 0
    }

    func skillDiceContribution(named name: String) -> Int {
        let rating = skills.first { $0.name == name }?.rating ?? 0
        return rating == 0 ? -1 : rating
    }

    func defense(usingSkillNamed skillName: String) -> Int {
        let dexterity = totalAttributeRating(named: "Dexterity")
        let wits = totalAttributeRating(named: "Wits")
        let skillRating = skills.first { $0.name == skillName }?.rating ?? 0
        let celerityRating = disciplineRating(named: "celerity")
        return min(dexterity, wits) + skillRating + celerityRating
    }

    func hasDefensiveCombatMerit(for skillName: String) -> Bool {
        let normalizedSkillName = normalizedRulesText(skillName)

        return merits.contains { merit in
            let normalizedMeritName = normalizedRulesText(merit.name)
            return normalizedMeritName.contains("defensive combat")
                && normalizedMeritName.contains(normalizedSkillName)
        }
    }

    private func normalizedRulesText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
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
            let stamina = attributes.first { $0.name == "Stamina" }?.rating ?? 0
            return (stamina, 1)
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
