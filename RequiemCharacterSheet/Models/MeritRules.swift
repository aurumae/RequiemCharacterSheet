//
//  MeritRules.swift
//  RequiemCharacterSheet
//

import Foundation

/// One requirement of a Merit or Devotion, worded for display, and whether the character meets it.
struct PrerequisiteCheck: Equatable {
    static let notForKindred = "Not available to Kindred"

    let description: String
    /// `nil` when it can't be checked automatically, e.g. "Cannot also have the Fame Merit".
    let isMet: Bool?
}

extension Array where Element == PrerequisiteCheck {
    /// Unmet requirements as one warning, e.g. "Requires Wits 3; Investigation 2", or
    /// "Not available to Kindred" for a Merit vampires can't take.
    var warningText: String {
        let requirements = filter { $0.description != PrerequisiteCheck.notForKindred }.map(\.description)
        var parts = contains { $0.description == PrerequisiteCheck.notForKindred } ? [PrerequisiteCheck.notForKindred] : []
        if !requirements.isEmpty {
            parts.append("Requires \(requirements.joined(separator: "; "))")
        }
        return parts.joined(separator: ". ")
    }
}

extension Character {
    /// Every requirement of the Merit: each prerequisite, then one line per "one of" choice.
    func prerequisiteChecks(for entry: MeritEntry) -> [PrerequisiteCheck] {
        let kindred = entry.unavailableToKindred ? [PrerequisiteCheck(description: PrerequisiteCheck.notForKindred, isMet: false)] : []
        return kindred + prerequisiteChecks(entry.prerequisites, anyOf: entry.prerequisitesAnyOf)
    }

    /// Every Discipline a Devotion needs, then one line per "one of" choice.
    func prerequisiteChecks(for entry: DevotionEntry) -> [PrerequisiteCheck] {
        prerequisiteChecks(entry.prerequisites, anyOf: entry.prerequisitesAnyOf)
    }

    /// The requirements the character is known not to meet. Devotions can still be taken; these are warnings.
    func unmetPrerequisites(for entry: DevotionEntry) -> [PrerequisiteCheck] {
        prerequisiteChecks(for: entry).filter { $0.isMet == false }
    }

    private func prerequisiteChecks(_ prerequisites: [Prerequisite], anyOf: [[Prerequisite]]) -> [PrerequisiteCheck] {
        var checks = prerequisites.map(check)
        if !anyOf.isEmpty {
            let groups = anyOf.map { $0.map(check) }
            let descriptions = groups.map { $0.map(\.description).joined(separator: " and ") }
            // A choice is met if any of its options has nothing unmet
            let isMet = groups.contains { group in group.allSatisfy { $0.isMet != false } }
            checks.append(PrerequisiteCheck(description: "One of: " + descriptions.joined(separator: ", or "), isMet: isMet))
        }
        return checks
    }

    /// The requirements the character is known not to meet. Merits can still be taken; these are warnings.
    func unmetPrerequisites(for entry: MeritEntry) -> [PrerequisiteCheck] {
        prerequisiteChecks(for: entry).filter { $0.isMet == false }
    }

