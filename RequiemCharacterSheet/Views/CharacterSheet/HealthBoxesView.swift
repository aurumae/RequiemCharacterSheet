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
        VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<rows.count, id: \.self) { rowIndex in
                HStack(spacing: 4) {
                    ForEach(rows[rowIndex], id: \.self) { index in
                        Button {
                            character.setHealthBox(at: index, to: nextDamageType(current: boxes[index]))
                        } label: {
                            HealthBoxView(damageType: boxes[index], isPenalty: false)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Health box \(index + 1)")
                        .accessibilityValue(boxes[index].accessibilityDescription)
                        .accessibilityHint("Double-tap to change the damage")
                    }
                }
            }
        }
    }

    /// Tapping cycles a box through no damage, bashing, lethal and aggravated.
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
