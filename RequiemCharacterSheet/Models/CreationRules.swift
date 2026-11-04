//
//  CreationRules.swift
//  RequiemCharacterSheet
//

import Foundation

/// A character being made with guided creation (Vampire: The Requiem pp. 79–84). While it's set,
/// the sheet holds the character to the book's starting dots: hard limits, not warnings.
struct CreationState: Codable, Equatable {
    /// Bonus Experiences for an experienced character, added when creation is finished.
    var bonusExperiences = 0
}

/// The book's starting dots.
enum CreationRules {
    /// Extra Attribute dots for the primary, secondary and tertiary categories; each Attribute also has one free dot.
    static let attributeDots = [5, 4, 3]
    /// Skill dots for the primary, secondary and tertiary categories.
    static let skillDots = [11, 7, 4]
    static let specialties = 3
    static let disciplineDots = 3
    /// At least two of the starting Discipline dots are in-clan, so at most one isn't.
    static let outOfClanDisciplineDots = 1
    static let meritDots = 10
    /// Blood Potency starts at 1; each extra dot (at most two) costs five Merit dots.
    static let meritDotsPerBloodPotency = 5
    static let maxBloodPotency = 3
    static let humanity = 7
}

/// How many of a budget's dots are used, e.g. Mental Skills: 9 of 11.
struct CreationBudget: Equatable {
    let used: Int
    let allowed: Int

    var remaining: Int { allowed - used }
}

/// A starting-dots rule the character breaks.
enum CreationProblem: Hashable {
    case attributesOverBudget
    case skillsOverBudget
    case tooManySpecialties
    case tooManyDisciplineDots
    case tooFewInClanDisciplineDots
    /// Crúac or Theban Sorcery without Status in its covenant.
    case sorceryWithoutStatus(discipline: String, covenant: String)
    case coilWithoutStatus
    case coilOutsideMystery
    case tooManyRituals(discipline: String)
    case ritualAboveDiscipline(ritual: String)
    case devotionsOrScales
    case tooManyMeritDots
    case meritUnavailableToKindred(merit: String)
    case bloodPotencyTooHigh
    case humanityTooHigh

    var description: String {
        switch self {
        case .attributesOverBudget:
            return "More Attribute dots than 5, 4 and 3"
        case .skillsOverBudget:
            return "More Skill dots than 11, 7 and 4"
        case .tooManySpecialties:
            return "More than 3 Specialties"
        case .tooManyDisciplineDots:
            return "More than 3 Discipline dots"
        case .tooFewInClanDisciplineDots:
            return "At least 2 Discipline dots must be in-clan"
        case .sorceryWithoutStatus(let discipline, let covenant):
            return "\(discipline) needs \(covenant) Status"
        case .coilWithoutStatus:
            return "Coils need Ordo Dracul Status"
        case .coilOutsideMystery:
            return "Only your Mystery's Coil can be learned at creation"
        case .tooManyRituals(let discipline):
            return "More \(discipline) rituals than \(discipline) dots"
        case .ritualAboveDiscipline(let ritual):
            return "\(ritual) is rated above its Discipline"
        case .devotionsOrScales:
            return "Devotions and Scales are learned with Experiences after creation"
        case .tooManyMeritDots:
            return "More than 10 Merit dots, counting 5 per extra dot of Blood Potency"
        case .meritUnavailableToKindred(let merit):
            return "\(merit) isn't available to Kindred"
        case .bloodPotencyTooHigh:
            return "Blood Potency can start at most at 3"
        case .humanityTooHigh:
            return "Humanity starts at 7"
        }
    }
}

/// Where a character stands against the starting dots.
struct CreationReport: Equatable {
    /// By category, with priorities worked out from where the dots are.
    var attributes: [TraitCategory: CreationBudget] = [:]
    var skills: [TraitCategory: CreationBudget] = [:]
    var specialties = CreationBudget(used: 0, allowed: CreationRules.specialties)
    var disciplines = CreationBudget(used: 0, allowed: CreationRules.disciplineDots)
    /// Merit dots, plus five for each extra dot of Blood Potency.
    var merits = CreationBudget(used: 0, allowed: CreationRules.meritDots)
    /// The Attribute given the clan's free dot, if one could be.
    var favoredAttribute: AttributeKind?
    var problems: Set<CreationProblem> = []

    var isWithinLimits: Bool { problems.isEmpty }
}

/// Something about to be added to the sheet, so a picker can tell whether it fits.
enum PendingTrait {
    case discipline(DisciplineEntry?)
    case merit(MeritEntry?, rating: Int)
    case ritual(discipline: TraitSource, dots: Int)
}

