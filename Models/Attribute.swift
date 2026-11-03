//
//  Attribute.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//

import Foundation
import Observation

@Observable
final class Attribute: Identifiable, Codable {
    let kind: AttributeKind
    var rating: Int

    var id: AttributeKind { kind }
    var name: String { kind.name }

    enum CodingKeys: CodingKey {
        case attribute, rating
        // Saves before version 4 identified attributes by display name
        case name
    }

    // Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .attribute)
        try container.encode(rating, forKey: .rating)
    }

    // Decoding
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let kind = try container.decodeIfPresent(AttributeKind.self, forKey: .attribute) {
            self.kind = kind
        } else {
            let name = try container.decode(String.self, forKey: .name)
            guard let kind = AttributeKind(name: name) else {
                throw DecodingError.dataCorruptedError(forKey: .name, in: container, debugDescription: "Unknown attribute \(name)")
            }
            self.kind = kind
        }
        rating = try container.decode(.rating, default: 1)
    }

    init(_ kind: AttributeKind, rating: Int = 1) {
        self.kind = kind
        self.rating = rating
    }
}
