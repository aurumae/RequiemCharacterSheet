//
//  BoxFillType.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 18/09/2024.
//


import Foundation

package enum HealthBoxFillType: String, Codable {
    case none
    case bashing
    case lethal
    case aggravated
}

extension [HealthBoxFillType] {
    /// The track cut to `boxes`. Temporary Health dots go away but their wounds don't: each one upgrades the least
    /// severe wound left, starting from the left (Werewolf: The Forsaken, p. 172). A wound finds an empty box first.
    package func folded(into boxes: Int) -> [HealthBoxFillType] {
        let boxes = Swift.max(boxes, 0)
        var track = (0..<boxes).map { indices.contains($0) ? self[$0] : .none }
        for wound in dropFirst(boxes) where wound != .none {
            if let empty = track.firstIndex(of: .none) {
                track[empty] = wound
            } else if let index = track.firstIndex(of: .bashing) {
                track[index] = .lethal
            } else if let index = track.firstIndex(of: .lethal) {
                track[index] = .aggravated
            }
        }
        return track
    }
}

package enum WillpowerBoxFillType: String, Codable {
    case none
    case spent
}
