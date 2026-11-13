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

package enum WillpowerBoxFillType: String, Codable {
    case none
    case spent
}
