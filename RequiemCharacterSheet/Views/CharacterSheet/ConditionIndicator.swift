//
//  ConditionIndicator.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// A small dot marked "c", after a trait an active Condition affects. Tapping it says which Condition and
/// how, and opens the Condition's card. The dot is small, but its tap area is a comfortable size, apart from
/// the trait's name.
struct ConditionIndicator: View {
    @Environment(\.theme) private var theme
    @Environment(\.presentSheet) private var presentSheet
    let character: Character
    let target: ConditionTarget
    /// The trait's name, for VoiceOver, e.g. "Stamina".
    let traitName: String

    @State private var showingEffects = false
    /// A card chosen in the popover, opened once the popover has closed.
    @State private var cardToOpen: CharacterCondition?

    var body: some View {
        let effects = character.conditionEffects(on: target)
        if !effects.isEmpty {
            Button {
                showingEffects = true
            } label: {
                ZStack {
                    Circle()
                        .fill(theme.accent)
                    Text("c")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .offset(y: -1)
                }
                .frame(width: 16, height: 16)
                // A 44-point target, the smallest Apple recommends, around the small dot
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            // Laid out at the dot's size, so the row isn't taller for having one; taps still use the 44 points
            .padding(.horizontal, -12)
            .padding(.vertical, -14)
            .accessibilityLabel("\(traitName): affected by \(effects.map(\.condition.name).joined(separator: ", "))")
            .accessibilityHint("Shows how")
            .popover(isPresented: $showingEffects) {
                ConditionEffectsPopover(traitName: traitName, effects: effects) { condition in
                    cardToOpen = condition
                    showingEffects = false
                }
                .presentationCompactAdaptation(.popover)
            }
            .onChange(of: showingEffects) { _, isShowing in
                guard !isShowing, let condition = cardToOpen else { return }
                cardToOpen = nil
                Task {
                    // Wait for the popover to finish closing; a sheet can't open while it's on screen
                    try? await Task.sleep(for: .milliseconds(350))
                    presentSheet?(HostedSheet(
                        content: AnyView(ConditionCardSheet(condition: condition, character: character)),
                        onDismiss: nil
                    ))
                }
            }
        }
    }
}

/// What each Condition does to the trait, each opening its card.
private struct ConditionEffectsPopover: View {
    @Environment(\.theme) private var theme
    let traitName: String
    let effects: [(condition: CharacterCondition, text: String)]
    let open: (CharacterCondition) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(traitName)
                .font(.headline)
            ForEach(Array(effects.enumerated()), id: \.offset) { _, effect in
                Button {
                    open(effect.condition)
                } label: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(effect.text)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(theme.muted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the \(effect.condition.name) card")
            }
        }
        .padding()
        .frame(width: 300, alignment: .leading)
    }
}
