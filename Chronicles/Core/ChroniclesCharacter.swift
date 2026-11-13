//
//  ChroniclesCharacter.swift
//  ChroniclesCore
//
//  The traits every Chronicles of Darkness character has, whatever the game, and the rules that only need those.
//  Each game's character class conforms, keeping its own stored properties and save format.
//

import Foundation

package protocol ChroniclesCharacter: AnyObject {
    var name: String { get set }
    var player: String { get set }
    var chronicle: String { get set }
    var concept: String { get set }

    var attributes: [Attribute] { get set }
    /// Every skill in the character's skill list.
    var skills: [Skill] { get set }
    var merits: [Merit] { get set }
    var aspirations: [Aspiration] { get set }
    /// Active Conditions, in the order they were added.
    var conditions: [CharacterCondition] { get set }

    var healthTrack: [HealthBoxFillType] { get set }
    var willpowerTrack: [WillpowerBoxFillType] { get set }

    var beats: Int { get set }
    var experiences: Int { get set }
    /// Whether raising traits costs Experiences.
    var xpMode: Bool { get set }
    var changeLog: [TraitChange] { get set }
}

/// One of the character's Skill Specialties, e.g. Firearms (Rifles).
package struct SpecialtyChoice: Hashable {
    package let skill: String
    package let specialty: String

    package init(skill: String, specialty: String) {
        self.skill = skill
        self.specialty = specialty
    }
}

extension QualifierRule {
    /// The qualifier is one of the character's Specialties, e.g. for Area of Expertise.
    package var usesSpecialty: Bool {
        fromSpecialties == true
    }
}

extension ChroniclesCharacter {
    package func attribute(_ kind: AttributeKind) -> Attribute? {
        attributes.first { $0.kind == kind }
    }

    package func skill(_ id: SkillID) -> Skill? {
        skills.first { $0.skillID == id }
    }

    /// The attribute's dots, without bonuses.
    package func rating(of kind: AttributeKind) -> Int {
        attribute(kind)?.rating ?? 0
    }

    /// The skill's dots; 0 if the character has no record of it.
    package func rating(of id: SkillID) -> Int {
        skill(id)?.rating ?? 0
    }

    /// Willpower dots: Resolve + Composure.
    package var willpower: Int {
        rating(of: .resolve) + rating(of: .composure)
    }

    /// Five Beats make an Experience.
    package func incrementBeats() {
        beats += 1
        if beats >= 5 {
            beats = 0
            experiences += 1
        }
    }

    package func decrementBeats() {
        if beats > 0 {
            beats -= 1
        }
    }

    /// Every Specialty on the sheet, in Skill order, each name once.
    package var specialtyChoices: [SpecialtyChoice] {
        var seen = Set<String>()
        return skills.flatMap { skill in
            skill.specialties.compactMap { specialty in
                let name = specialty.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, seen.insert(name).inserted else { return nil }
                return SpecialtyChoice(skill: skill.name, specialty: name)
            }
        }
    }
}
