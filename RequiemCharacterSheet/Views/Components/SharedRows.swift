//
//  SharedRows.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// A label with a read-only value on the right, e.g. "Speed: 8".
struct LabeledValueRow: View {
    let label: String
    let value: String

    init(_ label: String, value: Int) {
        self.label = label
        self.value = "\(value)"
    }

    var body: some View {
        HStack {
            Text(label)
                .themedText(.label)
            Spacer()
            Text(value)
                .themedText(.label)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// Minus and plus buttons. Used on their own, or as part of `CounterRow`.
struct StepperButtons: View {
    @Environment(\.theme) private var theme
    let canDecrement: Bool
    let canIncrement: Bool
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: decrement) {
                Image(systemName: "minus.circle")
                    .font(.title2)
            }
            .disabled(!canDecrement)
            .opacity(canDecrement ? 1 : 0.35)
            .accessibilityLabel("Decrease")

            Button(action: increment) {
                Image(systemName: "plus.circle")
                    .font(.title2)
            }
            .disabled(!canIncrement)
            .opacity(canIncrement ? 1 : 0.35)
            .accessibilityLabel("Increase")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(theme.accent)
    }
}

/// A label with a value that can be stepped up and down, e.g. "Armor: − 2 +".
/// VoiceOver reads it as one adjustable element (swipe up or down to change).
struct CounterRow: View {
    @Environment(\.theme) private var theme
    let label: String
    let value: Int
    let canDecrement: Bool
    let canIncrement: Bool
    let decrement: () -> Void
    let increment: () -> Void

    /// A counter for a value kept within `range`.
    init(_ label: String, value: Binding<Int>, in range: ClosedRange<Int>) {
        self.label = label
        self.value = value.wrappedValue
        self.canDecrement = value.wrappedValue > range.lowerBound
        self.canIncrement = value.wrappedValue < range.upperBound
        self.decrement = { value.wrappedValue = max(value.wrappedValue - 1, range.lowerBound) }
        self.increment = { value.wrappedValue = min(value.wrappedValue + 1, range.upperBound) }
    }

    /// A counter whose stepping has extra rules, such as Beats rolling over into Experiences.
    init(
        _ label: String,
        value: Int,
        canDecrement: Bool,
        canIncrement: Bool = true,
        decrement: @escaping () -> Void,
        increment: @escaping () -> Void
    ) {
        self.label = label
        self.value = value
        self.canDecrement = canDecrement
        self.canIncrement = canIncrement
        self.decrement = decrement
        self.increment = increment
    }

    var body: some View {
        HStack {
            Text(label)
                .themedText(.label)
            Spacer()
            HStack(spacing: 16) {
                stepButton("minus.circle", enabled: canDecrement, action: decrement)
                Text("\(value)")
                    .themedText(.label)
                    .frame(minWidth: 30)
                stepButton("plus.circle", enabled: canIncrement, action: increment)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label.trimmingCharacters(in: CharacterSet(charactersIn: ":")))
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                if canIncrement { increment() }
            case .decrement:
                if canDecrement { decrement() }
            @unknown default:
                break
            }
        }
    }

    private func stepButton(_ systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(theme.accent)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}

/// Text that becomes a text field when tapped. Editing ends on Done or when the field loses focus.
struct TapToEditText<Display: View>: View {
    @Environment(\.theme) private var theme
    let placeholder: String
    @Binding var text: String
    /// Font for the placeholder and the text field.
    var font: ThemeTextStyle = .body
    /// How the text is shown when it isn't being edited.
    @ViewBuilder let display: (String) -> Display

    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    var body: some View {
        if isEditing {
            TextField(placeholder, text: $text)
                .font(theme.font(font))
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .focused($isFocused)
                .onSubmit { isEditing = false }
                .onAppear { isFocused = true }
                .onChange(of: isFocused) { _, focused in
                    if !focused { isEditing = false }
                }
        } else {
            Button {
                isEditing = true
            } label: {
                if text.isEmpty {
                    Text(placeholder)
                        .font(theme.font(font))
                        .foregroundStyle(theme.muted)
                } else {
                    display(text)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Double-tap to edit")
        }
    }
}

extension TapToEditText where Display == ModifiedContent<Text, ThemedTextModifier> {
    /// Shows the text in the given style when it isn't being edited.
    init(_ placeholder: String, text: Binding<String>, font: ThemeTextStyle = .body) {
        self.placeholder = placeholder
        self._text = text
        self.font = font
        self.display = { Text($0).modifier(ThemedTextModifier(style: font)) }
    }
}

/// The "+ Add …" button at the end of a list section.
struct AddRowButton: View {
    @Environment(\.theme) private var theme
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "plus.circle")
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The game logo shown above the list on each screen.
struct LogoHeader: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Image(theme.logoImageName)
            .resizable()
            .scaledToFit()
            .frame(height: 100)
            .accessibilityHidden(true)
    }
}
