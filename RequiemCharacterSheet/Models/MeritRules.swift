//
//  MeritRules.swift
//  RequiemCharacterSheet
//

import Foundation
#if SWIFT_PACKAGE
import ChroniclesCore
#endif

extension PrerequisiteCheck {
    static let notForKindred = "Not available to Kindred"
}

extension Character {
    /// Every requirement of the Merit: each prerequisite, then one line per "one of" choice.
    func prerequisiteChecks(for entry: MeritEntry) -> [PrerequisiteCheck] {
        let kindred = entry.unavailableToKindred
            ? [PrerequisiteCheck(description: PrerequisiteCheck.notForKindred, isMet: false, isUnavailability: true)] : []
        return kindred + prerequisiteChecks(entry.prerequisites, anyOf: entry.prerequisitesAnyOf, merit: entry)
    }

    /// Every Discipline a Devotion needs, then one line per "one of" choice.
    func prerequisiteChecks(for entry: DevotionEntry) -> [PrerequisiteCheck] {
        prerequisiteChecks(entry.prerequisites, anyOf: entry.prerequisitesAnyOf)
    }

    /// The requirements the character is known not to meet. Devotions can still be taken; these are warnings.
    func unmetPrerequisites(for entry: DevotionEntry) -> [PrerequisiteCheck] {
        prerequisiteChecks(for: entry).filter { $0.isMet == false }
    }

    private func prerequisiteChecks(_ prerequisites: [Prerequisite], anyOf: [[Prerequisite]], merit: MeritEntry? = nil) -> [PrerequisiteCheck] {
        prerequisiteChecks(prerequisites, anyOf: anyOf) { self.check($0, merit: merit) }
    }

    /// The requirements the character is known not to meet. Merits can still be taken; these are warnings.
    func unmetPrerequisites(for entry: MeritEntry) -> [PrerequisiteCheck] {
        prerequisiteChecks(for: entry).filter { $0.isMet == false }
    }

    /// `merit` is the Merit being checked, which some covenants and clans may take in another's place, e.g. the
    /// Carthian Laws with Gallows Post Status.
    private func check(_ prerequisite: Prerequisite, merit: MeritEntry? = nil) -> PrerequisiteCheck {
        let id = prerequisite.id ?? ""
        let minimum = prerequisite.minimum ?? 1
        let catalog = Catalog.bundled
        // Attributes, Skills, Merits and Willpower are checked the same way in every game
        if let common = commonCheck(prerequisite, merits: catalog.merits) {
            return common
        }

        switch prerequisite.kind {
        case .discipline:
            let name = catalog.disciplines.entry(id)?.name ?? id
            return PrerequisiteCheck(description: "\(name) \(minimum)", isMet: disciplineRating(id) >= minimum)
        case .bloodPotency:
            return PrerequisiteCheck(description: "Blood Potency \(minimum)", isMet: bloodPotency >= minimum)
        case .clan:
            // The character's clan, or bloodline, may take this Merit as though it were the one named
            let access = (clanEntry?.meritAccess ?? []) + (bloodlineEntry?.meritAccess ?? [])
            if let merit, access.contains(where: { $0.inPlaceOf == id && $0.merits.contains(merit.id) }) {
                let name = bloodlineEntry?.meritAccess.isEmpty == false ? bloodlineEntry?.name : clanEntry?.name
                return PrerequisiteCheck(description: "Clan: \(name ?? id)", isMet: true)
            }
            let name = catalog.clans.entry(id)?.name ?? id
            return PrerequisiteCheck(description: "Clan: \(name)", isMet: clanSource == .catalog(id))
        case .covenant:
            // The character's covenant may take this family of Merits with its own Status instead
            if let merit, let own = covenantSource.catalogID.flatMap({ catalog.covenants.entry($0) }),
               own.meritGroups.contains(where: { $0.inPlaceOf == id && $0.covers(merit) }) {
                return PrerequisiteCheck(description: "\(own.name) Status \(minimum)", isMet: covenantStatus(own.id) >= minimum)
            }
            // Named for the character's own covenant when its Status counts as this one's
            let name = statusStandIn(for: id)?.name ?? catalog.covenants.entry(id)?.name ?? id
            guard prerequisite.minimum != nil else {
                return PrerequisiteCheck(description: "Covenant: \(name)", isMet: covenantSource == .catalog(id) || statusStandIn(for: id) != nil)
            }
            // Measured in Covenant Status with that covenant
            return PrerequisiteCheck(description: "\(name) Status \(minimum)", isMet: covenantStatus(id) >= minimum)
        case .bloodline:
            let name = catalog.bloodlines.entry(id)?.name ?? id
            return PrerequisiteCheck(description: "Bloodline: \(name)", isMet: bloodlineSource == .catalog(id))
        case .notCovenant:
            let name = catalog.covenants.entry(id)?.name ?? id
            return PrerequisiteCheck(description: "Not a member of the \(name)", isMet: covenantSource != .catalog(id))
        default:
            // Free text, or a kind this app doesn't check
            return unknown(prerequisite)
        }
    }

    private func unknown(_ prerequisite: Prerequisite) -> PrerequisiteCheck {
        unknownCheck(prerequisite)
    }
}

extension Effect {
    /// What the effect does at `rating` dots, in words, e.g. "Adds 2 to Initiative".
    func description(rating: Int, qualifier: String?) -> String {
        description(rating: rating, qualifier: qualifier, merits: Catalog.bundled.merits)
    }
}
