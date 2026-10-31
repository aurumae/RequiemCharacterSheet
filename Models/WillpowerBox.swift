//
//  WillpowerBox.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 18/09/2024.
//


import Foundation

class WillpowerBox: ObservableObject, Identifiable, Codable {
    var id: UUID
    @Published var state: WillpowerBoxFillType
    
    enum CodingKeys: CodingKey {
        case id, state
    }
    
    // Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(state, forKey: .state)
    }
    
    // Decoding
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: UUID())
        state = try container.decode(.state, default: WillpowerBoxFillType.none)
    }
    
    // Default initializer
    init(id: UUID = UUID(), state: WillpowerBoxFillType = .none) {
        self.id = id
        self.state = state
    }
}
