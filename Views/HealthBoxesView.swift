//
//  HealthBoxesView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 17/09/2024.
//


import SwiftUI

struct HealthBoxesView: View {
    @ObservedObject var character: Character
    var boxesPerRow: Int = 10

    var body: some View {
        let rows = character.healthBoxes.chunked(into: boxesPerRow)
        VStack(spacing: 4) {
            ForEach(0..<rows.count, id: \.self) { rowIndex in
                HStack(spacing: 4) {
                    ForEach(rows[rowIndex]) { box in
                        HealthBoxView(box: box, isPenalty: false)
                            .onTapGesture {
                                box.damageType = nextDamageType(current: box.damageType)
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
