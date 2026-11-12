//
//  SorceryRules.swift
//  RequiemCharacterSheet
//

import Foundation

/// The limit a Ritual Discipline puts on Humanity, e.g. Crúac 3 caps it at 7.
struct HumanityCap: Equatable {
    let limit: Int
    let disciplineName: String
    let dots: Int
}

extension Character {
    // MARK: - Shared

    /// Dots in a catalog Discipline, or 0 if it isn't on the sheet.
    func disciplineRating(_ id: CatalogEntryID) -> Int {
        disciplines.filter { $0.source == .catalog(id) }.map(\.rating).max() ?? 0
    }

    /// Dots of the Covenant Status Merit taken for this covenant.
    func covenantStatus(_ covenantID: CatalogEntryID) -> Int {
        let name = Catalog.bundled.covenants.entry(covenantID)?.name ?? covenantID
        let own = merits
            .filter { $0.source == .catalog("covenant-status") && $0.qualifier?.caseInsensitiveCompare(name) == .orderedSame }
            .map(\.rating).max() ?? 0
        // Status in the character's covenant may count as this one's, e.g. the Circles of Mor's as the Crone's
        if let standIn = statusStandIn(for: covenantID) {
            return max(own, covenantStatus(standIn.id))
        }
        return own
    }

    /// The character's covenant, if its Status counts as Status in `covenantID`.
    func statusStandIn(for covenantID: CatalogEntryID) -> CovenantEntry? {
        guard let own = covenantSource.catalogID.flatMap({ Catalog.bundled.covenants.entry($0) }),
              own.id != covenantID, own.statusCountsAs == covenantID else { return nil }
        return own
    }

    // MARK: - Blood sorcery (Vampire: The Requiem pp. 150–152)

    /// The Ritual Disciplines on the sheet, e.g. Crúac, in sheet order.
    var ritualDisciplines: [DisciplineEntry] {
        var seen = Set<CatalogEntryID>()
        return disciplines.compactMap(\.entry).filter { $0.kind == .ritual && seen.insert($0.id).inserted }
    }

    /// Whether the sheet shows a Rituals section.
    var showsRituals: Bool {
        !ritualDisciplines.isEmpty || !rituals.isEmpty
    }

    /// The rituals cast with this Discipline, lowest dots first.
    func rituals(of discipline: TraitSource) -> [Ritual] {
        rituals.filter { $0.discipline == discipline }.sorted { $0.dots < $1.dots }
    }

    /// Each dot of a Ritual Discipline, including the first, comes with one ritual (p. 151).
    func freeRitualCount(for disciplineID: CatalogEntryID) -> Int {
        disciplineRating(disciplineID)
    }

    /// Why the character can't learn new rituals for this Discipline, if they can't: they need Status in its covenant.
    func ritualLearningWarning(for entry: DisciplineEntry) -> String? {
        guard let rules = entry.ritualRules, !hasRitualStatus(for: entry) else { return nil }
        return "Learning rituals requires \(Self.ritualRequirementText(for: entry))"
    }

    /// Whether the character has the Status to learn rituals for this Discipline, in its covenant or in another that
    /// teaches it, e.g. the Ahl al-Mumit for Theban Sorcery.
    func hasRitualStatus(for entry: DisciplineEntry) -> Bool {
        guard let rules = entry.ritualRules else { return true }
        let covenants = [rules.covenant] + Self.otherCovenants(teaching: entry).map(\.id)
        // No Status needed, only membership, e.g. Belial's Brood's Triadic Evolution
        if rules.covenantStatusMinimum == 0 {
            return covenants.contains { covenantSource == .catalog($0) || statusStandIn(for: $0) != nil }
        }
        return covenants.contains { covenantStatus($0) >= rules.covenantStatusMinimum }
    }

    /// Covenants other than its own that teach a Ritual Discipline.
    static func otherCovenants(teaching entry: DisciplineEntry) -> [CovenantEntry] {
        Catalog.bundled.covenants.all.filter { $0.teaches.contains(entry.id) }
    }

    /// What learning a Ritual Discipline's rituals needs, e.g. "Lancea et Sanctum or Ahl al-Mumit Status 1", or
    /// "membership of Belial's Brood".
    static func ritualRequirementText(for entry: DisciplineEntry) -> String {
        guard let rules = entry.ritualRules else { return "" }
        if rules.covenantStatusMinimum == 0 { return "membership of \(ritualCovenantsText(for: entry))" }
        return "\(ritualCovenantsText(for: entry)) Status \(rules.covenantStatusMinimum)"
    }

    /// The covenants that teach a Ritual Discipline, e.g. "Lancea et Sanctum or Ahl al-Mumit".
    static func ritualCovenantsText(for entry: DisciplineEntry) -> String {
        guard let rules = entry.ritualRules else { return "" }
        let own = Catalog.bundled.covenants.entry(rules.covenant)?.name ?? rules.covenant
        return ([own] + otherCovenants(teaching: entry).map(\.name)).joined(separator: " or ")
    }