extension Character {
    var isInCreation: Bool {
        creation != nil
    }

    /// Where the character stands now.
    var creationReport: CreationReport {
        creationReport(levels: traitSnapshot.levels)
    }

    /// Where the character would stand with these trait ratings, and perhaps one more trait added.
    func creationReport(levels: [TraitKey: Int], adding pending: PendingTrait? = nil) -> CreationReport {
        var report = CreationReport()
        let level = { (key: TraitKey) in levels[key] ?? 0 }

        // Attributes: one free dot each, then 5/4/3, with the clan's favoured Attribute getting a free dot
        var attributeDots: [TraitCategory: Int] = [:]
        for kind in AttributeKind.allCases {
            attributeDots[kind.category, default: 0] += max(level(TraitKey(.attribute, kind.rawValue)) - 1, 0)
        }
        let favored = (clanEntry?.favoredAttributes ?? []).filter { level(TraitKey(.attribute, $0.rawValue)) >= 2 }
        // Try each way of placing the clan's dot (or none), and keep the one that fits best
        let options: [AttributeKind?] = favored.map { $0 } + [nil]
        let placed = options.map { favorite -> (AttributeKind?, [TraitCategory: CreationBudget]) in
            var dots = attributeDots
            if let favorite { dots[favorite.category, default: 0] -= 1 }
            return (favorite, Self.budgets(for: dots, allotments: CreationRules.attributeDots))
        }
        let best = placed.min { Self.overspend($0.1) < Self.overspend($1.1) }
        report.attributes = best?.1 ?? [:]
        report.favoredAttribute = best?.0 ?? nil
        if Self.overspend(report.attributes) > 0 { report.problems.insert(.attributesOverBudget) }

        // Skills: 11/7/4
        var skillDots: [TraitCategory: Int] = [:]
        var specialties = 0
        for skill in skills {
            guard let category = skill.definition?.category else { continue }
            skillDots[category, default: 0] += level(TraitKey(.skill, skill.skillID.rawValue))
            specialties += level(TraitKey(.specialty, skill.skillID.rawValue))
        }
        report.skills = Self.budgets(for: skillDots, allotments: CreationRules.skillDots)
        if Self.overspend(report.skills) > 0 { report.problems.insert(.skillsOverBudget) }
        report.specialties = CreationBudget(used: specialties, allowed: CreationRules.specialties)
        if specialties > CreationRules.specialties { report.problems.insert(.tooManySpecialties) }

        // Disciplines: three dots, at most one out-of-clan; the third may be Crúac, Theban Sorcery or the Mystery's Coil
        var disciplineEntries = disciplines.map { ($0.entry, level(TraitKey(.discipline, $0.id.uuidString))) }
        if case .discipline(let entry) = pending { disciplineEntries.append((entry, 1)) }
        var disciplineDots = 0
        var outOfClan = 0
        for (entry, dots) in disciplineEntries where dots > 0 {
            disciplineDots += dots
            if let entry, inClanDisciplines.contains(entry.id), entry.kind != .ritual { continue }
            outOfClan += dots
            if let rules = entry?.ritualRules, covenantStatus(rules.covenant) < rules.covenantStatusMinimum {
                let covenant = Catalog.bundled.covenants.entry(rules.covenant)?.name ?? rules.covenant
                report.problems.insert(.sorceryWithoutStatus(discipline: entry?.name ?? "", covenant: covenant))
            }
        }
        for coil in coils {
            let dots = level(TraitKey(.coil, coil.id.uuidString))
            guard dots > 0 else { continue }
            disciplineDots += dots
            outOfClan += dots
            if !isMysteryCoil(coil) { report.problems.insert(.coilOutsideMystery) }
            if ordoDraculStatus < 1 { report.problems.insert(.coilWithoutStatus) }
        }
        report.disciplines = CreationBudget(used: disciplineDots, allowed: CreationRules.disciplineDots)
        if disciplineDots > CreationRules.disciplineDots { report.problems.insert(.tooManyDisciplineDots) }
        // Only checked when the clan is known, since a custom clan's Disciplines aren't
        if clanEntry != nil, outOfClan > CreationRules.outOfClanDisciplineDots {
            report.problems.insert(.tooFewInClanDisciplineDots)
        }

        // Rituals: the one that comes with each dot, none above the Discipline's dots
        var ritualList = rituals.filter { level(TraitKey(.ritual, $0.id.uuidString)) > 0 }.map { ($0.discipline, $0.dots, $0.name) }
        if case .ritual(let discipline, let dots) = pending { ritualList.append((discipline, dots, "The ritual")) }
        for discipline in Set(ritualList.map(\.0)) {
            let known = ritualList.filter { $0.0 == discipline }
            let rating = disciplines.filter { $0.source == discipline }
                .map { level(TraitKey(.discipline, $0.id.uuidString)) }.max() ?? 0
            let name = Catalog.bundled.disciplines.name(of: discipline)
            if known.count > rating { report.problems.insert(.tooManyRituals(discipline: name)) }
            for ritual in known where ritual.1 > rating {
                report.problems.insert(.ritualAboveDiscipline(ritual: ritual.2))
            }
        }

        let devotionsOrScales = devotions.contains { level(TraitKey(.devotion, $0.id.uuidString)) > 0 }
            || scales.contains { level(TraitKey(.scale, $0.id.uuidString)) > 0 }
        if devotionsOrScales { report.problems.insert(.devotionsOrScales) }

        // Merits: ten dots, five of which buy each extra dot of Blood Potency
        var meritList = merits.map { ($0.entry, $0.name, level(TraitKey(.merit, $0.id.uuidString))) }
        if case .merit(let entry, let rating) = pending { meritList.append((entry, entry?.name ?? "", rating)) }
        let bloodPotency = level(TraitKey(.bloodPotency, "bloodPotency"))
        let meritDots = meritList.map(\.2).reduce(0, +) + max(bloodPotency - 1, 0) * CreationRules.meritDotsPerBloodPotency
        report.merits = CreationBudget(used: meritDots, allowed: CreationRules.meritDots)
        if meritDots > CreationRules.meritDots { report.problems.insert(.tooManyMeritDots) }
        for (entry, name, _) in meritList where entry?.unavailableToKindred == true {
            report.problems.insert(.meritUnavailableToKindred(merit: name))
        }
        if bloodPotency > CreationRules.maxBloodPotency { report.problems.insert(.bloodPotencyTooHigh) }
        if level(TraitKey(.humanity, "humanity")) > CreationRules.humanity { report.problems.insert(.humanityTooHigh) }

        return report
    }

