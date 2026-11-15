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
        guard event == nil else { return sharedChangeText }
        switch trait.kind {
        case .ritual, .scale:
            return to > from ? "Learned" : "Removed"
        case .devotion:
            if from == 0 { return "Learned" }
            if to == 0 { return "Removed" }
            return "Cost \(from) → \(to)"
        default:
            return sharedChangeText
        }
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
