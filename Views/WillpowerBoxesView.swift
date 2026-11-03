//
//  WillpowerBoxesView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 17/09/2024.
//


import SwiftUI

struct WillpowerBoxesView: View {
    let character: Character
    var boxesPerRow: Int = 10

    var body: some View {
        let boxes = character.willpowerBoxes
        let rows = Array(boxes.indices).chunked(into: boxesPerRow)
        VStack(spacing: 4) {
            ForEach(0..<rows.count, id: \.self) { rowIndex in
                HStack(spacing: 4) {
                    ForEach(rows[rowIndex], id: \.self) { index in
                        Button {
                            character.setWillpowerBox(at: index, to: boxes[index] == .none ? .spent : .none)
                        } label: {
                            WillpowerBoxView(state: boxes[index])
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Willpower box \(index + 1)")
                        .accessibilityValue(boxes[index] == .spent ? "Spent" : "Available")
                        .accessibilityHint("Double-tap to toggle")
                    }
                }
            }
        }
    }
}
