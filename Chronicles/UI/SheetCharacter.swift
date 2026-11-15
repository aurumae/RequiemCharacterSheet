//
//  SheetCharacter.swift
//  Chronicles
//
//  What the shared sheet sections need from a game's character beyond the shared traits.
//

import SwiftUI

/// A character the shared sheet sections can show. Each requirement has a default, below, for a game without the
/// rule; a game with one supplies its own, e.g. Requiem's Blood Potency caps, guided creation and Conditions.
protocol SheetCharacter: ExperienceCharacter, Observable {
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

    /// Dots a Merit gets from the character's other Merits, e.g. Flock's on Herd.
    func meritBonus(for id: CatalogEntryID) -> Int
    /// Every requirement of a Merit, met or not.
    func prerequisiteChecks(for entry: MeritEntry) -> [PrerequisiteCheck]
    /// Whether a Merit can be added at `rating` now, e.g. within the starting dots during guided creation. `nil` for a
    /// custom Merit.
    func creationAllowsMerit(_ entry: MeritEntry?, rating: Int) -> Bool
    /// The choices for a Merit's qualifier, or `nil` when the player types it.
    func qualifierOptions(for entry: MeritEntry) -> [String]?
    /// Merit categories in the order the picker lists them.
    var meritCategoryOrder: [MeritEntry.Category] { get }
    /// A Merit category's heading in the picker.
    func meritCategoryTitle(_ category: MeritEntry.Category) -> String
    /// Why a Merit can't be taken at all by this kind of character, e.g. "Not available to Kindred"; `nil` if it can.
    func meritUnavailableReason(_ entry: MeritEntry) -> String?

    /// What changed in a log entry, e.g. "1 → 3", or "Learned" for a game's own kinds of trait.
    func changeText(for change: TraitChange) -> String

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

    func meritBonus(for id: CatalogEntryID) -> Int {
        0
    }

    /// The prerequisites every game can check; any other kind is shown as written.
    func prerequisiteChecks(for entry: MeritEntry) -> [PrerequisiteCheck] {
        prerequisiteChecks(entry.prerequisites, anyOf: entry.prerequisitesAnyOf) { prerequisite in
            commonCheck(prerequisite, merits: Catalog.bundled.merits) ?? unknownCheck(prerequisite)
        }
    }

    /// The requirements the character is known not to meet. Merits can still be taken; these are warnings.
    func unmetPrerequisites(for entry: MeritEntry) -> [PrerequisiteCheck] {
        prerequisiteChecks(for: entry).filter { $0.isMet == false }
    }

    func creationAllowsMerit(_ entry: MeritEntry?, rating: Int) -> Bool {
        true
    }

    func qualifierOptions(for entry: MeritEntry) -> [String]? {
        guard let rule = entry.qualifier else { return nil }
        if rule.usesSpecialty { return specialtyChoices.map(\.specialty) }
        return rule.options
    }

    var meritCategoryOrder: [MeritEntry.Category] {
        [.mental, .physical, .social, .fighting, .other, .supernatural]
    }

    func meritCategoryTitle(_ category: MeritEntry.Category) -> String {
        switch category {
        case .mental: "Mental"
        case .physical: "Physical"
        case .social: "Social"
        case .fighting: "Fighting"
        case .supernatural: "Supernatural"
        case .other: "Other"
        default: category.rawValue.capitalized
        }
    }

    func meritUnavailableReason(_ entry: MeritEntry) -> String? {
        nil
    }

    func changeText(for change: TraitChange) -> String {
        change.sharedChangeText
    }

    /// The shared mark: a button listing what each Condition does to the trait.
    func conditionMark(for target: ConditionTarget, traitName: String) -> AnyView? {
        AnyView(ConditionIndicator(character: self, target: target, traitName: traitName))
    }

    func categoryAccessory(for category: TraitCategory, skills: Bool) -> AnyView? {
        nil
    }
}
