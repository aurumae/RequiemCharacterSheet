//
//  WillpowerBoxView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 18/09/2024.
//


import SwiftUI

/// One willpower box, showing whether it's been spent.
struct WillpowerBoxView: View {
    @Environment(\.theme) private var theme
    let state: WillpowerBoxFillType

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .overlay(
                Text(state == .spent ? "/" : "")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.ink)
                    .bold()
            )
            .overlay(
                Rectangle().stroke(theme.ink, lineWidth: 1)
            )
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
    }
}