    /// Rules the ritual breaks for this character: rated above their Discipline dots, or a Theban miracle above their Humanity.
    func warnings(for ritual: Ritual) -> [String] {
        guard let id = ritual.discipline.catalogID, let discipline = Catalog.bundled.disciplines.entry(id) else { return [] }
        var warnings: [String] = []
        if disciplineRating(id) < ritual.dots {
            warnings.append("Requires \(discipline.name) \(ritual.dots)")
        }
        if discipline.ritualRules?.humanity == .atLeastRitualDots, humanity < ritual.dots {
            warnings.append("Casting requires Humanity \(ritual.dots)")
        }
        return warnings
    }

    /// The lowest Humanity limit set by the character's Ritual Disciplines: Crúac caps it at 10 minus its dots.
    var humanityCap: HumanityCap? {
        disciplines.compactMap { discipline -> HumanityCap? in
            guard let entry = discipline.entry, entry.ritualRules?.humanity == .capAtTenMinusDots, discipline.rating > 0 else {
                return nil
            }
            return HumanityCap(limit: 10 - discipline.rating, disciplineName: entry.name, dots: discipline.rating)
        }
        .min { $0.limit < $1.limit }
    }

    // MARK: - Coils and Scales (pp. 154–155)

    /// Whether the sheet shows the Coils of the Dragon section.
    var showsCoils: Bool {
        covenantSource == .catalog("ordo-dracul") || mysterySource != .custom("") || !coils.isEmpty || !scales.isEmpty
    }

    /// Follows a Mystery chosen from the list, adding its Coil to the sheet if it isn't there yet.
    /// Dots in a previous Mystery's Coil are kept.
    func chooseMystery(_ source: TraitSource) {
        mysterySource = source
        if source != .custom(""), !coils.contains(where: { $0.mystery == source }) {
            coils.insert(Coil(mystery: source), at: 0)
        }
    }

    /// Renames a custom Mystery as it's typed, keeping its Coil with it.
    func renameMystery(to name: String) {
        let old = mysterySource
        let new = Catalog.bundled.mysteries.source(named: name)
        mysterySource = new
        if let coil = coils.first(where: { $0.mystery == old }), old != .custom(""), !coils.contains(where: { $0.mystery == new }) {
            coil.mystery = new
        } else if new != .custom(""), !coils.contains(where: { $0.mystery == new }) {
            coils.insert(Coil(mystery: new), at: 0)
        }
    }

    func isMysteryCoil(_ coil: Coil) -> Bool {
        guard mysterySource != .custom("") else { return false }
        if coil.mystery == mysterySource { return true }
        // A Coil that counts as part of the character's Mystery
        let partOf = coil.mystery.catalogID.flatMap { Catalog.bundled.mysteries.entry($0) }?.partOfMystery
        return partOf != nil && partOf == mysterySource.catalogID
    }

    var ordoDraculStatus: Int {
        covenantStatus("ordo-dracul")
    }

    /// Coils outside the character's Mystery can't have more dots than their Ordo Dracul Status.
    func warning(for coil: Coil) -> String? {
        guard !isMysteryCoil(coil), coil.rating > ordoDraculStatus else { return nil }
        // A non-breaking space keeps "Ordo Dracul" together when the warning wraps
        return "Outside your Mystery, limited to Ordo\u{00A0}Dracul Status (\(ordoDraculStatus))"
    }

    /// Dots in a Mystery's Coil.
    func coilRating(_ mysteryID: CatalogEntryID) -> Int {
        coils.filter { $0.mystery == .catalog(mysteryID) }.map(\.rating).max() ?? 0
    }

    /// Whether the character has one of the Coil tiers the Scale resonates with.
    func meetsPrerequisite(of scale: ScaleEntry) -> Bool {
        if let anyCoil = scale.anyCoil, coils.contains(where: { $0.rating >= anyCoil }) { return true }
        return scale.prerequisiteCoils.contains { coilRating($0.mystery) >= $0.dots }
    }

    /// A Scale costs 1 Experience with its prerequisite Coil, 2 without.
    func experienceCost(of scale: ScaleEntry) -> Int {
        meetsPrerequisite(of: scale) ? 1 : 2
    }
}

extension ScaleEntry {
    /// e.g. "Beast's Hunger (Mystery of the Wyrm ••)".
    var prerequisiteText: String {
        let any = anyCoil.map { ["Any Coil \(String(repeating: "•", count: $0))"] } ?? []
        return (any + prerequisiteCoils.map { prerequisite in
            let mystery = Catalog.bundled.mysteries.entry(prerequisite.mystery)
            let tier = mystery?.tier(prerequisite.dots)?.name ?? prerequisite.tier
            return "\(tier) (\(mystery?.name ?? prerequisite.mystery) \(String(repeating: "•", count: prerequisite.dots)))"
        })
        .joined(separator: " or ")
    }
}

extension RitualRules.HumanityRule {
    /// The rule in words.
    var description: String {
        switch self {
        case .capAtTenMinusDots:
            return "Humanity can't rise above 10 minus its dots. Learning a dot is a breaking point at Humanity 4 or higher."
        case .atLeastRitualDots:
            return "Casting a miracle requires Humanity at least equal to its dots."
        case .none:
            return "No limit on Humanity."
        case .breakingPointAtSixMinusDots:
            return "Each ritual is a breaking point at Humanity 6 minus its dots or higher: 5+ for one dot, down to 1+ for five."
        }
    }
}
