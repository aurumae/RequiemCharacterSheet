//
//  VitaeBox.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import Foundation

class VitaeBox: ObservableObject, Identifiable, Codable {
    var id: UUID
    @Published var isFilled: Bool

    enum CodingKeys: CodingKey {
        case id, isFilled
    }

    // Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(isFilled, forKey: .isFilled)
    }

    // Decoding
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        isFilled = try container.decode(Bool.self, forKey: .isFilled)
    }

    // Default initializer
    init(id: UUID = UUID(), isFilled: Bool = false) {
        self.id = id
        self.isFilled = isFilled
    }
}