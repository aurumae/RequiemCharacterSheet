//
//  Experience.swift
//  RequiemCharacterSheet
//

import Foundation
#if SWIFT_PACKAGE
import ChroniclesCore
#endif

/// Requiem's kinds of trait, alongside the shared Attributes, Skills, Specialties, Merits and Conditions.
extension TraitKind {
    static let discipline = TraitKind("discipline")
    static let coil = TraitKind("coil")
    static let ritual = TraitKind("ritual")
    static let devotion = TraitKind("devotion")
    static let scale = TraitKind("scale")
    static let humanity = TraitKind("humanity")
    static let bloodPotency = TraitKind("bloodPotency")

    /// Every kind, in sheet order: Attributes, Skills, Specialties, Disciplines…
    static let requiemOrder: [TraitKind] = [
        .attribute, .skill, .specialty, .discipline, .merit, .coil, .ritual, .devotion, .scale, .humanity,
        .bloodPotency, .condition,
    ]

    /// Lowering a paid trait with XP Mode on refunds its Experiences, as for a mistake. Humanity and
    /// Blood Potency fall in play (breaking points, torpor), so losing them never refunds.
    var isRefundable: Bool {
        self != .humanity && self != .bloodPotency
    }
}

extension TraitKey: Comparable {
    /// In sheet order: Attributes, Skills, Specialties, Disciplines…
    package static func < (lhs: TraitKey, rhs: TraitKey) -> Bool {
        let order = TraitKind.requiemOrder
        let left = order.firstIndex(of: lhs.kind) ?? order.count
        let right = order.firstIndex(of: rhs.kind) ?? order.count
        return left != right ? left < right : lhs.id < rhs.id
    }
}

extension TraitChange {
    /// What changed, e.g. "1 → 3", "Learned", or "Cost 1 → 3" for a custom Devotion.
    var changeText: String {
        if let event {
            switch event {
            case .added: return "Added"
            case .ended: return "Ended"
            case .resolved: return "Resolved"
            case .beat: return "Beat"
            }
        }
        switch trait.kind {
        case .ritual, .scale:
            return to > from ? "Learned" : "Removed"
        case .devotion:
            if from == 0 { return "Learned" }
            if to == 0 { return "Removed" }
            return "Cost \(from) → \(to)"
        default:
            return "\(from) → \(to)"
        }
    }

    /// What it cost, e.g. "Spent 8", "Refunded 4", "Creation", "Free" (XP Mode off) or "No cost".
    var costText: String {
        if trait.kind == .condition {
            return beats.map { $0 == 1 ? "+1 Beat" : "+\($0) Beats" } ?? ""
        }
        if duringCreation == true { return "Creation" }
        if experiences > 0 { return "Spent \(experiences)" }
        if experiences < 0 { return "Refunded \(-experiences)" }
        return xpMode ? "No cost" : "Free"
    }
}

extension Character {
    /// The name to show for a log entry: the trait's current name if it's still on the sheet (a custom
    /// trait may have been named after it was added), otherwise its name when it changed.
    func displayName(for change: TraitChange) -> String {
        // A Condition is named as it is now, or as it was when it ended, e.g. with the note typed after adding it
        let current = condition(for: change).map(logName)
            ?? (change.trait.kind == .condition ? changeLog.last { $0.trait == change.trait }?.name : nil)
            ?? traitSnapshot.names[change.trait] ?? ""
        let name = current.isEmpty ? change.name : current
        return name.isEmpty ? "Unnamed \(change.trait.kind.displayName)" : name
    }
}

extension TraitKind {
    var displayName: String {
        switch self {
        case .attribute: return "Attribute"
        case .skill: return "Skill"
        case .specialty: return "Specialty"
        case .discipline: return "Discipline"
        case .merit: return "Merit"
        case .coil: return "Coil"
        case .ritual: return "Ritual"
        case .devotion: return "Devotion"
        case .scale: return "Scale"
        case .humanity: return "Humanity"
        case .bloodPotency: return "Blood Potency"
        case .condition: return "Condition"
        default: return rawValue
        }
    }
}
