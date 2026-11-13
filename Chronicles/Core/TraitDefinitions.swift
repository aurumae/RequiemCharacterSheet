//
//  TraitDefinitions.swift
//  RequiemCharacterSheet
//

import Foundation

/// The three categories every attribute and skill belongs to.
package enum TraitCategory: String, CaseIterable, Codable, CodingKeyRepresentable {
    case mental, physical, social

    /// "Mental", "Physical" or "Social".
    package var name: String {
        rawValue.capitalized
    }

    /// Dice modifier for rolling a skill in this category with no dots.
    package var unskilledPenalty: Int {
        self == .mental ? -3 : -1
    }
}

// MARK: - Attributes

/// The nine attributes, shared by every Chronicles of Darkness game.
package enum AttributeKind: String, CaseIterable, Codable {
    case intelligence, wits, resolve
    case strength, dexterity, stamina
    case presence, manipulation, composure

    package var name: String {
        rawValue.capitalized
    }

    package var category: TraitCategory {
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
    package init?(name: String) {
        self.init(rawValue: name.lowercased())
    }
}

// MARK: - Skills

/// A stable identifier for a skill. Saves and rules refer to skills by id, so display names can
/// change and different skill lists (e.g. Dark Eras) can add skills without touching existing ones.
package struct SkillID: RawRepresentable, Hashable, Codable {
    package let rawValue: String

    package init(rawValue: String) {
        self.rawValue = rawValue
    }

    package init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension SkillID {
    // Mental
    package static let academics = SkillID("academics")
    package static let computer = SkillID("computer")
    package static let crafts = SkillID("crafts")
    package static let investigation = SkillID("investigation")
    package static let medicine = SkillID("medicine")
    package static let occult = SkillID("occult")
    package static let politics = SkillID("politics")
    package static let science = SkillID("science")
    // Physical
    package static let athletics = SkillID("athletics")
    package static let brawl = SkillID("brawl")
    package static let drive = SkillID("drive")
    package static let firearms = SkillID("firearms")
    package static let larceny = SkillID("larceny")
    package static let stealth = SkillID("stealth")
    package static let survival = SkillID("survival")
    package static let weaponry = SkillID("weaponry")
    // Social
    package static let animalKen = SkillID("animal-ken")
    package static let empathy = SkillID("empathy")
    package static let expression = SkillID("expression")
    package static let intimidation = SkillID("intimidation")
    package static let persuasion = SkillID("persuasion")
    package static let socialize = SkillID("socialize")
    package static let streetwise = SkillID("streetwise")
    package static let subterfuge = SkillID("subterfuge")
}

package struct SkillDefinition: Identifiable, Hashable {
    package let id: SkillID
    package let name: String
    package let category: TraitCategory

    /// Every skill known to the app, across all skill lists.
    package static let all: [SkillDefinition] = [
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

    package static func withID(_ id: SkillID) -> SkillDefinition? {
        byID[id]
    }

    /// Matches a display name such as "Animal Ken", as used by saves before version 4.
    package static func named(_ name: String) -> SkillDefinition? {
        all.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}

/// The skills a character sheet shows, in order. Different settings use different lists;
/// a skill can appear in several lists, and a character keeps dots in skills outside their list.
package struct SkillList: Identifiable {
    package let id: String
    package let name: String
    package let skills: [SkillID]

    package static let vampireCore = SkillList(
        id: "vampire-core",
        name: "Vampire: The Requiem (2nd Edition)",
        skills: [
            .academics, .computer, .crafts, .investigation, .medicine, .occult, .politics, .science,
            .athletics, .brawl, .drive, .firearms, .larceny, .stealth, .survival, .weaponry,
            .animalKen, .empathy, .expression, .intimidation, .persuasion, .socialize, .streetwise, .subterfuge
        ]
    )

    package static let all: [SkillList] = [vampireCore]

    package static func withID(_ id: String) -> SkillList? {
        all.first { $0.id == id }
    }
}
