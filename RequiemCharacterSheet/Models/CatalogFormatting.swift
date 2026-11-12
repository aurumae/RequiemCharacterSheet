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
        if let discipline {
            parts.append(Catalog.bundled.disciplines.entry(discipline)?.name ?? discipline)
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
        let named = pool.discipline.map(self.disciplineRating) ?? 0
        return rollRating(of: attribute) + skill + (pool.includesDiscipline ? disciplineRating : 0) + named
    }

    /// Dice for a pool that names its own Discipline, such as a Devotion's.
    func dice(for pool: DicePool) -> Int? {
        dice(for: pool, disciplineRating: 0)
    }

    /// The character's in-clan Disciplines: their bloodline's, or else their clan's, if from the catalog.
    /// Why the character can't learn a catalog Discipline, e.g. one only a bloodline has (Cachexy, the Morbus).
    func reasonCantLearn(_ entry: DisciplineEntry) -> String? {
        guard let bloodline = entry.bloodline, bloodlineSource != .catalog(bloodline) else { return nil }
        let name = Catalog.bundled.bloodlines.entry(bloodline)?.name ?? bloodline
        return "Only the \(name) bloodline can learn \(entry.name)"
    }

    /// Who the in-clan Disciplines belong to, e.g. "Mekhet", or "Morbus" for that bloodline.
    var inClanGroupName: String {
        bloodlineEntry?.name ?? clan
    }

    var inClanDisciplines: Set<CatalogEntryID> {
        // A bloodline's Disciplines replace its parent clan's
        Set(bloodlineEntry?.disciplines ?? clanEntry?.disciplines ?? [])
    }
}

// MARK: - Grouping by book

/// A book's entries in one group, for pickers that lay out their own rows.
struct CatalogBookSection<Entry: CatalogEntry>: Identifiable {
    var id: String { book.id + "/" + title }
    let book: Book
    let title: String
    let entries: [Entry]
    /// Whether it's the first section of its book, which carries the book's heading.
    let startsBook: Bool

    /// Every book in catalog order, and within each the groups that have entries from it, in the order given.
    static func sections(_ groups: [CatalogPickerGroup<Entry>]) -> [CatalogBookSection] {
        Catalog.bundled.books.flatMap { book in
            let inBook = groups.map { group in (group, group.entries.filter { $0.source.book == book.id }) }
                .filter { !$0.1.isEmpty }
            return inBook.enumerated().map { index, pair in
                CatalogBookSection(
                    book: book,
                    title: pair.0.title,
                    entries: pair.1,
                    startsBook: index == 0
                )
            }
        }
    }
}

/// Entries that share a heading within each book, e.g. a clan's in-clan Disciplines. An empty title shows just the
/// book's heading.
struct CatalogPickerGroup<Entry: CatalogEntry> {
    let title: String
    let entries: [Entry]

    init(_ title: String, _ entries: [Entry]) {
        self.title = title
        self.entries = entries
    }
}

extension BloodlineEntry {
    /// Whether members can come from this clan. A bloodline with no parent clans listed takes members from any clan,
    /// e.g. the Penumbrae.
    func accepts(clan: CatalogEntryID) -> Bool {
        parentClans.isEmpty || parentClans.contains(clan)
    }

    /// e.g. "Daeva or Nosferatu", or "Any clan".
    var parentClansText: String {
        guard !parentClans.isEmpty else { return "Any clan" }
        return parentClans.compactMap { Catalog.bundled.clans.entry($0)?.name }.joined(separator: " or ")
    }
}