    // MARK: - Hard limits

    /// The highest rating the trait can be set to during creation without breaking a new rule,
    /// or `nil` when the character isn't being created. Never below the current rating.
    func creationMaximum(for key: TraitKey, upTo cap: Int) -> Int? {
        guard isInCreation else { return nil }
        var levels = traitSnapshot.levels
        let current = levels[key] ?? 0
        let existing = creationReport(levels: levels).problems
        for rating in stride(from: cap, to: current, by: -1) {
            levels[key] = rating
            if creationReport(levels: levels).problems.isSubset(of: existing) {
                return rating
            }
        }
        return current
    }

    /// The highest rating for a row on the sheet: the creation limit while creating, otherwise `cap`.
    func editableMaximum(for key: TraitKey, upTo cap: Int) -> Int {
        creationMaximum(for: key, upTo: cap) ?? cap
    }

    /// Whether adding the trait keeps the character within the starting dots. Always true outside creation.
    func creationAllows(_ pending: PendingTrait) -> Bool {
        guard isInCreation else { return true }
        let levels = traitSnapshot.levels
        let existing = creationReport(levels: levels).problems
        return creationReport(levels: levels, adding: pending).problems.isSubset(of: existing)
    }

    /// Whether Devotions and Scales can be added: not during creation.
    var canLearnDevotionsAndScales: Bool {
        !isInCreation
    }

    /// Whether a Specialty can be added: during creation, only while fewer than three are taken.
    var canAddSpecialty: Bool {
        !isInCreation || creationReport.specialties.remaining > 0
    }

    // MARK: - Priorities

    /// Gives the categories with the most dots the largest allotments: primary, secondary, tertiary.
    private static func budgets(for dots: [TraitCategory: Int], allotments: [Int]) -> [TraitCategory: CreationBudget] {
        // Ties keep the sheet's order (Mental, Physical, Social), so the budgets shown don't jump about
        let ordered = TraitCategory.allCases.enumerated().sorted { lhs, rhs in
            let (left, right) = (dots[lhs.element] ?? 0, dots[rhs.element] ?? 0)
            return left != right ? left > right : lhs.offset < rhs.offset
        }.map(\.element)
        var budgets: [TraitCategory: CreationBudget] = [:]
        for (category, allowed) in zip(ordered, allotments) {
            budgets[category] = CreationBudget(used: dots[category] ?? 0, allowed: allowed)
        }
        return budgets
    }

    private static func overspend(_ budgets: [TraitCategory: CreationBudget]) -> Int {
        budgets.values.reduce(0) { $0 + max($1.used - $1.allowed, 0) }
    }
}
