//
//  CatalogFormatting.swift
//  RequiemCharacterSheet
//

import Foundation

extension Cost {
    /// The cost in words, e.g. "1 Vitae and 1 Willpower", "Optional: 1 Vitae" or "Free".
    var displayText: String {
        if vitae == .varies || willpower == .varies {
            return "Varies"
        }
        let parts = [vitae.map { $0.text(unit: "Vitae") }, willpower.map { $0.text(unit: "Willpower") }].compactMap { $0 }
        guard !parts.isEmpty else { return "Free" }
        let text = parts.joined(separator: " and ")
        return optional ? "Optional: \(text)" : text
    }
}

extension CostAmount {
    func text(unit: String) -> String {
        switch self {
        case .fixed(let amount):
            return "\(amount) \(unit)"
        case .range(let range):
            return "\(range.lowerBound)–\(range.upperBound) \(unit)"
        case .varies:
            return "Varies"
        }
    }
}

extension DicePool {
    /// The pool as a formula, e.g. "Intelligence + Expression + Dominate" or
    /// "Intelligence + Subterfuge + Dominate − victim's Resolve". Contested resistance is in `resistedBy`.
    func formula(disciplineName: String) -> String? {
        if let text { return text }
        guard let attribute else { return nil }
        var parts = [attribute.name]
        if let skill {
            parts.append(SkillDefinition.withID(skill)?.name ?? skill.rawValue)
        }
        if includesDiscipline {
            parts.append(disciplineName)
        }
        let formula = parts.joined(separator: " + ")
        if let resistance, subtractsResistance {
            return "\(formula) \(resistance)"
        }
        return formula
    }

    /// What the target rolls to resist, for contested powers, e.g. "Resolve + Blood Potency".
    var resistedBy: String? {
        guard let resistance, !subtractsResistance else { return nil }
        return resistance
    }

    /// Whether the resistance is subtracted from the pool, e.g. "− victim's Resolve".
    private var subtractsResistance: Bool {
        resistance?.hasPrefix("−") == true || resistance?.hasPrefix("-") == true
    }
}

extension SourceReference {
    /// e.g. "Vampire: The Requiem Second Edition, p. 131".
    func citation(in catalog: Catalog = .bundled) -> String {
        let book = catalog.book(book)?.name ?? book
        return page.map { "\(book), p. \($0)" } ?? book
    }
}

extension DisciplinePower {
    /// "Instant", "Reflexive", "Contested", or `nil` if the book gives none.
    var actionText: String? {
        guard let action, action != "none" else { return nil }
        return action.prefix(1).uppercased() + action.dropFirst()
    }
}

extension Character {
    /// How many dice this character rolls for a power's pool, before any resistance or situational modifiers,
    /// or `nil` if the pool can't be worked out (e.g. it's described only in text).
    func dice(for pool: DicePool, disciplineRating: Int) -> Int? {
        guard let attribute = pool.attribute else { return nil }
        let skill = pool.skill.map(skillDiceContribution) ?? 0
        return rollRating(of: attribute) + skill + (pool.includesDiscipline ? disciplineRating : 0)
    }

    /// The Disciplines the character's clan has in-clan, if the clan is from the catalog.
    var inClanDisciplines: Set<CatalogEntryID> {
        Set(clanEntry?.disciplines ?? [])
    }
}
