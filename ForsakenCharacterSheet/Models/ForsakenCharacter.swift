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
    /// The character's Blood and Bone: the Wolf and the Man in them, in place of Requiem's Mask and Dirge.
    var blood: String
    var bone: String
    var auspice: String
    var tribe: String
    var lodge: String

    var attributes: [Attribute]
    var skills: [Skill]
    var merits: [Merit]
    var aspirations: [Aspiration]
    /// Active Conditions, in the order they were added.
    var conditions: [CharacterCondition]

    var healthTrack: [HealthBoxFillType]
    var willpowerTrack: [WillpowerBoxFillType]

    var beats: Int
    var experiences: Int
    var xpMode: Bool
    var changeLog: [TraitChange]

    init() {
        id = UUID()
        createdAt = Date()
        modifiedAt = createdAt

        name = ""
        player = ""
        chronicle = ""
        concept = ""
        blood = ""
        bone = ""
        auspice = ""
        tribe = ""
        lodge = ""

        attributes = AttributeKind.allCases.map { Attribute($0) }
        // The Chronicles of Darkness core Skills, the same as Requiem's
        skills = SkillList.vampireCore.skills.map { Skill($0) }
        merits = []
        aspirations = [Aspiration()]
        conditions = []

        healthTrack = []
        willpowerTrack = []

        beats = 0
        experiences = 0
        xpMode = false
        changeLog = []
    }

    // MARK: - Saving

    enum CodingKeys: CodingKey {
        case game, schemaVersion, id, createdAt, modifiedAt,
             name, player, chronicle, concept, blood, bone, auspice, tribe, lodge,
             attributes, skills, merits, aspirations, conditions, healthTrack, willpowerTrack,
             beats, experiences, xpMode, changeLog
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
        try container.encode(blood, forKey: .blood)
        try container.encode(bone, forKey: .bone)
        try container.encode(auspice, forKey: .auspice)
        try container.encode(tribe, forKey: .tribe)
        try container.encode(lodge, forKey: .lodge)

        try container.encode(attributes, forKey: .attributes)
        try container.encode(skills, forKey: .skills)
        try container.encode(merits, forKey: .merits)
        try container.encode(aspirations, forKey: .aspirations)
        try container.encode(conditions, forKey: .conditions)
        try container.encode(healthTrack, forKey: .healthTrack)
        try container.encode(willpowerTrack, forKey: .willpowerTrack)

        try container.encode(beats, forKey: .beats)
        try container.encode(experiences, forKey: .experiences)
        try container.encode(xpMode, forKey: .xpMode)
        try container.encode(changeLog, forKey: .changeLog)
    }

    /// Missing fields fall back to a new character's, so a file from an older version opens.
    required init(from decoder: Decoder) throws {
        let blank = ForsakenCharacter()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: blank.id)
        createdAt = try container.decode(.createdAt, default: blank.createdAt)
        modifiedAt = try container.decode(.modifiedAt, default: blank.modifiedAt)

        name = try container.decode(.name, default: "")
        player = try container.decode(.player, default: "")
        chronicle = try container.decode(.chronicle, default: "")
        concept = try container.decode(.concept, default: "")
        blood = try container.decode(.blood, default: "")
        bone = try container.decode(.bone, default: "")
        auspice = try container.decode(.auspice, default: "")
        tribe = try container.decode(.tribe, default: "")
        lodge = try container.decode(.lodge, default: "")

        attributes = try container.decode(.attributes, default: blank.attributes)
        skills = try container.decode(.skills, default: blank.skills)
        let savedMerits: [Merit] = try container.decode(.merits, default: [])
        // A custom Merit whose name has since joined the catalog links to it
        savedMerits.forEach { $0.relink(in: Catalog.bundled.merits) }
        merits = savedMerits
        aspirations = try container.decode(.aspirations, default: blank.aspirations)
        let savedConditions: [CharacterCondition] = try container.decode(.conditions, default: [])
        savedConditions.forEach { $0.relink(in: Catalog.bundled.conditions) }
        conditions = savedConditions
        healthTrack = try container.decode(.healthTrack, default: [])
        willpowerTrack = try container.decode(.willpowerTrack, default: [])

        beats = try container.decode(.beats, default: 0)
        experiences = try container.decode(.experiences, default: 0)
        xpMode = try container.decode(.xpMode, default: false)
        changeLog = try container.decode(.changeLog, default: [])
    }
}

/// Uses the shared defaults: ratings up to 5, no guided creation yet.
extension ForsakenCharacter: SheetCharacter {
    var conditionCatalog: CatalogIndex<ConditionEntry> {
        Catalog.bundled.conditions
    }

    var isInCreation: Bool { false }
}

extension ForsakenCharacter: ChroniclesCharacter {
    /// Stamina + Size, in Hishu (human) form. The other forms' bonuses come with the forms.
    var health: Int {
        rating(of: .stamina) + 5
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
