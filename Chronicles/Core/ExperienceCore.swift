//
//  ExperienceCore.swift
//  ChroniclesCore
//
//  Experiences for any game: spent and available, logging every change to a trait, and charging for new dots in XP
//  Mode. Each game says which traits cost Experiences, what a dot costs and which refund when lowered.
//

import Foundation

/// A character whose traits cost Experiences.
package protocol ExperienceCharacter: ConditionsCharacter {
    /// The Experiences paid for each dot of each trait, so lowering a trait refunds what was paid.
    var paidDots: [TraitKey: [Int: Int]] { get set }
    /// The game's Merits, for naming them in the log.
    var meritCatalog: CatalogIndex<MeritEntry> { get }
    /// The rating of every trait that costs Experiences, e.g. from `addSharedTraits(to:)` and the game's own.
    var traitSnapshot: TraitSnapshot { get }
    /// What one dot of the trait costs, given the character as they are now.
    func experienceCost(of key: TraitKey, level: Int) -> Int
    /// Whether lowering a paid trait with XP Mode on refunds its Experiences, as for a mistake. Traits lost in play,
    /// such as Requiem's Humanity, don't.
    func refundsWhenLowered(_ kind: TraitKind) -> Bool
    /// Every kind of trait in sheet order, e.g. Attributes, Skills, Specialties…, which the log follows when several
    /// change at once.
    var traitKindOrder: [TraitKind] { get }
    /// A kind of trait's name, e.g. "Merit", for naming an unnamed one in the log.
    func displayName(of kind: TraitKind) -> String
}

extension ExperienceCharacter {
    // MARK: - Totals

    /// Experiences spent, less refunds, over the whole change log.
    package var experiencesSpent: Int {
        changeLog.reduce(0) { $0 + $1.experiences }
    }

    /// Experiences earned less those spent. Can go below zero, as some Storytellers allow.
    package var experiencesAvailable: Int {
        experiences - experiencesSpent
    }

    package func incrementExperiences() {
        experiences += 1
    }

    package func decrementExperiences() {
        if experiences > 0 {
            experiences -= 1
        }
    }

    // MARK: - Snapshot and costs

    /// Attributes, Skills with their Specialties, and Merits, which every game has.
    package func addSharedTraits(to snapshot: inout TraitSnapshot) {
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
        for merit in merits {
            add(TraitKey(.merit, merit.id.uuidString), merit.rating, merit.name(in: meritCatalog))
        }
    }

    /// The cost of a dot of a trait every game has, or `nil` for the game's own kinds. Conditions cost 0.
    package func sharedExperienceCost(of kind: TraitKind) -> Int? {
        switch kind {
        case .attribute: 4
        case .skill: 2
        case .specialty, .merit: 1
        case .condition: 0
        default: nil
        }
    }

    // MARK: - Recording

    /// Logs every trait whose rating differs from `old`. With XP Mode on, each new dot is charged and
    /// remembered as paid, and lowering a trait refunds the paid dots removed, where the game allows.
    package func recordChanges(since old: TraitSnapshot, at date: Date = Date()) {
        let new = traitSnapshot
        let order = traitKindOrder
        let keys = Set(old.levels.keys).union(new.levels.keys).sorted { lhs, rhs in
            let left = order.firstIndex(of: lhs.kind) ?? order.count
            let right = order.firstIndex(of: rhs.kind) ?? order.count
            return left != right ? left < right : lhs.id < rhs.id
        }
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
                if let cost = paid.removeValue(forKey: level), xpMode, refundsWhenLowered(key.kind) {
                    experiences -= cost
                }
            }
        }
        paidDots[key] = paid.isEmpty ? nil : paid
        changeLog.append(TraitChange(id: UUID(), date: date, trait: key, name: name, from: from, to: to,
                                     experiences: experiences, xpMode: xpMode, duringCreation: isInCreation ? true : nil))
    }

    // MARK: - Log wording

    /// The name to show for a log entry: the trait's current name if it's still on the sheet (a custom
    /// trait may have been named after it was added), otherwise its name when it changed.
    package func displayName(for change: TraitChange) -> String {
        // A Condition is named as it is now, or as it was when it ended, e.g. with the note typed after adding it
        let current = condition(for: change).map(logName)
            ?? (change.trait.kind == .condition ? changeLog.last { $0.trait == change.trait }?.name : nil)
            ?? traitSnapshot.names[change.trait] ?? ""
        let name = current.isEmpty ? change.name : current
        return name.isEmpty ? "Unnamed \(displayName(of: change.trait.kind))" : name
    }
}

extension TraitChange {
    /// What it cost, e.g. "Spent 8", "Refunded 4", "Creation", "Free" (XP Mode off) or "No cost".
    package var costText: String {
        if trait.kind == .condition {
            return beats.map { $0 == 1 ? "+1 Beat" : "+\($0) Beats" } ?? ""
        }
        if duringCreation == true { return "Creation" }
        if experiences > 0 { return "Spent \(experiences)" }
        if experiences < 0 { return "Refunded \(-experiences)" }
        return xpMode ? "No cost" : "Free"
    }

    /// What changed for a rated trait or Condition, e.g. "1 → 3" or "Resolved".
    package var sharedChangeText: String {
        if let event {
            switch event {
            case .added: return "Added"
            case .ended: return "Ended"
            case .resolved: return "Resolved"
            case .beat: return "Beat"
            }
        }
        return "\(from) → \(to)"
    }
}
