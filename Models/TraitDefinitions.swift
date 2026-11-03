//
//  TraitDefinitions.swift
//  RequiemCharacterSheet
//

import Foundation

/// The three categories every attribute and skill belongs to.
enum TraitCategory: String, CaseIterable, Codable {
    case mental, physical, social

    var title: String {
        rawValue.uppercased()
    }

    /// Dice modifier for rolling a skill in this category with no dots.
    var unskilledPenalty: Int {
        self == .mental ? -3 : -1
    }
}

// MARK: - Attributes

/// The nine attributes, shared by every Chronicles of Darkness game.
enum AttributeKind: String, CaseIterable, Codable {
    case intelligence, wits, resolve
    case strength, dexterity, stamina
    case presence, manipulation, composure

    var name: String {
        rawValue.capitalized
    }

    var category: TraitCategory {
        switch self {
        case .intelligence, .wits, .resolve:
            return .mental
        case .strength, .dexterity, .stamina:
            return .physical
        case .presence, .manipulation, .composure:
            return .social
        }
    }

    /// Matches a display name such as "Strength", as used by saves before version 4.
    init?(name: String) {
        self.init(rawValue: name.lowercased())
    }
}

// MARK: - Skills

/// A stable identifier for a skill. Saves and rules refer to skills by id, so display names can
/// change and different skill lists (e.g. Dark Eras) can add skills without touching existing ones.
struct SkillID: RawRepresentable, Hashable, Codable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension SkillID {
    // Mental
    static let academics = SkillID("academics")
    static let computer = SkillID("computer")
    static let crafts = SkillID("crafts")
    static let investigation = SkillID("investigation")
    static let medicine = SkillID("medicine")
    static let occult = SkillID("occult")
    static let politics = SkillID("politics")
    static let science = SkillID("science")
    // Physical
    static let athletics = SkillID("athletics")
    static let brawl = SkillID("brawl")
    static let drive = SkillID("drive")
    static let firearms = SkillID("firearms")
    static let larceny = SkillID("larceny")
    static let stealth = SkillID("stealth")
    static let survival = SkillID("survival")
    static let weaponry = SkillID("weaponry")
    // Social
    static let animalKen = SkillID("animal-ken")
    static let empathy = SkillID("empathy")
    static let expression = SkillID("expression")
    static let intimidation = SkillID("intimidation")
    static let persuasion = SkillID("persuasion")
    static let socialize = SkillID("socialize")
    static let streetwise = SkillID("streetwise")
    static let subterfuge = SkillID("subterfuge")
}

struct SkillDefinition: Identifiable, Hashable {
    let id: SkillID
    let name: String
    let category: TraitCategory

    /// Every skill known to the app, across all skill lists.
    static let all: [SkillDefinition] = [
        SkillDefinition(id: .academics, name: "Academics", category: .mental),
        SkillDefinition(id: .computer, name: "Computer", category: .mental),
        SkillDefinition(id: .crafts, name: "Crafts", category: .mental),
        SkillDefinition(id: .investigation, name: "Investigation", category: .mental),
        SkillDefinition(id: .medicine, name: "Medicine", category: .mental),
        SkillDefinition(id: .occult, name: "Occult", category: .mental),
        SkillDefinition(id: .politics, name: "Politics", category: .mental),
        SkillDefinition(id: .science, name: "Science", category: .mental),
        SkillDefinition(id: .athletics, name: "Athletics", category: .physical),
        SkillDefinition(id: .brawl, name: "Brawl", category: .physical),
        SkillDefinition(id: .drive, name: "Drive", category: .physical),
        SkillDefinition(id: .firearms, name: "Firearms", category: .physical),
        SkillDefinition(id: .larceny, name: "Larceny", category: .physical),
        SkillDefinition(id: .stealth, name: "Stealth", category: .physical),
        SkillDefinition(id: .survival, name: "Survival", category: .physical),
        SkillDefinition(id: .weaponry, name: "Weaponry", category: .physical),
        SkillDefinition(id: .animalKen, name: "Animal Ken", category: .social),
        SkillDefinition(id: .empathy, name: "Empathy", category: .social),
        SkillDefinition(id: .expression, name: "Expression", category: .social),
        SkillDefinition(id: .intimidation, name: "Intimidation", category: .social),
        SkillDefinition(id: .persuasion, name: "Persuasion", category: .social),
        SkillDefinition(id: .socialize, name: "Socialize", category: .social),
        SkillDefinition(id: .streetwise, name: "Streetwise", category: .social),
        SkillDefinition(id: .subterfuge, name: "Subterfuge", category: .social)
    ]

    private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func withID(_ id: SkillID) -> SkillDefinition? {
        byID[id]
    }

    /// Matches a display name such as "Animal Ken", as used by saves before version 4.
    static func named(_ name: String) -> SkillDefinition? {
        all.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}

/// The skills a character sheet shows, in order. Different settings use different lists;
/// a skill can appear in several lists, and a character keeps dots in skills outside their list.
struct SkillList: Identifiable {
    let id: String
    let name: String
    let skills: [SkillID]

    static let vampireCore = SkillList(
        id: "vampire-core",
        name: "Vampire: The Requiem (2nd Edition)",
        skills: [
            .academics, .computer, .crafts, .investigation, .medicine, .occult, .politics, .science,
            .athletics, .brawl, .drive, .firearms, .larceny, .stealth, .survival, .weaponry,
            .animalKen, .empathy, .expression, .intimidation, .persuasion, .socialize, .streetwise, .subterfuge
        ]
    )

    static let all: [SkillList] = [vampireCore]

    static func withID(_ id: String) -> SkillList? {
        all.first { $0.id == id }
    }
}
