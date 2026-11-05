//
//  WillpowerBoxView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 18/09/2024.
//


import SwiftUI

/// One willpower box, showing whether it's been spent.
struct WillpowerBoxView: View {
    /// Grows with the text size, so the mark inside stays readable.
    @ScaledMetric(relativeTo: .body) private var boxSize: CGFloat = 20
    @Environment(\.theme) private var theme
    let state: WillpowerBoxFillType

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .overlay(
                Text(state == .spent ? "/" : "")
                    .font(.system(size: boxSize * 0.7))
                    .foregroundStyle(theme.ink)
                    .bold()
            )
            .overlay(
                Rectangle().stroke(theme.ink, lineWidth: 1)
            )
            .frame(width: boxSize, height: boxSize)
            .contentShape(Rectangle())
    }
}
