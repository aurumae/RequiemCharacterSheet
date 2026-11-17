//
//  Prerequisites.swift
//  ChroniclesCore
//
//  Checking Merit prerequisites any character has (Attributes, Skills, Merits, Willpower), and the wording of
//  Merits' ratings and effects. Each game adds the kinds only it has, e.g. Requiem's clan or Blood Potency.
//

import Foundation

/// One requirement of a Merit or Devotion, worded for display, and whether the character meets it.
package struct PrerequisiteCheck: Equatable {
    package let description: String
    /// `nil` when it can't be checked automatically, e.g. "Cannot also have the Fame Merit".
    package let isMet: Bool?
    /// The Merit isn't open to this kind of character at all, e.g. "Not available to Kindred", rather than needing
    /// something they could gain.
    package var isUnavailability = false

    package init(description: String, isMet: Bool?, isUnavailability: Bool = false) {
        self.description = description
        self.isMet = isMet
        self.isUnavailability = isUnavailability
    }
}

extension Array where Element == PrerequisiteCheck {
    /// Unmet requirements as one warning, e.g. "Requires Wits 3; Investigation 2", or
    /// "Not available to Kindred" for a Merit vampires can't take.
    package var warningText: String {
        var parts = filter(\.isUnavailability).map(\.description)
        let requirements = filter { !$0.isUnavailability }.map(\.description)
        if !requirements.isEmpty {
            parts.append("Requires \(requirements.joined(separator: "; "))")
        }
        return parts.joined(separator: ". ")
    }
}

extension ChroniclesCharacter {
    /// Every prerequisite, checked with `check`, then one line per "one of" choice.
    package func prerequisiteChecks(
        _ prerequisites: [Prerequisite],
        anyOf: [[Prerequisite]],
        check: (Prerequisite) -> PrerequisiteCheck
    ) -> [PrerequisiteCheck] {
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

    /// A prerequisite every game can check, or `nil` for a kind the game must check itself, e.g. Requiem's clan.
    package func commonCheck(_ prerequisite: Prerequisite, merits catalog: CatalogIndex<MeritEntry>) -> PrerequisiteCheck? {
        let id = prerequisite.id ?? ""
        let minimum = prerequisite.minimum ?? 1
        switch prerequisite.kind {
        case .attribute:
            guard let kind = AttributeKind(rawValue: id) else { return unknownCheck(prerequisite) }
            return PrerequisiteCheck(description: "\(kind.name) \(minimum)", isMet: rating(of: kind) >= minimum)
        case .skill:
            let skill = SkillID(id)
            let name = SkillDefinition.withID(skill)?.name ?? id
            return PrerequisiteCheck(description: "\(name) \(minimum)", isMet: rating(of: skill) >= minimum)
        case .merit:
            let name = catalog.entry(id)?.name ?? id
            let isMet = merits.contains { $0.source == .catalog(id) && $0.rating >= minimum }
            return PrerequisiteCheck(description: minimum > 1 ? "\(name) \(minimum)" : name, isMet: isMet)
        case .willpower:
            return PrerequisiteCheck(description: "Willpower \(minimum)", isMet: willpower >= minimum)
        default:
            return nil
        }
    }

    /// A requirement shown as written but not checked, e.g. free text.
    package func unknownCheck(_ prerequisite: Prerequisite) -> PrerequisiteCheck {
        PrerequisiteCheck(description: prerequisite.text ?? prerequisite.id ?? "Other requirement", isMet: nil)
    }
}

extension MeritEntry {
    /// The ratings it can be bought at, as dots: "•", "•–•••", or "•• or ••••" when there are gaps.
    package var ratingsText: String {
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
    package func allowedRating(for rating: Int) -> Int {
        guard rating > 0 else { return 0 }
        let sorted = ratings.sorted()
        return sorted.first { $0 >= rating } ?? sorted.last ?? rating
    }
}

extension Effect {
    /// What the effect does at `rating` dots, in words, e.g. "Adds 2 to Initiative".
    package func description(rating: Int, qualifier: String?, merits: CatalogIndex<MeritEntry>) -> String {
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
            return adds(amount.value(forRating: rating), to: merits.entry(id)?.name ?? id)
        case .skill(let id, let amount):
            return adds(amount.value(forRating: rating), to: SkillDefinition.withID(id)?.name ?? id.rawValue)
        case .health(let amount):
            return adds(amount.value(forRating: rating), to: "Health")
        case .willpower(let amount):
            return adds(amount.value(forRating: rating), to: "Willpower")
        case .essenceMaximum(let amount):
            return adds(amount.value(forRating: rating), to: "the Essence maximum")
        case .armor(let amount):
            return adds(amount.value(forRating: rating), to: "general armor")
        }
    }

    private func adds(_ amount: Int, to trait: String) -> String {
        amount >= 0 ? "Adds \(amount) to \(trait)" : "Subtracts \(-amount) from \(trait)"
    }
}
