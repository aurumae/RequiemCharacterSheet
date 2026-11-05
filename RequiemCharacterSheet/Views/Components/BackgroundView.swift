//
//  BackgroundView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//


import SwiftUI

/// Places content inside the safe area, over the parchment border, which fills the whole screen.
struct BackgroundView<Content: View>: View {
    @Environment(\.theme) private var theme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                GeometryReader { geometry in
                    Image(theme.borderImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
            }
    }
}

extension View {
    /// For a list that ends at the bottom page border: fades its edges out, so a half-hidden row
    /// doesn't look tappable, and leaves room to scroll the last row clear of the border. Taps near the
    /// bottom of the screen go to the list before the system's home gesture.
    func pageBorderEdge() -> some View {
        self
            .contentMargins(.bottom, 32, for: .scrollContent)
            .contentMargins(.top, 8, for: .scrollContent)
            .mask {
                VStack(spacing: 0) {
                    // A short fade where rows scroll under the logo, too
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 8)
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 20)
                }
            }
            .defersSystemGestures(on: .bottom)
    }
}

/// The list row holding a field, so the list can scroll it into view. Lists scroll to whole rows, not to
/// views inside them, so every row with a text field is identified with `editingRow(_:)`.
struct EditingRow {
    let id: AnyHashable
    /// Where in the visible list the row's anchor point goes: for a row with one field, its upper part.
    var anchor: Double = 0.3
}

extension EnvironmentValues {
    /// Scrolls a row into view, e.g. above the keyboard when one of its fields opens for editing.
    @Entry var revealEditingField: (EditingRow) -> Void = { _ in }
    /// The row the current view is in, set by `editingRow(_:)`.
    @Entry var editingRow: EditingRow?
}

extension View {
    /// Identifies a list row so its text fields can be scrolled clear of the keyboard.
    func editingRow(_ id: some Hashable) -> some View {
        self
            .id(id)
            .environment(\.editingRow, EditingRow(id: AnyHashable(id)))
    }
}
