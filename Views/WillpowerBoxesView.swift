//
//  WillpowerBoxesView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 17/09/2024.
//


import SwiftUI

struct WillpowerBoxesView: View {
    @ObservedObject var character: Character
    var boxesPerRow: Int = 10

    var body: some View {
        let rows = character.willpowerBoxes.chunked(into: boxesPerRow)
        VStack(spacing: 4) {
            ForEach(0..<rows.count, id: \.self) { rowIndex in
                HStack(spacing: 4) {
                    ForEach(rows[rowIndex]) { box in
                        WillpowerBoxView(box: box)
                    }
                }
            }
        }
    }
}
