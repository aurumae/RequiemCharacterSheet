//
//  BoxView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 17/09/2024.
//


import SwiftUI

/// One health box, showing the damage marked in it.
struct HealthBoxView: View {
    /// Grows with the text size, so the mark inside stays readable.
    @ScaledMetric(relativeTo: .body) private var boxSize: CGFloat = 20
    @Environment(\.theme) private var theme
    let damageType: HealthBoxFillType
    var isPenalty: Bool = false

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .overlay(
                Text(symbol(for: damageType))
                    .font(.system(size: boxSize * 0.7))
                    .foregroundStyle(theme.ink)
                    .bold()
            )
            .overlay(
                Rectangle().stroke(isPenalty ? theme.accent : theme.ink, lineWidth: isPenalty ? 3 : 1)
            )
            .frame(width: boxSize, height: boxSize)
            .contentShape(Rectangle())
    }

    private func symbol(for type: HealthBoxFillType) -> String {
        switch type {
        case .bashing:
            return "/"
        case .lethal:
            return "X"
        case .aggravated:
            return "✱"
        case .none:
            return ""
        }
    }
}

extension HealthBoxFillType {
    /// How VoiceOver describes a health box.
    var accessibilityDescription: String {
        switch self {
        case .none:
            return "Empty"
        case .bashing:
            return "Bashing damage"
        case .lethal:
            return "Lethal damage"
        case .aggravated:
            return "Aggravated damage"
        }
    }
}
