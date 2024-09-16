//
//  BoxFillType.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 18/09/2024.
//


import Foundation

/*
enum BoxFillType: String, Codable {
    case none
    case willpower
    case bashing
    case lethal
    case aggravated
}
 */

enum HealthBoxFillType: String, Codable {
    case none
    case bashing
    case lethal
    case aggravated
}

enum WillpowerBoxFillType: String, Codable {
    case none
    case spent
}
