//
//  HealthBoxesView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 17/09/2024.
//


import SwiftUI

struct HealthBoxesView: View {
    let character: Character
    var boxesPerRow: Int = 10

    var body: some View {
        let boxes = character.healthBoxes
        let rows = Array(boxes.indices).chunked(into: boxesPerRow)
        VStack(spacing: 4) {
            ForEach(0..<rows.count, id: \.self) { rowIndex in
                HStack(spacing: 4) {
                    ForEach(rows[rowIndex], id: \.self) { index in
                        HealthBoxView(damageType: boxes[index], isPenalty: false)
                            .onTapGesture {
                                character.setHealthBox(at: index, to: nextDamageType(current: boxes[index]))
                            }
                    }
                }
            }
        }
    }

    func nextDamageType(current: HealthBoxFillType) -> HealthBoxFillType {
        switch current {
        case .none:
            return .bashing
        case .bashing:
            return .lethal
        case .lethal:
            return .aggravated
        case .aggravated:
            return .none
        }
    }
}
