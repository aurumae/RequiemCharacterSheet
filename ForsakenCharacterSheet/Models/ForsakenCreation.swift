//
//  ForsakenCreation.swift
//  ForsakenCharacterSheet
//
//  Guided creation for werewolves: the core book's quick reference (pp. 82–84) for the Forsaken and Ghost Wolves,
//  and Night Horrors: Shunned by the Moon's for the Pure. While it's set, the sheet holds the character to the
//  starting dots: hard limits, not warnings.
//

import Foundation

/// A character being made with guided creation.
struct CreationState: Codable, Equatable {
    /// Each category's priority as the player chose it: 0 primary, 1 secondary, 2 tertiary.
    var attributePriorities: [TraitCategory: Int] = [:]
    var skillPriorities: [TraitCategory: Int] = [:]
    /// The Skill given the free dot from the auspice's Skills, or a Pure tribe's.
    var freeSkill: SkillID?

    init() {}

    enum CodingKeys: CodingKey {
        case attributePriorities, skillPriorities, freeSkill
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attributePriorities = try container.decode(.attributePriorities, default: [:])
        skillPriorities = try container.decode(.skillPriorities, default: [:])
        freeSkill = try container.decodeIfPresent(SkillID.self, forKey: .freeSkill)
    }
}

/// Which priority a category has: the Attributes' 5/4/3 or the Skills' 11/7/4.
enum CreationPriority: Int, CaseIterable {
    case primary, secondary, tertiary

    var name: String {
        switch self {
        case .primary: "Primary"
        case .secondary: "Secondary"
        case .tertiary: "Tertiary"
        }
    }
}

/// The books' starting dots.
enum CreationRules {
    static let attributeDots = [5, 4, 3]
    static let skillDots = [11, 7, 4]
    static let specialties = 3
    static let meritDots = 10
    /// Rites come free up to two dots; up to five more cost a Merit dot each.
    static let freeRiteDots = 2
    static let maxRiteDotsFromMerits = 5
    /// Each Primal Urge dot past the first costs five Merit dots, up to Primal Urge 3.
    static let meritDotsPerPrimalUrge = 5
    static let maxPrimalUrge = 3
    static let harmony = 7
    /// No Renown above two at creation.
    static let maxRenown = 2
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
    case tooManyRenownDots(allowed: Int)
    case renownAboveTwo
    case renownMissing(String)
    case pureRenownElsewhere
    case tooManyShadowFacets(allowed: Int)
    case shadowFacetOutsideAffinities
    case tooManyWolfFacets(allowed: Int)
    case facetWithoutRenown(facet: String, renown: String)
    case tooManyRiteDots
    case tooManyMeritDots
    case meritUnavailable(merit: String)
    case meritPrerequisitesUnmet(merit: String)
    case primalUrgeTooHigh
    case harmonyNotSeven

    /// Which reason to give first when several apply, e.g. running out of dots before needing Renown.
    var priority: Int {
        switch self {
        case .attributesOverBudget, .skillsOverBudget, .tooManySpecialties, .tooManyRenownDots, .tooManyShadowFacets,
             .tooManyWolfFacets, .tooManyRiteDots, .tooManyMeritDots:
            0
        default:
            1
        }
    }

    var description: String {
        switch self {
        case .attributesOverBudget(let category):
            "More \(category.name) Attribute dots than its priority allows"
        case .skillsOverBudget(let category):
            "More \(category.name) Skill dots than its priority allows"
        case .tooManySpecialties:
            "More than 3 Specialties"
        case .tooManyRenownDots(let allowed):
            "More than \(allowed) Renown dots"
        case .renownAboveTwo:
            "No Renown can start above 2"
        case .renownMissing(let what):
            "\(what) needs a dot"
        case .pureRenownElsewhere:
            "The Pure's second Renown dot goes in the tribe's primary or secondary Renown"
        case .tooManyShadowFacets(let allowed):
            "More than \(allowed) Shadow Gift Facets"
        case .shadowFacetOutsideAffinities:
            "Too many Shadow Gift Facets outside your tribe's and auspice's Gifts"
        case .tooManyWolfFacets(let allowed):
            allowed == 0 ? "No Wolf Gift Facet: two dots of auspice Renown bring the Moon Gift's second Facet instead"
                : "More than \(allowed) Wolf Gift Facet"
        case .facetWithoutRenown(let facet, let renown):
            "\(facet) needs a dot of \(renown)"
        case .tooManyRiteDots:
            "More than 7 dots of Rites (2 free, up to 5 from Merit dots)"
        case .tooManyMeritDots:
            "More than 10 Merit dots, counting extra Rites and 5 per extra dot of Primal Urge"
        case .meritUnavailable(let merit):
            "\(merit) isn't available to werewolves"
        case .meritPrerequisitesUnmet(let merit):
            "\(merit)'s prerequisites aren't met"
        case .primalUrgeTooHigh:
            "Primal Urge can start at most at 3"
        case .harmonyNotSeven:
            "Harmony starts at 7"
        }
    }
}

