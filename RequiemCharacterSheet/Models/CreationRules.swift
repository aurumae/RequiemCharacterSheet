//
//  CreationRules.swift
//  RequiemCharacterSheet
//

import Foundation
#if SWIFT_PACKAGE
import ChroniclesCore
#endif

/// A character being made with guided creation (Vampire: The Requiem pp. 79–84). While it's set,
/// the sheet holds the character to the book's starting dots: hard limits, not warnings.
struct CreationState: Codable, Equatable {
    /// Bonus Experiences for an experienced character, added when creation is finished.
    var bonusExperiences = 0
    /// The Attribute the player gave the clan's free dot. It's outside the 5/4/3.
    var favoredAttribute: AttributeKind?
    /// Each category's priority as the player chose it: 0 primary, 1 secondary, 2 tertiary.
    /// A category has no dots to spend until it has one.
    var attributePriorities: [TraitCategory: Int] = [:]
    var skillPriorities: [TraitCategory: Int] = [:]

    enum CodingKeys: CodingKey {
        case bonusExperiences, favoredAttribute, attributePriorities, skillPriorities
    }

    init(bonusExperiences: Int = 0, favoredAttribute: AttributeKind? = nil,
         attributePriorities: [TraitCategory: Int] = [:], skillPriorities: [TraitCategory: Int] = [:]) {
        self.bonusExperiences = bonusExperiences
        self.favoredAttribute = favoredAttribute
        self.attributePriorities = attributePriorities
        self.skillPriorities = skillPriorities
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bonusExperiences = try container.decode(.bonusExperiences, default: 0)
        favoredAttribute = try container.decodeIfPresent(AttributeKind.self, forKey: .favoredAttribute)
        attributePriorities = try container.decode(.attributePriorities, default: [:])
        skillPriorities = try container.decode(.skillPriorities, default: [:])
    }
}

/// Which priority a category has: the attributes' 5/4/3 or the skills' 11/7/4.
enum CreationPriority: Int, CaseIterable {
    case primary, secondary, tertiary

    var name: String {
        switch self {
        case .primary: return "Primary"
        case .secondary: return "Secondary"
        case .tertiary: return "Tertiary"
        }
    }
}

/// The book's starting dots.
enum CreationRules {
    /// Bonus Experiences a Storyteller may allow for a more experienced vampire (p. 82).
    static let experiencedRanks: [(name: String, experiences: Int)] = [
        ("Starting character", 0),
        ("Around the block", 5),
        ("Rising star", 10),
        ("Ancilla", 15),
        ("Rank elder", 25),
        ("Mover and shaker", 35),
        ("Urban Legend", 50),
        ("Methuselah", 100),
    ]

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
    /// For Attribute and Skill categories: the priority the player chose, if they have.
    var priority: CreationPriority?

    init(used: Int, allowed: Int, priority: CreationPriority? = nil) {
        self.used = used
        self.allowed = allowed
        self.priority = priority
    }

    var remaining: Int { allowed - used }
}

/// A starting-dots rule the character breaks.
enum CreationProblem: Hashable {
    case attributesOverBudget(TraitCategory)
    case skillsOverBudget(TraitCategory)
    case tooManySpecialties
    case tooManyDisciplineDots
    case tooFewInClanDisciplineDots
    /// Crúac or Theban Sorcery without Status in its covenant.
    /// `requirement` is e.g. "Circle of the Crone Status 1".
    case sorceryWithoutStatus(discipline: String, requirement: String)
    case coilWithoutStatus
    case coilOutsideMystery
    case tooManyRituals(discipline: String)
    case ritualAboveDiscipline(ritual: String)
    case devotionsOrScales
    case tooManyMeritDots
    case meritUnavailableToKindred(merit: String)
    case meritPrerequisitesUnmet(merit: String)
    case bloodPotencyTooHigh
    case humanityTooHigh

    /// Which reason to give first when several apply, e.g. running out of dots before needing Status.
    var priority: Int {
        switch self {
        case .tooManyDisciplineDots, .tooManyMeritDots, .attributesOverBudget, .skillsOverBudget, .tooManySpecialties:
            return 0
        case .sorceryWithoutStatus, .coilWithoutStatus, .coilOutsideMystery, .meritUnavailableToKindred, .meritPrerequisitesUnmet:
            return 1
        default:
            return 2
        }
    }

