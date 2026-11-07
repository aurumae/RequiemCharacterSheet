//
//  HostedSheet.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// A sheet handed to the character sheet to present, e.g. the Add Discipline picker.
struct HostedSheet: Identifiable {
    let id = UUID()
    let content: AnyView
    let onDismiss: (() -> Void)?
}

/// Presents a sheet from outside the character sheet's list. A `.sheet` on a row can get stuck: if it can't
/// be presented (e.g. while another sheet is still closing), or the list discards the row, its "presented"
/// state stays on and later taps do nothing until the character is reopened. The host gets a new sheet on
/// every tap, so it always tries again. Always compares equal, as closures can't be compared.
struct PresentSheetAction: Equatable {
    private let present: (HostedSheet) -> Void

    init(_ present: @escaping (HostedSheet) -> Void) {
        self.present = present
    }

    func callAsFunction(_ sheet: HostedSheet) {
        present(sheet)
    }

    static func == (lhs: Self, rhs: Self) -> Bool { true }
}

extension EnvironmentValues {
    /// Set by the character sheet for the views in its list; `nil` elsewhere.
    @Entry var presentSheet: PresentSheetAction?
}

extension View {
    /// Like `.sheet(isPresented:)`, but presented by the character sheet when inside its list; see
    /// `PresentSheetAction`. `isPresented` turns off again as soon as the sheet is handed over.
    func hostedSheet<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(HostedSheetModifier(isPresented: isPresented, onDismiss: onDismiss, sheetContent: content))
    }
}

private struct HostedSheetModifier<SheetContent: View>: ViewModifier {
    @Environment(\.presentSheet) private var presentSheet
    @Binding var isPresented: Bool
    let onDismiss: (() -> Void)?
    let sheetContent: () -> SheetContent

    func body(content: Content) -> some View {
        if let presentSheet {
            content
                .onChange(of: isPresented) { _, nowPresented in
                    guard nowPresented else { return }
                    presentSheet(HostedSheet(content: AnyView(sheetContent()), onDismiss: onDismiss))
                    isPresented = false
                }
        } else {
            content.sheet(isPresented: $isPresented, onDismiss: onDismiss, content: sheetContent)
        }
    }
}

extension View {
    /// Presents the sheets handed over by `hostedSheet` from views inside `content`'s list.
    func sheetHost(_ sheet: Binding<HostedSheet?>, lastPresented: Binding<HostedSheet?>) -> some View {
        self.sheet(item: sheet, onDismiss: {
            lastPresented.wrappedValue?.onDismiss?()
            lastPresented.wrappedValue = nil
        }) { sheet in
            sheet.content
        }
    }
}
