//
//  SpecialtyRules.swift
//  RequiemCharacterSheet
//

import Foundation

/// One of the character's Skill Specialties, e.g. Firearms (Rifles).
struct SpecialtyChoice: Hashable {
    let skill: String
    let specialty: String
}

extension QualifierRule {
    /// The qualifier is one of the character's Specialties, e.g. for Area of Expertise.
    var usesSpecialty: Bool {
        fromSpecialties == true
    }
}

extension Character {
    /// Every Specialty on the sheet, in Skill order, each name once.
    var specialtyChoices: [SpecialtyChoice] {
        var seen = Set<String>()
        return skills.flatMap { skill in
            skill.specialties.compactMap { specialty in
                let name = specialty.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, seen.insert(name).inserted else { return nil }
                return SpecialtyChoice(skill: skill.name, specialty: name)
            }
        }
    }

    /// The choices for a Merit's qualifier, or `nil` when the player types it.
    func qualifierOptions(for entry: MeritEntry) -> [String]? {
        guard let rule = entry.qualifier else { return nil }
        if rule.usesSpecialty { return specialtyChoices.map(\.specialty) }
        if rule.fromCovenants == true { return Catalog.bundled.covenants.all.map(\.name) }
        return rule.options
    }

    func addSpecialty(_ name: String, to skill: Skill) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        skill.specialties.append(name)
    }

    /// Renames a Specialty, and any Merit that's for it, e.g. Area of Expertise. An empty name removes it.
    func renameSpecialty(of skill: Skill, at index: Int, to name: String) {
        guard skill.specialties.indices.contains(index) else { return }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            removeSpecialty(of: skill, at: index)
            return
        }
        let old = skill.specialties[index].trimmingCharacters(in: .whitespacesAndNewlines)
        skill.specialties[index] = name
        guard !hasSpecialty(named: old) else { return }
        for merit in meritsFollowing(specialty: old) {
            merit.qualifier = name
        }
    }

    /// Removes a Specialty, and any Merit that was for it, e.g. Area of Expertise. With XP Mode on,
    /// the Merit's dots are refunded like any other removed trait.
    func removeSpecialty(of skill: Skill, at index: Int) {
        guard skill.specialties.indices.contains(index) else { return }
        let old = skill.specialties.remove(at: index).trimmingCharacters(in: .whitespacesAndNewlines)
        // Another Skill may have a Specialty with the same name, which the Merit can stay with
        guard !hasSpecialty(named: old) else { return }
        let following = Set(meritsFollowing(specialty: old).map(\.id))
        merits.removeAll { following.contains($0.id) }
    }

    private func hasSpecialty(named name: String) -> Bool {
        specialtyChoices.contains { $0.specialty == name }
    }

    /// Merits whose qualifier is this Specialty.
    private func meritsFollowing(specialty name: String) -> [Merit] {
        merits.filter { $0.entry?.qualifier?.usesSpecialty == true && $0.qualifier == name }
    }
}
