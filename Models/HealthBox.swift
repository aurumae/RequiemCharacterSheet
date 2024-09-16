//
//  HealthBox.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 18/09/2024.
//


import Foundation

class HealthBox: ObservableObject, Identifiable, Codable {
    var id: UUID
    @Published var damageType: HealthBoxFillType

    enum CodingKeys: CodingKey {
        case id, damageType
    }

    // Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(damageType, forKey: .damageType)
    }

    // Decoding
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        damageType = try container.decode(HealthBoxFillType.self, forKey: .damageType)
    }

    // Default initializer
    init(id: UUID = UUID(), damageType: HealthBoxFillType = .none) {
        self.id = id
        self.damageType = damageType
    }
}
