//
//  ExperienceRules.swift
//  RequiemCharacterSheet
//

import Foundation
#if SWIFT_PACKAGE
import ChroniclesCore
#endif

extension Character: ExperienceCharacter {
    var meritCatalog: CatalogIndex<MeritEntry> {
        Catalog.bundled.merits
    }

    var traitKindOrder: [TraitKind] {
        TraitKind.requiemOrder
    }

    func refundsWhenLowered(_ kind: TraitKind) -> Bool {
        kind.isRefundable
    }

    func displayName(of kind: TraitKind) -> String {
        kind.displayName
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

        // Attributes, Skills, Specialties and Merits
        addSharedTraits(to: &snapshot)
        for discipline in disciplines {
            add(TraitKey(.discipline, discipline.id.uuidString), discipline.rating, discipline.name)
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

    // MARK: - Costs

    /// What one dot of the trait costs, by the book's Experience costs, given the character as they are now.
    func experienceCost(of key: TraitKey, level: Int) -> Int {
        if let shared = sharedExperienceCost(of: key.kind) {
            return shared
        }
        switch key.kind {
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
