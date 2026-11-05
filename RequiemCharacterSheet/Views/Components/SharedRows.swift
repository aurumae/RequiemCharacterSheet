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

/// A label with a number that becomes a number field when tapped, e.g. "Armor: 2".
/// The value is right-aligned like `LabeledValueRow`, and is kept within `range` when editing ends.
struct TapToEditNumberRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    init(_ label: String, value: Binding<Int>, in range: ClosedRange<Int>) {
        self.label = label
        self._value = value
        self.range = range
    }

    var body: some View {
        if isEditing {
            HStack {
                Text(label)
                    .themedText(.label)
                Spacer()
                TextField(label.trimmingCharacters(in: CharacterSet(charactersIn: ":")), text: $draft)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .themedText(.label)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 80)
                    .focused($isFocused)
                    .onAppear {
                        draft = "\(value)"
                        isFocused = true
                    }
                    .onChange(of: isFocused) { _, focused in
                        if !focused { commit() }
                    }
                    // The number pad has no return key
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { isFocused = false }
                        }
                    }
            }
            // The bordered field is taller than the plain value, so no extra padding keeps the row height steady
        } else {
            Button {
                isEditing = true
            } label: {
                HStack {
                    Text(label)
                        .themedText(.label)
                    Spacer()
                    Text("\(value)")
                        .themedText(.label)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label.trimmingCharacters(in: CharacterSet(charactersIn: ":")))
            .accessibilityValue("\(value)")
            .accessibilityHint("Double-tap to edit")
            .accessibilityAddTraits(.isButton)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    value = min(value + 1, range.upperBound)
                case .decrement:
                    value = max(value - 1, range.lowerBound)
                @unknown default:
                    break
                }
            }
        }
    }

    /// Saves the entered number, kept within `range`. Anything that isn't a number leaves the value unchanged.
    private func commit() {
        if let entered = Int(draft.trimmingCharacters(in: .whitespaces)) {
            value = min(max(entered, range.lowerBound), range.upperBound)
        }
        isEditing = false
    }
}

/// Text that becomes a text field when tapped. The text is saved when editing ends (Done, or the field
/// losing focus), not on every keystroke, so names that link to the catalog don't change mid-word.
struct TapToEditText<Display: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.revealEditingField) private var revealEditingField
    /// The list row this field is in, so the list can scroll it clear of the keyboard.
    @Environment(\.editingRow) private var editingRow
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let placeholder: String
    @Binding var text: String
    /// Font for the placeholder and the text field.
    var font: ThemeTextStyle = .body
    /// The field grows to show several lines, e.g. for an Aspiration. Return still ends editing.
    var multiline = false
    /// What VoiceOver calls the field, e.g. "Name", with its text read as the value. Without one, the text
    /// itself is read, which suits fields whose text says what they are (trait names, Aspirations).
    var accessibilityName: String?
    /// How the text is shown when it isn't being edited.
    @ViewBuilder let display: (String) -> Display

    @State private var isEditing: Bool
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    /// - Parameter beginsEditing: Start with the field open, e.g. for a row that was just added.
    init(placeholder: String, accessibilityName: String? = nil, text: Binding<String>, font: ThemeTextStyle = .body,
         multiline: Bool = false, beginsEditing: Bool = false, @ViewBuilder display: @escaping (String) -> Display) {
        self.placeholder = placeholder
        self.accessibilityName = accessibilityName
        self._text = text
        self.font = font
        self.multiline = multiline
        self.display = display
        self._isEditing = State(initialValue: beginsEditing)
    }

    var body: some View {
        if isEditing {
            TextField(placeholder, text: $draft, axis: multiline ? .vertical : .horizontal)
                .lineLimit(multiline ? 1...8 : 1...1)
                // A multi-line field puts a line break in on Return; take it as Done instead
                .onChange(of: draft) {
                    if multiline, draft.contains("\n") {
                        draft = draft.replacingOccurrences(of: "\n", with: "")
                        finishEditing()
                    } else if multiline {
                        // Keep a growing field above the keyboard
                        reveal()
                    }
                }
                .font(theme.font(font, dynamicTypeSize: dynamicTypeSize))
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .modifier(NamedField(name: accessibilityName, value: nil))
                .focused($isFocused)
                .onSubmit(finishEditing)
                .onAppear {
                    draft = text
                    isFocused = true
                    // Once the keyboard is up, scroll the field into the upper part of the screen. The list
                    // adjusts for the keyboard itself after it appears, so scroll again once that's done.
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        reveal()
                        try? await Task.sleep(for: .milliseconds(500))
                        reveal()
                    }
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused { finishEditing() }
                }
                // Also once the keyboard has finished appearing, e.g. after a picker closes
                .task {
                    for await _ in NotificationCenter.default.notifications(named: UIResponder.keyboardDidShowNotification) {
                        try? await Task.sleep(for: .milliseconds(200))
                        reveal()
                    }
                }
        } else {
            Button {
                isEditing = true
            } label: {
                if text.isEmpty {
                    Text(placeholder)
                        .font(theme.font(font, dynamicTypeSize: dynamicTypeSize))
                        .foregroundStyle(theme.muted)
                } else {
                    display(text)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Double-tap to edit")
            .modifier(NamedField(name: accessibilityName, value: text.isEmpty ? "Empty" : text))
        }
    }

    private func reveal() {
        if let editingRow {
            revealEditingField(editingRow)
        }
    }

    private func finishEditing() {
        guard isEditing else { return }
        text = draft
        isEditing = false
    }
}

extension TapToEditText where Display == ModifiedContent<Text, ThemedTextModifier> {
    /// Shows the text in the given style when it isn't being edited.
    init(_ placeholder: String, accessibilityName: String? = nil, text: Binding<String>, font: ThemeTextStyle = .body) {
        self.init(placeholder: placeholder, accessibilityName: accessibilityName, text: text, font: font) {
            Text($0).modifier(ThemedTextModifier(style: font))
        }
    }
}

/// The "+ Add …" button at the end of a list section.
struct AddRowButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
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
                .opacity(isEnabled ? 1 : 0.35)
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

/// A muted line explaining why something can't be done during guided creation.
struct CreationNote: View {
    @Environment(\.theme) private var theme
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .themedText(.detail)
            .foregroundStyle(theme.muted)
    }
}

/// Gives a field its name for VoiceOver, e.g. "Name", with the entered text as its value.
private struct NamedField: ViewModifier {
    let name: String?
    let value: String?

    func body(content: Content) -> some View {
        if let name {
            if let value {
                content
                    .accessibilityLabel(name)
                    .accessibilityValue(value)
            } else {
                content.accessibilityLabel(name)
            }
        } else {
            content
        }
    }
}
