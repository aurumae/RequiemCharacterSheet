//
//  Skill.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import Foundation
import Observation

/// A character's dots and specialties in one skill.
@Observable
final class Skill: Identifiable, Codable {
    let skillID: SkillID
    var rating: Int
    var specialties: [String]

    var id: SkillID { skillID }

    var definition: SkillDefinition? {
        SkillDefinition.withID(skillID)
    }

    var name: String {
        definition?.name ?? skillID.rawValue.capitalized
    }

    var category: TraitCategory {
        definition?.category ?? .mental
    }

    enum CodingKeys: CodingKey {
        case skill, rating, specialties
        // Saves before version 4 identified skills by display name, with a single specialty
        case name, specialty
    }

    // Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(skillID, forKey: .skill)
        try container.encode(rating, forKey: .rating)
        try container.encode(specialties, forKey: .specialties)
    }

    // Decoding
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let skillID = try container.decodeIfPresent(SkillID.self, forKey: .skill) {
            self.skillID = skillID
        } else {
            let name = try container.decode(String.self, forKey: .name)
            skillID = SkillDefinition.named(name)?.id
                ?? SkillID(name.lowercased().replacingOccurrences(of: " ", with: "-"))
        }
        rating = try container.decode(.rating, default: 0)
        if let specialties = try container.decodeIfPresent([String].self, forKey: .specialties) {
            self.specialties = specialties
        } else {
            let specialty: String = try container.decode(.specialty, default: "")
            self.specialties = specialty.isEmpty ? [] : [specialty]
        }
    }

    init(_ skillID: SkillID, rating: Int = 0, specialties: [String] = []) {
        self.skillID = skillID
        self.rating = rating
        self.specialties = specialties
    }
}