    private func check(_ prerequisite: Prerequisite) -> PrerequisiteCheck {
        let id = prerequisite.id ?? ""
        let minimum = prerequisite.minimum ?? 1
        let catalog = Catalog.bundled

        switch prerequisite.kind {
        case .attribute:
            guard let kind = AttributeKind(rawValue: id) else { return unknown(prerequisite) }
            return PrerequisiteCheck(description: "\(kind.name) \(minimum)", isMet: rating(of: kind) >= minimum)
        case .skill:
            let skill = SkillID(id)
            let name = SkillDefinition.withID(skill)?.name ?? id
            return PrerequisiteCheck(description: "\(name) \(minimum)", isMet: rating(of: skill) >= minimum)
        case .merit:
            let name = catalog.merits.entry(id)?.name ?? id
            let isMet = merits.contains { $0.source == .catalog(id) && $0.rating >= minimum }
            return PrerequisiteCheck(description: minimum > 1 ? "\(name) \(minimum)" : name, isMet: isMet)
        case .discipline:
            let name = catalog.disciplines.entry(id)?.name ?? id
            return PrerequisiteCheck(description: "\(name) \(minimum)", isMet: disciplineRating(id) >= minimum)
        case .bloodPotency:
            return PrerequisiteCheck(description: "Blood Potency \(minimum)", isMet: bloodPotency >= minimum)
        case .clan:
            let name = catalog.clans.entry(id)?.name ?? id
            return PrerequisiteCheck(description: "Clan: \(name)", isMet: clanSource == .catalog(id))
        case .covenant:
            let name = catalog.covenants.entry(id)?.name ?? id
            guard prerequisite.minimum != nil else {
                return PrerequisiteCheck(description: "Covenant: \(name)", isMet: covenantSource == .catalog(id))
            }
            // Measured in Covenant Status with that covenant
            return PrerequisiteCheck(description: "\(name) Status \(minimum)", isMet: covenantStatus(id) >= minimum)
        case .willpower:
            return PrerequisiteCheck(description: "Willpower \(minimum)", isMet: willpower >= minimum)
        case .notCovenant:
            let name = catalog.covenants.entry(id)?.name ?? id
            return PrerequisiteCheck(description: "Not a member of the \(name)", isMet: covenantSource != .catalog(id))
        case .other:
            return unknown(prerequisite)
        }
    }

    private func unknown(_ prerequisite: Prerequisite) -> PrerequisiteCheck {
        PrerequisiteCheck(description: prerequisite.text ?? prerequisite.id ?? "Other requirement", isMet: nil)
    }
}

extension MeritEntry {
    /// The ratings it can be bought at, as dots: "•", "•–•••", or "•• or ••••" when there are gaps.
    var ratingsText: String {
        guard let lowest = ratings.min(), let highest = ratings.max() else { return "" }
        // The larger dot, as in DotsText; a range reads as the books write it, "● to ●●●"
        let dots = { (count: Int) in String(repeating: "●", count: count) }
        if lowest == highest {
            return dots(lowest)
        }
        if ratings.sorted() == Array(lowest...highest) {
            return "\(dots(lowest)) to \(dots(highest))"
        }
        return ratings.sorted().map(dots).joined(separator: " or ")
    }

    /// The nearest allowed rating at or above `rating` (or the highest allowed). 0 is always allowed.
    func allowedRating(for rating: Int) -> Int {
        guard rating > 0 else { return 0 }
        let sorted = ratings.sorted()
        return sorted.first { $0 >= rating } ?? sorted.last ?? rating
    }
}

extension Effect {
    /// What the effect does at `rating` dots, in words, e.g. "Adds 2 to Initiative".
    func description(rating: Int, qualifier: String?) -> String {
        switch self {
        case .attribute(let kind, let amount):
            return adds(amount.value(forRating: rating), to: kind.name)
        case .attributeRolls(let kind, let amount):
            return adds(amount.value(forRating: rating), to: "\(kind.name) rolls")
        case .defense(let amount):
            return adds(amount.value(forRating: rating), to: "Defense")
        case .initiative(let amount):
            return adds(amount.value(forRating: rating), to: "Initiative")
        case .speed(let amount):
            return adds(amount.value(forRating: rating), to: "Speed")
        case .size(let amount):
            return adds(amount.value(forRating: rating), to: "Size (and so Health)")
        case .defenseSkillFromQualifier:
            return "Defense can use \(qualifier ?? "the chosen Skill") instead of Athletics"
        case .merit(let id, let amount):
            return adds(amount.value(forRating: rating), to: Catalog.bundled.merits.entry(id)?.name ?? id)
        }
    }

    private func adds(_ amount: Int, to trait: String) -> String {
        amount >= 0 ? "Adds \(amount) to \(trait)" : "Subtracts \(-amount) from \(trait)"
    }
}
