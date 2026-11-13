//
//  DotView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//


import SwiftUI

/// A single rating dot. Interactive dots are buttons; others are drawn only.
struct DotView: View {
    @Environment(\.theme) private var theme
    var isFilled: Bool
    /// Defaults to the theme's accent colour.
    var fillColor: Color?
    /// Called when the dot is tapped. A dot with no action can't be tapped.
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) {
                circle
            }
            .buttonStyle(.borderless)
        } else {
            circle
        }
    }

    private var circle: some View {
        Circle()
            .fill(isFilled ? (fillColor ?? theme.accent) : Color.clear)
            .overlay(Circle().stroke(theme.ink, lineWidth: 1))
            .frame(width: 20, height: 20)
            .contentShape(Circle())
    }
}