/// Where a character stands against the starting dots.
struct CreationReport: Equatable {
    var attributes: [TraitCategory: CreationBudget] = [:]
    var skills: [TraitCategory: CreationBudget] = [:]
    var specialties = CreationBudget(used: 0, allowed: CreationRules.specialties)
    var renown = CreationBudget(used: 0, allowed: 3)
    var shadowFacets = CreationBudget(used: 0, allowed: 2)
    var wolfFacets = CreationBudget(used: 0, allowed: 1)
    var rites = CreationBudget(used: 0, allowed: CreationRules.freeRiteDots)
    /// Merit dots, plus extra Rites and five for each extra dot of Primal Urge.
    var merits = CreationBudget(used: 0, allowed: CreationRules.meritDots)
    var problems: Set<CreationProblem> = []

    var isWithinLimits: Bool { problems.isEmpty }

    /// Dots spent beyond every budget, so a change can't make a category that's already over any worse.
    var overspend: Int {
        let budgets = Array(attributes.values) + Array(skills.values)
            + [specialties, renown, shadowFacets, wolfFacets, merits]
        return budgets.reduce(0) { $0 + max(-$1.remaining, 0) }
    }

    /// Whether `other` breaks no rule this report doesn't, and isn't further over budget.
    func allows(_ other: CreationReport) -> Bool {
        other.problems.isSubset(of: problems) && other.overspend <= overspend
    }
}

/// Something about to be added to the sheet, so a picker can tell whether it fits.
enum PendingTrait {
    case merit(MeritEntry?, rating: Int)
    case facet(GiftEntry.Facet, gift: GiftEntry)
    case rite(dots: Int)
}

extension ForsakenCharacter {
    var isInCreation: Bool {
        creation != nil
    }

    /// Where the character stands now.
    var creationReport: CreationReport {
        creationReport(levels: traitSnapshot.levels)
    }

    /// The Skills the free creation dot can go on: the auspice's, or a Pure tribe's.
    var freeSkillChoices: [SkillID] {
        (isPure ? tribeEntry?.skills : auspiceEntry?.skills) ?? []
    }

    /// Who gives the free Skill dot, e.g. "Rahu" or "Predator Kings".
    var freeSkillGiver: String? {
        isPure ? tribeEntry?.name : auspiceEntry?.name
    }

    /// The Totem dots every new character gets: one, or two for the Pure (Shunned by the Moon, p. 202).
    var freeTotemDots: Int {
        isPure ? 2 : 1
    }