    var description: String {
        switch self {
        case .attributesOverBudget(let category):
            return "More \(category.name) Attribute dots than its priority allows"
        case .skillsOverBudget(let category):
            return "More \(category.name) Skill dots than its priority allows"
        case .tooManySpecialties:
            return "More than 3 Specialties"
        case .tooManyDisciplineDots:
            return "More than 3 Discipline dots"
        case .tooFewInClanDisciplineDots:
            return "At least 2 Discipline dots must be in-clan"
        case .sorceryWithoutStatus(let discipline, let requirement):
            return "\(discipline) needs \(requirement)"
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
        case .meritPrerequisitesUnmet(let merit):
            return "\(merit)'s prerequisites aren't met"
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
    var problems: Set<CreationProblem> = []

    var isWithinLimits: Bool { problems.isEmpty }

    /// Dots spent beyond every budget, so a change can't make a category that's already over any worse.
    var overspend: Int {
        let budgets = Array(attributes.values) + Array(skills.values) + [specialties, disciplines, merits]
        return budgets.reduce(0) { $0 + max(-$1.remaining, 0) }
    }

    /// Whether `other` breaks no rule this report doesn't, and isn't further over budget.
    func allows(_ other: CreationReport) -> Bool {
        other.problems.isSubset(of: problems) && other.overspend <= overspend
    }
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

        // Attributes: one free dot each, and the clan's dot on the favoured Attribute, then 5/4/3 by priority
        var attributeDots: [TraitCategory: Int] = [:]
        for kind in AttributeKind.allCases {
            let free = kind == creation?.favoredAttribute ? 2 : 1
            attributeDots[kind.category, default: 0] += max(level(TraitKey(.attribute, kind.rawValue)) - free, 0)
        }
        report.attributes = Self.budgets(for: attributeDots, priorities: creation?.attributePriorities ?? [:],
                                         allotments: CreationRules.attributeDots)
        for (category, budget) in report.attributes where budget.remaining < 0 {
            report.problems.insert(.attributesOverBudget(category))
        }

        // Skills: 11/7/4
        var skillDots: [TraitCategory: Int] = [:]
        var specialties = 0
        for skill in skills {
            guard let category = skill.definition?.category else { continue }
            skillDots[category, default: 0] += level(TraitKey(.skill, skill.skillID.rawValue))
            specialties += level(TraitKey(.specialty, skill.skillID.rawValue))
        }
        report.skills = Self.budgets(for: skillDots, priorities: creation?.skillPriorities ?? [:],
                                     allotments: CreationRules.skillDots)
        for (category, budget) in report.skills where budget.remaining < 0 {
            report.problems.insert(.skillsOverBudget(category))
        }
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
            if let entry, entry.ritualRules != nil, !hasRitualStatus(for: entry) {
                report.problems.insert(.sorceryWithoutStatus(discipline: entry.name, requirement: Self.ritualRequirementText(for: entry)))
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
        for (entry, name, _) in meritList {
            guard let entry else { continue }
            if entry.unavailableToKindred {
                report.problems.insert(.meritUnavailableToKindred(merit: name))
            } else if !unmetPrerequisites(for: entry).isEmpty {
                // Prerequisites are hard limits at creation too, e.g. Attaché needs Invictus Status
                report.problems.insert(.meritPrerequisitesUnmet(merit: name))
            }
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
        let existing = creationReport(levels: levels)
        for rating in stride(from: cap, to: current, by: -1) {
            levels[key] = rating
            if existing.allows(creationReport(levels: levels)) {
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
        return creationReport(levels: levels).allows(creationReport(levels: levels, adding: pending))
    }

    /// Whether Devotions and Scales can be added: not during creation.
    var canLearnDevotionsAndScales: Bool {
        !isInCreation
    }

    /// Whether a Specialty can be added: during creation, only while fewer than three are taken.
    var canAddSpecialty: Bool {
        !isInCreation || creationReport.specialties.remaining > 0
    }

    // MARK: - Priorities and the clan's dot

    /// Each category's dots against the allotment for the priority the player gave it; none until they choose.
    private static func budgets(for dots: [TraitCategory: Int], priorities: [TraitCategory: Int],
                                allotments: [Int]) -> [TraitCategory: CreationBudget] {
        var budgets: [TraitCategory: CreationBudget] = [:]
        for category in TraitCategory.allCases {
            let priority = priorities[category].flatMap(CreationPriority.init(rawValue:))
            budgets[category] = CreationBudget(used: dots[category] ?? 0,
                                               allowed: priority.map { allotments[$0.rawValue] } ?? 0,
                                               priority: priority)
        }
        return budgets
    }

    /// Gives a category a priority. The category that had it swaps to this one's old priority, or has none.
    func setPriority(_ priority: CreationPriority, for category: TraitCategory, skills: Bool) {
        guard var state = creation else { return }
        var priorities = skills ? state.skillPriorities : state.attributePriorities
        let old = priorities[category]
        if let other = priorities.first(where: { $0.value == priority.rawValue && $0.key != category })?.key {
            priorities[other] = old
        }
        priorities[category] = priority.rawValue
        if skills {
            state.skillPriorities = priorities
        } else {
            state.attributePriorities = priorities
        }
        creation = state
    }

    /// Whether the player still has to choose which favoured Attribute takes the clan's dot.
    var needsFavoredAttribute: Bool {
        isInCreation && !creationFavoredAttributes.isEmpty && creation?.favoredAttribute == nil
    }

    /// The Attributes the free dot can go on during guided creation. A bloodline chosen at creation that has its own
    /// favoured Attributes, like the Bron's, replaces the clan's.
    var creationFavoredAttributes: [AttributeKind] {
        if let own = bloodlineEntry?.favoredAttributes, !own.isEmpty { return own }
        return clanEntry?.favoredAttributes ?? []
    }

    /// Who gives the free dot during guided creation: the bloodline when its favoured Attributes replace the clan's.
    var creationFavoredAttributeGiver: String? {
        if let bloodline = bloodlineEntry, !bloodline.favoredAttributes.isEmpty { return bloodline.name }
        return clanEntry?.name
    }

    /// Outside guided creation, every favoured Attribute of the clan and of the bloodline, each with where it comes
    /// from, e.g. Presence (Ventrue, Bron). Adopting a bloodline later doesn't move the dot, so the player picks.
    var favoredAttributeSources: [(attribute: AttributeKind, sources: [String])] {
        var sources: [(String, [AttributeKind])] = []
        if let clan = clanEntry { sources.append((clan.name, clan.favoredAttributes)) }
        if let bloodline = bloodlineEntry, !bloodline.favoredAttributes.isEmpty {
            sources.append((bloodline.name, bloodline.favoredAttributes))
        }
        let attributes = sources.flatMap(\.1).reduce(into: [AttributeKind]()) { if !$0.contains($1) { $0.append($1) } }
        return attributes.map { kind in (kind, sources.filter { $0.1.contains(kind) }.map(\.0)) }
    }

    /// The favoured Attributes worded for display, e.g. "Presence (Ventrue and Bron), Resolve (Ventrue) or Stamina (Bron)".
    var favoredAttributesText: String {
        let parts = favoredAttributeSources.map { "\($0.attribute.name) (\($0.sources.joined(separator: " and ")))" }
        guard let last = parts.last else { return "" }
        return parts.count == 1 ? last : parts.dropLast().joined(separator: ", ") + " or " + last
    }

    /// Puts the clan's free dot on one of its favoured Attributes, moving it from any other.
    func chooseFavoredAttribute(_ kind: AttributeKind) {
        guard var state = creation, state.favoredAttribute != kind else { return }
        if let old = state.favoredAttribute, let attribute = attributes.first(where: { $0.kind == old }) {
            attribute.rating = max(attribute.rating - 1, 1)
        }
        if let attribute = attributes.first(where: { $0.kind == kind }) {
            attribute.rating = min(attribute.rating + 1, 5)
        }
        state.favoredAttribute = kind
        creation = state
    }

    /// Takes the clan's dot back off, e.g. when the clan changes.
    func clearFavoredAttribute() {
        guard var state = creation, let old = state.favoredAttribute else { return }
        if let attribute = attributes.first(where: { $0.kind == old }) {
            attribute.rating = max(attribute.rating - 1, 1)
        }
        state.favoredAttribute = nil
        creation = state
    }

    /// The lowest rating an Attribute can be set to: 2 for the one with the clan's dot during creation.
    func minimumRating(of kind: AttributeKind) -> Int {
        creation?.favoredAttribute == kind ? 2 : 1
    }
}

// MARK: - Steps

/// One of the book's seven creation steps, with how far along the character is.
struct CreationStep: Identifiable, Equatable {
    enum Status: Equatable {
        case done, inProgress, problem
    }

    let number: Int
    let title: String
    /// e.g. "Physical 5 of 5 · Mental 3 of 4 · Social 0 of 3".
    let detail: String
    let status: Status

    var id: Int { number }
}

extension Character {
    /// A new character made with guided creation: held to the starting dots, with XP Mode off.
    static func guided() -> Character {
        let character = Character()
        character.creation = CreationState()
        return character
    }

    /// The seven steps of creation (pp. 79–82), each with its budget and whether it's done.
    var creationSteps: [CreationStep] {
        let report = creationReport
        let problems = report.problems
        func status(done: Bool, problemsIn area: Set<CreationProblem>) -> CreationStep.Status {
            if !problems.isDisjoint(with: area) { return .problem }
            return done ? .done : .inProgress
        }
        /// e.g. "Physical (primary) 5 of 5 · Mental (secondary) 2 of 4 · Social: choose a priority".
        func describe(_ budgets: [TraitCategory: CreationBudget]) -> String {
            guard budgets.values.contains(where: { $0.priority != nil }) else {
                return "Choose a priority for each category"
            }
            // By priority; categories without one keep the sheet's order
            let order = TraitCategory.allCases
            return budgets.sorted {
                ($0.value.priority?.rawValue ?? 3, order.firstIndex(of: $0.key) ?? 0)
                    < ($1.value.priority?.rawValue ?? 3, order.firstIndex(of: $1.key) ?? 0)
            }
                .map { category, budget in
                    guard let priority = budget.priority else { return "\(category.name): choose a priority" }
                    return "\(category.name) (\(priority.name.lowercased())) \(budget.used) of \(budget.allowed)"
                }
                .joined(separator: " · ")
        }
        func isSpent(_ budgets: [TraitCategory: CreationBudget]) -> Bool {
            budgets.values.allSatisfy { $0.priority != nil && $0.remaining == 0 }
        }
        let attributeProblems = Set(TraitCategory.allCases.map(CreationProblem.attributesOverBudget))
        let skillProblems = Set(TraitCategory.allCases.map(CreationProblem.skillsOverBudget))

        let aspirationCount = aspirations.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }.count
        let hasConcept = !concept.trimmingCharacters(in: .whitespaces).isEmpty

        // On Humanity 6, or 7 for the Ventrue
        let touchstoneLevel = clanEntry?.bane.firstTouchstoneHumanity ?? 6
        let touchstone = touchstones.first { $0.level == touchstoneLevel }?.text.trimmingCharacters(in: .whitespaces) ?? ""
        var missing: [String] = []
        if clan.isEmpty { missing.append("clan") }
        if needsFavoredAttribute { missing.append("the clan's favoured Attribute") }
        if mask.isEmpty { missing.append("Mask") }
        if dirge.isEmpty { missing.append("Dirge") }
        if touchstone.isEmpty { missing.append("Touchstone on Humanity \(touchstoneLevel)") }
        var kindredDetail = "Disciplines \(report.disciplines.used) of \(report.disciplines.allowed)"
        if !missing.isEmpty {
            kindredDetail = "Needs " + missing.joined(separator: ", ") + " · " + kindredDetail
        }
        let disciplineProblems: Set<CreationProblem> = Set(problems.filter {
            switch $0 {
            case .tooManyDisciplineDots, .tooFewInClanDisciplineDots, .sorceryWithoutStatus, .coilWithoutStatus,
                 .coilOutsideMystery, .tooManyRituals, .ritualAboveDiscipline, .devotionsOrScales, .humanityTooHigh:
                return true
            default:
                return false
            }
        })
        let meritProblems: Set<CreationProblem> = Set(problems.filter {
            switch $0 {
            case .tooManyMeritDots, .meritUnavailableToKindred, .meritPrerequisitesUnmet, .bloodPotencyTooHigh:
                return true
            default:
                return false
            }
        })

        return [
            CreationStep(number: 1, title: "Concept",
                         detail: "A concept and three Aspirations (\(aspirationCount) of 3)",
                         status: hasConcept && aspirationCount >= 3 ? .done : .inProgress),
            CreationStep(number: 2, title: "Attributes", detail: describe(report.attributes),
                         status: status(done: isSpent(report.attributes), problemsIn: attributeProblems)),
            CreationStep(number: 3, title: "Skills", detail: describe(report.skills),
                         status: status(done: isSpent(report.skills), problemsIn: skillProblems)),
            CreationStep(number: 4, title: "Skill Specialties",
                         detail: "\(report.specialties.used) of \(report.specialties.allowed)",
                         status: status(done: report.specialties.remaining == 0, problemsIn: [.tooManySpecialties])),
            CreationStep(number: 5, title: "Kindred Traits", detail: kindredDetail,
                         status: status(done: missing.isEmpty && report.disciplines.remaining == 0, problemsIn: disciplineProblems)),
            CreationStep(number: 6, title: "Merits",
                         detail: "\(report.merits.used) of \(report.merits.allowed), counting Blood Potency \(bloodPotency)",
                         status: status(done: report.merits.remaining == 0, problemsIn: meritProblems)),
            CreationStep(number: 7, title: "Advantages", detail: "Worked out for you from the traits above", status: .done),
        ]
    }

    /// The steps not yet done, for the reminder before finishing.
    var unfinishedCreationSteps: [CreationStep] {
        creationSteps.filter { $0.status != .done }
    }

    /// Ends guided creation: adds any bonus Experiences for an experienced vampire and turns XP Mode on,
    /// so what's bought from now on is paid for.
    func finishCreation(bonusExperiences: Int) {
        guard isInCreation else { return }
        creation = nil
        experiences += bonusExperiences
        xpMode = true
    }

    /// Stops guided creation without finishing it, leaving a blank sheet with no limits.
    func leaveCreation() {
        creation = nil
    }
}
