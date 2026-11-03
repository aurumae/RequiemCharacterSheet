//
//  Skill.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import Foundation
import Observation

@Observable
final class Skill: Identifiable, Codable {
    let id: UUID
    let name: String
    var rating: Int
    var specialty: String

    enum CodingKeys: CodingKey {
        case id, name, rating, specialty
    }

    // Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(rating, forKey: .rating)
        try container.encode(specialty, forKey: .specialty)
    }

    // Decoding
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: UUID())
        name = try container.decode(String.self, forKey: .name)
        rating = try container.decode(.rating, default: 0)
        specialty = try container.decode(.specialty, default: "")
    }

    init(name: String, rating: Int = 0, specialty: String = "") {
        self.id = UUID()
        self.name = name
        self.rating = rating
        self.specialty = specialty
    }
}