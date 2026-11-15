//
//  SheetCharacter.swift
//  Chronicles
//
//  What the shared sheet sections need from a game's character beyond the shared traits.
//

import SwiftUI

/// A character the shared sheet sections can show. Each requirement has a default, below, for a game without the
/// rule; a game with one supplies its own, e.g. Requiem's Blood Potency caps, guided creation and Conditions.
protocol SheetCharacter: ChroniclesCharacter {
    /// The highest rating Attributes and Skills can be bought to, e.g. as Blood Potency allows.
    var baseRatingCap: Int { get }
    var attributeRatingRange: ClosedRange<Int> { get }
    var skillRatingRange: ClosedRange<Int> { get }
    /// An Attribute's dots with any bonuses, e.g. from a Discipline.
    func totalAttributeRating(for attribute: Attribute) -> Int
    /// The highest rating the player may set a trait to now, no higher than `cap`, e.g. less during guided creation.
    func editableMaximum(for key: TraitKey, upTo cap: Int) -> Int
    /// The lowest rating an Attribute can be set to.
    func minimumRating(of kind: AttributeKind) -> Int
    /// A line under an Attribute's name, e.g. that it includes a clan's free dot.
    func attributeNote(for kind: AttributeKind) -> String?

    /// The Skills shown in a category, in order.
    func skills(in category: TraitCategory) -> [Skill]
    /// Whether another Specialty can be added, e.g. not past three during guided creation.
    var canAddSpecialty: Bool { get }
    func addSpecialty(_ name: String, to skill: Skill)
    /// Renames a Specialty; an empty name removes it.
    func renameSpecialty(of skill: Skill, at index: Int, to name: String)
    func removeSpecialty(of skill: Skill, at index: Int)
    /// The names of Merits that depend on a Specialty, e.g. Area of Expertise, which go if it's deleted.
    func meritsDepending(onSpecialty specialty: String) -> [String]

    /// The mark for active Conditions that affect a trait, or `nil` for none.
    func conditionMark(for target: ConditionTarget, traitName: String) -> AnyView?
    /// Controls beside a Mental, Physical or Social heading, e.g. guided creation's priority menu. `nil` for none.
    func categoryAccessory(for category: TraitCategory, skills: Bool) -> AnyView?
}

extension SheetCharacter {
    var baseRatingCap: Int { 5 }
    var attributeRatingRange: ClosedRange<Int> { 1...baseRatingCap }
    var skillRatingRange: ClosedRange<Int> { 0...baseRatingCap }

    func totalAttributeRating(for attribute: Attribute) -> Int {
        attribute.rating
    }

    func editableMaximum(for key: TraitKey, upTo cap: Int) -> Int {
        cap
    }

    func minimumRating(of kind: AttributeKind) -> Int {
        1
    }

    func attributeNote(for kind: AttributeKind) -> String? {
        nil
    }

    /// The core Skills, and any others with dots or Specialties.
    func skills(in category: TraitCategory) -> [Skill] {
        let listed = Set(SkillList.vampireCore.skills)
        return skills.filter { skill in
            skill.category == category
                && (listed.contains(skill.skillID) || skill.rating > 0 || !skill.specialties.isEmpty)
        }
    }

    var canAddSpecialty: Bool { true }

    func addSpecialty(_ name: String, to skill: Skill) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        skill.specialties.append(name)
    }

    func renameSpecialty(of skill: Skill, at index: Int, to name: String) {
        guard skill.specialties.indices.contains(index) else { return }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            removeSpecialty(of: skill, at: index)
            return
        }
        skill.specialties[index] = name
    }

    func removeSpecialty(of skill: Skill, at index: Int) {
        guard skill.specialties.indices.contains(index) else { return }
        skill.specialties.remove(at: index)
    }

    func meritsDepending(onSpecialty specialty: String) -> [String] {
        []
    }

    func conditionMark(for target: ConditionTarget, traitName: String) -> AnyView? {
        nil
    }

    func categoryAccessory(for category: TraitCategory, skills: Bool) -> AnyView? {
        nil
    }
}
