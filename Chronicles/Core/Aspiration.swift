//
//  Aspiration.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import Foundation
import Observation

@Observable
package final class Aspiration: Identifiable, Codable {
    package var id: UUID
    package var text: String

    package enum CodingKeys: CodingKey {
        case id, text
    }

    package init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }

    // Encoding
    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
    }

    // Decoding
    package required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: UUID())
        text = try container.decode(.text, default: "")
    }
}