    /// Where the character would stand with these trait ratings, and perhaps one more trait added.
    func creationReport(levels: [TraitKey: Int], adding pending: PendingTrait? = nil) -> CreationReport {
        var report = CreationReport()
        let level = { (key: TraitKey) in levels[key] ?? 0 }

        // Attributes: one free dot each, then 5/4/3 by priority
        var attributeDots: [TraitCategory: Int] = [:]
        for kind in AttributeKind.allCases {
            attributeDots[kind.category, default: 0] += max(level(TraitKey(.attribute, kind.rawValue)) - 1, 0)
        }
        report.attributes = Self.budgets(for: attributeDots, priorities: creation?.attributePriorities ?? [:],
                                         allotments: CreationRules.attributeDots)
        for (category, budget) in report.attributes where budget.remaining < 0 {
            report.problems.insert(.attributesOverBudget(category))
        }

        // Skills: 11/7/4, besides the auspice's (or Pure tribe's) free dot
        var skillDots: [TraitCategory: Int] = [:]
        var specialties = 0
        for skill in skills {
            guard let category = skill.definition?.category else { continue }
            let rating = level(TraitKey(.skill, skill.skillID.rawValue))
            let free = skill.skillID == creation?.freeSkill && freeSkillChoices.contains(skill.skillID) && rating > 0 ? 1 : 0
            skillDots[category, default: 0] += rating - free
            specialties += level(TraitKey(.specialty, skill.skillID.rawValue))
        }
        report.skills = Self.budgets(for: skillDots, priorities: creation?.skillPriorities ?? [:],
                                     allotments: CreationRules.skillDots)
        for (category, budget) in report.skills where budget.remaining < 0 {
            report.problems.insert(.skillsOverBudget(category))
        }
        report.specialties = CreationBudget(used: specialties, allowed: CreationRules.specialties)
        if specialties > CreationRules.specialties { report.problems.insert(.tooManySpecialties) }

        // Renown: the auspice's and the tribe's, and one more (Ghost Wolves have no tribe's); the Pure have the
        // tribe's primary Renown and a dot in it or a secondary one
        let renownLevels = Dictionary(uniqueKeysWithValues: Renown.allCases.map { ($0, level(TraitKey(.renown, $0.rawValue))) })
        let renownDots = renownLevels.values.reduce(0, +)
        let renownAllowed = isPure || tribeEntry?.kind == .ghostWolf ? 2 : 3
        report.renown = CreationBudget(used: renownDots, allowed: renownAllowed)
        if renownDots > renownAllowed { report.problems.insert(.tooManyRenownDots(allowed: renownAllowed)) }
        if renownLevels.values.contains(where: { $0 > CreationRules.maxRenown }) { report.problems.insert(.renownAboveTwo) }
        if renownDots >= renownAllowed {
            if let auspice = effectiveAuspice, renownLevels[auspice.renown] == 0 {
                report.problems.insert(.renownMissing("\(auspice.name) Renown (\(auspice.renown.name))"))
            }
            if let tribe = tribeEntry, let tribal = tribe.renown, renownLevels[tribal] == 0 {
                report.problems.insert(.renownMissing("\(tribe.name) Renown (\(tribal.name))"))
            }
        }
        if isPure, let tribe = tribeEntry, let primary = tribe.renown {
            let allowedRenown = Set([primary] + (tribe.secondaryRenown ?? []))
            if renownLevels.contains(where: { $0.value > 0 && !allowedRenown.contains($0.key) }) {
                report.problems.insert(.pureRenownElsewhere)
            }
        }

        // Gifts: two Shadow Facets from the tribe's or auspice's Gifts (the Pure: two from the tribe's and one from
        // any), and a Wolf Facet unless two dots of auspice Renown bring the Moon Gift's second Facet
        var gifts: [(gift: GiftEntry?, facet: GiftEntry.Facet?, name: String, kind: GiftEntry.Kind)] = facets
            .filter { level(TraitKey(.facet, $0.id.uuidString)) > 0 }
            .map { owned in
                let found = owned.source.catalogID.flatMap { Catalog.bundled.facet($0) }
                return (found?.gift, found?.facet, facetName(owned), found?.gift.kind ?? owned.customKind)
            }
        if case .facet(let facet, let gift) = pending { gifts.append((gift, facet, facet.name, gift.kind)) }
        let shadow = gifts.filter { $0.kind == .shadow }
        // A custom Gift can't be checked, so it counts as one of the character's own
        let outsideAffinities = shadow.filter { $0.gift.map { !affinityGifts.contains($0.id) } ?? false }.count
        let shadowAllowed = isPure ? 3 : 2
        report.shadowFacets = CreationBudget(used: shadow.count, allowed: shadowAllowed)
        if shadow.count > shadowAllowed { report.problems.insert(.tooManyShadowFacets(allowed: shadowAllowed)) }
        if outsideAffinities > (isPure ? 1 : 0) { report.problems.insert(.shadowFacetOutsideAffinities) }
        let auspiceRenown = effectiveAuspice.map { renownLevels[$0.renown] ?? 0 } ?? 0
        let wolfAllowed = !isPure && auspiceRenown >= 2 ? 0 : 1
        let wolf = gifts.filter { $0.kind == .wolf }.count
        report.wolfFacets = CreationBudget(used: wolf, allowed: wolfAllowed)
        if wolf > wolfAllowed { report.problems.insert(.tooManyWolfFacets(allowed: wolfAllowed)) }
        for gift in gifts {
            if let renown = gift.facet?.renown, renownLevels[renown] == 0 {
                report.problems.insert(.facetWithoutRenown(facet: gift.name, renown: renown.name))
            }
        }

        // Rites: two dots free, up to five more for a Merit dot each
        var riteDots = rites.reduce(0) { $0 + level(TraitKey(.rite, $1.id.uuidString)) }
        if case .rite(let dots) = pending { riteDots += dots }
        let extraRiteDots = max(riteDots - CreationRules.freeRiteDots, 0)
        report.rites = CreationBudget(used: riteDots, allowed: CreationRules.freeRiteDots)
        if extraRiteDots > CreationRules.maxRiteDotsFromMerits { report.problems.insert(.tooManyRiteDots) }

        // Merits: ten dots, besides the free Totem dots and Language (First Tongue); extra Rites and Primal Urge use them
        var meritList = merits.map { ($0.entry, $0.name, level(TraitKey(.merit, $0.id.uuidString)), $0.qualifier) }
        if case .merit(let entry, let rating) = pending { meritList.append((entry, entry?.name ?? "", rating, nil)) }
        var meritDots = 0
        var usedFreeLanguage = false
        for (entry, _, dots, qualifier) in meritList {
            var free = 0
            if entry?.id == "totem" {
                free = freeTotemDots
            } else if entry?.id == "language", !usedFreeLanguage,
                      qualifier?.matchesSearch("First Tongue") == true {
                free = 1
                usedFreeLanguage = true
            }
            meritDots += max(dots - free, 0)
        }
        let primalUrgeLevel = level(TraitKey(.primalUrge, "primalUrge"))
        meritDots += extraRiteDots + max(primalUrgeLevel - 1, 0) * CreationRules.meritDotsPerPrimalUrge
        report.merits = CreationBudget(used: meritDots, allowed: CreationRules.meritDots)
        if meritDots > CreationRules.meritDots { report.problems.insert(.tooManyMeritDots) }
        for (entry, name, _, _) in meritList {
            guard let entry else { continue }
            if meritUnavailableReason(entry) != nil {
                report.problems.insert(.meritUnavailable(merit: name))
            } else if !unmetPrerequisites(for: entry).isEmpty {
                report.problems.insert(.meritPrerequisitesUnmet(merit: name))
            }
        }
        if primalUrgeLevel > CreationRules.maxPrimalUrge { report.problems.insert(.primalUrgeTooHigh) }
        if harmony != CreationRules.harmony { report.problems.insert(.harmonyNotSeven) }

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

    /// Whether adding the trait keeps the character within the starting dots. Always true outside creation.
    func creationAllows(_ pending: PendingTrait) -> Bool {
        guard isInCreation else { return true }
        let levels = traitSnapshot.levels
        return creationReport(levels: levels).allows(creationReport(levels: levels, adding: pending))
    }

    // MARK: - Priorities and the free Skill dot

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

    /// Puts the free Skill dot on one of the auspice's (or Pure tribe's) Skills, moving it from any other.
    func chooseFreeSkill(_ id: SkillID) {
        guard var state = creation, state.freeSkill != id else { return }
        if let old = state.freeSkill, let skill = skill(old) {
            skill.rating = max(skill.rating - 1, 0)
        }
        if let skill = skill(id) {
            skill.rating = min(skill.rating + 1, 5)
        }
        state.freeSkill = id
        creation = state
    }

    /// Whether the free Skill dot still has to be placed.
    var needsFreeSkill: Bool {
        guard isInCreation, !freeSkillChoices.isEmpty else { return false }
        return creation?.freeSkill.map { !freeSkillChoices.contains($0) } ?? true
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
    let detail: String
    let status: Status

    var id: Int { number }
}

extension ForsakenCharacter {
    /// A new character made with guided creation: held to the starting dots, with XP Mode off, and with the Totem
    /// dot and Language (First Tongue) every werewolf starts with.
    static func guided() -> ForsakenCharacter {
        let character = ForsakenCharacter()
        character.creation = CreationState()
        character.merits = [
            Merit(source: .catalog("totem"), rating: 1),
            Merit(source: .catalog("language"), qualifier: "First Tongue", rating: 1),
        ]
        return character
    }

    /// The seven steps, each with its budget and whether it's done.
    var creationSteps: [CreationStep] {
        let report = creationReport
        let problems = report.problems
        func status(done: Bool, problemsIn area: Set<CreationProblem>) -> CreationStep.Status {
            if !problems.isDisjoint(with: area) { return .problem }
            return done ? .done : .inProgress
        }
        func describe(_ budgets: [TraitCategory: CreationBudget]) -> String {
            guard budgets.values.contains(where: { $0.priority != nil }) else {
                return "Choose a priority for each category"
            }
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

        var missing: [String] = []
        if tribe.isEmpty { missing.append("tribe") }
        if !isPure && auspice.isEmpty { missing.append("auspice") }
        if isPure && huntersAspect == nil { missing.append("Hunter's Aspect") }
        if needsFreeSkill, let giver = freeSkillGiver { missing.append("\(giver) Skill dot") }
        if blood.isEmpty { missing.append("Blood") }
        if bone.isEmpty { missing.append("Bone") }
        if fleshTouchstone.trimmingCharacters(in: .whitespaces).isEmpty
            || spiritTouchstone.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("Touchstones") }
        if case .custom(let name) = kuruthTriggerSource, name.isEmpty { missing.append("Kuruth triggers") }
        let traitsDetail = (missing.isEmpty ? "" : "Needs " + missing.joined(separator: ", ") + " · ")
            + "Renown \(report.renown.used) of \(report.renown.allowed)"
        let giftsDetail = "Shadow Facets \(report.shadowFacets.used) of \(report.shadowFacets.allowed)"
            + (report.wolfFacets.allowed > 0 ? " · Wolf \(report.wolfFacets.used) of \(report.wolfFacets.allowed)" : "")
            + " · Rites \(report.rites.used) of \(report.rites.allowed)"
        let traitProblems: Set<CreationProblem> = Set(problems.filter {
            switch $0 {
            case .tooManyRenownDots, .renownAboveTwo, .renownMissing, .pureRenownElsewhere, .harmonyNotSeven: true
            default: false
            }
        })
        let giftProblems: Set<CreationProblem> = Set(problems.filter {
            switch $0 {
            case .tooManyShadowFacets, .shadowFacetOutsideAffinities, .tooManyWolfFacets, .facetWithoutRenown,
                 .tooManyRiteDots: true
            default: false
            }
        })
        let meritProblems: Set<CreationProblem> = Set(problems.filter {
            switch $0 {
            case .tooManyMeritDots, .meritUnavailable, .meritPrerequisitesUnmet, .primalUrgeTooHigh: true
            default: false
            }
        })
        let giftsDone = report.shadowFacets.remaining == 0 && report.wolfFacets.remaining == 0
            && report.rites.remaining <= 0

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
            CreationStep(number: 5, title: isPure ? "Pure Traits" : "Forsaken Traits", detail: traitsDetail,
                         status: status(done: missing.isEmpty && report.renown.remaining == 0, problemsIn: traitProblems)),
            CreationStep(number: 6, title: "Gifts and Rites", detail: giftsDetail,
                         status: status(done: giftsDone, problemsIn: giftProblems)),
            CreationStep(number: 7, title: "Merits",
                         detail: "\(report.merits.used) of \(report.merits.allowed), counting extra Rites and Primal Urge \(primalUrge)",
                         status: status(done: report.merits.remaining == 0, problemsIn: meritProblems)),
        ]
    }

    /// The steps not yet done, for the reminder before finishing.
    var unfinishedCreationSteps: [CreationStep] {
        creationSteps.filter { $0.status != .done }
    }

    /// Ends guided creation, adding any bonus Experiences the Storyteller allows, and turns XP Mode on.
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
