//
//  Merit.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import Foundation

class Merit: ObservableObject, Identifiable, Codable {
    var id: UUID
    @Published var name: String
    @Published var rating: Int

    enum CodingKeys: CodingKey {
        case id, name, rating
    }

    init(id: UUID = UUID(), name: String = "", rating: Int = 0) {
        self.id = id
        self.name = name
        self.rating = rating
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
}