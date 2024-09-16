//
//  Touchstone.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import Foundation

class Touchstone: ObservableObject, Identifiable, Codable {
    let id: UUID
    let level: Int
    @Published var text: String

    enum CodingKeys: CodingKey {
        case id, level, text
    }

    init(level: Int, text: String = "") {
        self.id = UUID()
        self.level = level
        self.text = text
    }

    // Codable Conformance
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(level, forKey: .level)
        try container.encode(text, forKey: .text)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        level = try container.decode(Int.self, forKey: .level)
        text = try container.decode(String.self, forKey: .text)
    }
}