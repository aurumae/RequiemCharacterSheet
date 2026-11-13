//
//  ExperienceRules.swift
//  RequiemCharacterSheet
//

import Foundation
#if SWIFT_PACKAGE
import ChroniclesCore
#endif

extension Character {
    // MARK: - Totals

    /// Experiences spent, less refunds, over the whole change log.
    var experiencesSpent: Int {
        changeLog.reduce(0) { $0 + $1.experiences }
    }

    /// Experiences earned less those spent. Can go below zero, as some Storytellers allow.
    var experiencesAvailable: Int {
        experiences - experiencesSpent
    }

    // MARK: - Snapshot

    /// The rating of every trait that costs Experiences. Rituals, Devotions and Scales count 1 for
    /// being on the sheet, except a custom Devotion, which counts its Experience cost so changing it is paid for.
    var traitSnapshot: TraitSnapshot {
        var snapshot = TraitSnapshot()
        func add(_ key: TraitKey, _ level: Int, _ name: String) {
            snapshot.levels[key] = level
            snapshot.names[key] = name
        }

        for attribute in attributes {
            add(TraitKey(.attribute, attribute.kind.rawValue), attribute.rating, attribute.name)
        }
        for skill in skills {
            add(TraitKey(.skill, skill.skillID.rawValue), skill.rating, skill.name)
            let specialties = skill.specialties.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
            add(TraitKey(.specialty, skill.skillID.rawValue), specialties, "\(skill.name) Specialties")
        }
        for discipline in disciplines {
            add(TraitKey(.discipline, discipline.id.uuidString), discipline.rating, discipline.name)
        }
        for merit in merits {
            add(TraitKey(.merit, merit.id.uuidString), merit.rating, merit.name)
        }
        for coil in coils {
            add(TraitKey(.coil, coil.id.uuidString), coil.rating, coil.entry?.coil.name ?? coil.name)
        }
        for ritual in rituals {
            add(TraitKey(.ritual, ritual.id.uuidString), 1, ritual.name)
        }
        for devotion in devotions {
            add(TraitKey(.devotion, devotion.id.uuidString), devotion.entry == nil ? max(devotion.customExperienceCost, 1) : 1, devotion.name)
        }
        for scale in scales {
            add(TraitKey(.scale, scale.id.uuidString), 1, scale.name)
        }
        add(TraitKey(.humanity, "humanity"), humanity, "Humanity")
        add(TraitKey(.bloodPotency, "bloodPotency"), bloodPotency, "Blood Potency")
        return snapshot
    }

    // MARK: - Recording

    /// Logs every trait whose rating differs from `old`. With XP Mode on, each new dot is charged and
    /// remembered as paid, and lowering a trait refunds the paid dots removed (except Humanity and Blood Potency).
    func recordChanges(since old: TraitSnapshot, at date: Date = Date()) {
        let new = traitSnapshot
        let keys = Set(old.levels.keys).union(new.levels.keys).sorted()
        for key in keys {
            let from = old.levels[key] ?? 0
            let to = new.levels[key] ?? 0
            guard from != to else { continue }
            let name = new.names[key] ?? old.names[key] ?? ""
            record(key, name: name, from: from, to: to, at: date)
        }
    }

    private func record(_ key: TraitKey, name: String, from: Int, to: Int, at date: Date) {
        var paid = paidDots[key] ?? [:]
        var experiences = 0
        if to > from {
            for level in (from + 1)...to where xpMode {
                let cost = experienceCost(of: key, level: level)
                paid[level] = cost
                experiences += cost
            }
        } else {
            for level in (to + 1)...from {
                // A dot that's gone is no longer paid for, refunded or not
                if let cost = paid.removeValue(forKey: level), xpMode, key.kind.isRefundable {
                    experiences -= cost
                }
            }
        }
        paidDots[key] = paid.isEmpty ? nil : paid
        changeLog.append(TraitChange(id: UUID(), date: date, trait: key, name: name, from: from, to: to,
                                     experiences: experiences, xpMode: xpMode, duringCreation: isInCreation ? true : nil))
    }

    // MARK: - Costs

    /// What one dot of the trait costs, by the book's Experience costs, given the character as they are now.
    func experienceCost(of key: TraitKey, level: Int) -> Int {
        switch key.kind {
        case .attribute:
            return 4
        case .skill:
            return 2
        case .specialty, .merit:
            return 1
        case .discipline:
            guard let discipline = disciplines.first(where: { $0.id.uuidString == key.id }) else { return 4 }
            // Crúac and Theban Sorcery are never in-clan
            if let entry = discipline.entry, entry.kind != .ritual, inClanDisciplines.contains(entry.id) {
                return 3
            }
            return 4
        case .coil:
            guard let coil = coils.first(where: { $0.id.uuidString == key.id }) else { return 4 }
            return isMysteryCoil(coil) ? 3 : 4
        case .ritual:
            guard let ritual = rituals.first(where: { $0.id.uuidString == key.id }) else { return 2 }
            // Each dot of the Discipline comes with one ritual; the rest cost 2 each
            let others = rituals(of: ritual.discipline).filter { $0.id != ritual.id }.count
            let free = ritual.discipline.catalogID.map(freeRitualCount) ?? 0
            return others < free ? 0 : 2
        case .devotion:
            guard let devotion = devotions.first(where: { $0.id.uuidString == key.id }) else { return 1 }
            // A custom Devotion's level is its cost, one Experience per level
            return devotion.entry?.experienceCost ?? 1
        case .scale:
            guard let entry = scales.first(where: { $0.id.uuidString == key.id })?.entry else { return 2 }
            return experienceCost(of: entry)
        case .humanity:
            return 2
        case .bloodPotency:
            return 5
        default:
            // Conditions are logged but never bought
            return 0
        }
    }
}
