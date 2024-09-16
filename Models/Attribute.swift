//
//  Attribute.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//

import Foundation

class Attribute: ObservableObject, Identifiable, Codable {
    let id: UUID
    let name: String
    @Published var rating: Int

    enum CodingKeys: CodingKey {
        case id, name, rating
    }

    // Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(rating, forKey: .rating)
    }

    // Decoding
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        rating = try container.decode(Int.self, forKey: .rating)
    }

    init(name: String, rating: Int) {
        self.id = UUID()
        self.name = name
        self.rating = rating
    }
}
