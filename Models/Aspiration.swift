//
//  Aspiration.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import Foundation

class Aspiration: ObservableObject, Identifiable, Codable {
    var id: UUID
    @Published var text: String

    enum CodingKeys: CodingKey {
        case id, text
    }

    init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }

    // Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
    }

    // Decoding
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
    }
}